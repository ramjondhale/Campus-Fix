import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'campus_fix_firebase.dart';
import 'complaint_writes.dart';
import 'firebase_auth_repository.dart';
import 'firestore_codec.dart';

/// The fixed, opaque assignee id a **maintenance** viewer sees on a complaint
/// that a *colleague* has claimed (plan section 5.3). It identifies nobody; it
/// only keeps `workQueueProvider`'s "unclaimed or mine" rule working without
/// exposing who the colleague is.
const String kClaimedByColleagueId = '__claimed__';

/// Assembles the [Complaint] a given [viewer] is allowed to see from the split
/// Firestore documents (plan section 5.3, seam S-4).
///
/// [publicDoc] is `complaints/{id}` (the 17 `PublicComplaintView` keys plus
/// `version` and `claimed`); [adminDoc] is `complaints/{id}/private/admin` and
/// is only honoured when [viewer] is an admin (a defense in depth: callers pass
/// it for admins only) **or** [trustAdminDoc] is set. Both must already be
/// passed through `documentToJson` (Timestamps converted to ISO strings).
///
/// Restricted fields are filled with inert placeholders so the providers stay
/// untouched:
///
/// | field | admin / [trustAdminDoc] | other viewers |
/// |---|---|---|
/// | `reporter` | placeholder, `userId` = viewer id only when [ownedByViewer] | same |
/// | `assignment.assigneeId` | real (from [adminDoc]) | maintenance: viewer id if [claimedByViewer], [kClaimedByColleagueId] if `claimed`, else null; others: null |
/// | `assignment.assignedBy` / `isManual` / `assignedAt` | real | placeholders |
/// | `timeline[].actorId` / `id` | real | empty / derived (`ev-<id>-NN`) |
/// | `priority`, `priorityOverride`, `severity`, `peopleAffected` | real | `priority = effectivePriority`, override null, inert defaults |
///
/// **[trustAdminDoc]** is for the write path only ([FirebaseComplaintRepository.byId]):
/// the MVP rules let every signed-in user read `private/admin` (rules delta
/// (f)), and `ComplaintService` must validate and recompute against the *real*
/// priority inputs, assignment and timeline whoever acts. Computing a priority
/// from the placeholders (`severity = minor`, `peopleAffected = individual`)
/// would silently lower it. The board / list reads never set it.
///
/// The real reporter identity is never assembled here: an admin gets it only
/// through the audited reveal (`FirebaseReporterIdentityRevealer`, plan S-5).
Complaint assembleComplaint({
  required Map<String, Object?> publicDoc,
  Map<String, Object?>? adminDoc,
  required AppUser viewer,
  bool ownedByViewer = false,
  bool claimedByViewer = false,
  bool trustAdminDoc = false,
}) {
  final PublicComplaintView pub = PublicComplaintView.fromJson(publicDoc);
  final bool claimed = publicDoc['claimed'] == true;
  final Map<String, Object?>? admin =
      (viewer.role.canSeeReporterIdentity || trustAdminDoc) ? adminDoc : null;

  final Priority priority;
  final Priority? priorityOverride;
  final Severity severity;
  final PeopleAffected peopleAffected;
  final Assignment? assignment;
  final List<StatusEvent> timeline;

  if (admin != null) {
    priority = Priority.values.byName(admin['priority'] as String);
    final Object? rawOverride = admin['priorityOverride'];
    priorityOverride = rawOverride == null
        ? null
        : Priority.values.byName(rawOverride as String);
    severity = Severity.values.byName(admin['severity'] as String);
    peopleAffected = PeopleAffected.values.byName(
      admin['peopleAffected'] as String,
    );
    final Object? rawAssignment = admin['assignment'];
    assignment = rawAssignment == null
        ? null
        : Assignment.fromJson(Map<String, Object?>.from(rawAssignment as Map));
    final Object? rawTimeline = admin['timeline'];
    timeline = <StatusEvent>[
      if (rawTimeline is List)
        for (final Object? e in rawTimeline)
          StatusEvent.fromJson(Map<String, Object?>.from(e as Map)),
    ];
  } else {
    priority = pub.effectivePriority;
    priorityOverride = null;
    severity = Severity.minor;
    peopleAffected = PeopleAffected.individual;
    final Department? department = pub.assignedDepartment;
    assignment = department == null
        ? null
        : Assignment(
            department: department,
            assigneeId: _placeholderAssigneeId(
              viewer,
              claimed: claimed,
              claimedByViewer: claimedByViewer,
            ),
            assignedBy: '',
            assignedAt: pub.updatedAt,
            isManual: false,
          );
    timeline = <StatusEvent>[
      for (int i = 0; i < pub.timeline.length; i++)
        StatusEvent(
          id: 'ev-${pub.id}-${(i + 1).toString().padLeft(2, '0')}',
          status: pub.timeline[i].status,
          actorId: '',
          actorRole: pub.timeline[i].actorRole,
          note: pub.timeline[i].note,
          at: pub.timeline[i].at,
        ),
    ];
  }

  return Complaint(
    id: pub.id,
    category: pub.category,
    title: pub.title,
    description: pub.description,
    building: pub.building,
    floor: pub.floor,
    room: pub.room,
    reporter: ReporterIdentity(
      userId: ownedByViewer ? viewer.id : '',
      fullName: '',
      idNumber: '',
      email: '',
    ),
    beforePhotos: pub.beforePhotos,
    afterPhotos: pub.afterPhotos,
    priority: priority,
    priorityOverride: priorityOverride,
    status: pub.status,
    assignment: assignment,
    timeline: timeline,
    resolutionNote: pub.resolutionNote,
    safetyFlag: pub.safetyFlag,
    severity: severity,
    peopleAffected: peopleAffected,
    createdAt: pub.createdAt,
    updatedAt: pub.updatedAt,
  );
}

String? _placeholderAssigneeId(
  AppUser viewer, {
  required bool claimed,
  required bool claimedByViewer,
}) {
  if (viewer.role != UserRole.maintenance) return null;
  if (claimedByViewer) return viewer.id;
  return claimed ? kClaimedByColleagueId : null;
}

/// [ComplaintRepository] over the Firestore 3-way split (plan section 5):
///
/// * `complaints/{id}`                     public document (readable by every signed-in user)
/// * `complaints/{id}/private/admin`       admin-only half
/// * `complaints/{id}/private/identity`    reporter PII (admin-readable in the MVP)
/// * `userComplaints/{uid}/items/{id}`     ownership index ("My complaints" / [byReporter])
/// * `staffClaims/{uid}/items/{id}`        claim index (maintenance "claimed by me")
///
/// Reads assemble a [Complaint] **per viewer** with [assembleComplaint]. The
/// viewer is read from [AuthRepository.currentUser] on every call, so a
/// sign-out / sign-in swap needs no new repository.
///
/// ## What each read touches (C2; plan sections 5.3 and 6.2, seam S-4)
///
/// | viewer | Firestore reads |
/// |---|---|
/// | admin | public `complaints` + one `private/admin` get per complaint (cached per `version` + `updatedAt`, so only changed complaints are re-read) |
/// | maintenance | public `complaints` + own `userComplaints/{uid}/items` + own `staffClaims/{uid}/items` |
/// | reporter, verifier | public `complaints` + own `userComplaints/{uid}/items` |
/// | signed out | nothing (empty list / `null`; the rules would deny it anyway) |
///
/// `private/identity` is **never** read here: the assembled `reporter` is always
/// a placeholder (an admin gets the real identity only through the audited
/// reveal, `FirebaseReporterIdentityRevealer`).
///
/// **Not bounded yet.** Plan S-11 / R1 asks for bounded listeners (open
/// complaints plus recent closed). The MVP demo board is the whole seed (29
/// complaints), `My complaints` is computed from the same list, and bounding
/// would hide old closed complaints from it, so [all] and [watchAll] read every
/// complaint. Revisit with the load check (R1).
///
/// A document that cannot be decoded (a malformed or hand-edited document) is
/// skipped with a `debugPrint` rather than failing the whole board.
///
/// ## Writes (C3: client-side, no Cloud Functions)
///
/// `ComplaintService` runs in the client for every role and calls [submit] /
/// [update]; each is **one Firestore transaction** whose documents the rules
/// validate as a batch (`firestore.rules`: `validNewComplaint`, `validUpdate`,
/// `validPrivateAdmin`, the index and `counters` rules). The pure planning half
/// lives in `complaint_writes.dart`.
///
/// | call | transaction |
/// |---|---|
/// | [submit] | read `counters/complaintIds-{year}`, allocate `CF-{year}-{NNNNN}` (create at 1 or +1), then write `complaints/{id}` (version 1, claimed false), `private/admin`, `private/identity` and `userComplaints/{uid}/items/{id}` |
/// | [update] | read the public + `private/admin` documents, check `version` against the last [byId] read, then update both (`version + 1`, appended timeline, new `updatedAt`) and add / remove the `staffClaims` marker of a changed assignee |
///
/// **[byId] is the write base.** Every `ComplaintService` action starts with
/// `byId`. Unlike the list reads it fetches `private/admin` for **every** role
/// (MVP rules delta (f): any signed-in user may read it) and assembles the
/// *real* priority inputs, assignment and timeline, so the service recomputes
/// priorities and validates P6 / P7 against true data whoever acts. It also
/// remembers the `version` it saw; [update] writes only if the stored version
/// still equals it (otherwise a [ComplaintConflictException]).
class FirebaseComplaintRepository implements ComplaintRepository {
  FirebaseComplaintRepository(
    CampusFixFirebase fb, {
    required AuthRepository viewer,
  }) : _fb = fb,
       _viewer = viewer;

  final CampusFixFirebase _fb;
  final AuthRepository _viewer;

  /// What the last [byId] of each complaint saw (optimistic concurrency, rule
  /// P8). `Complaint` has no version field, so the repository remembers it and
  /// writes `version + 1` on [update].
  ///
  /// Filled **only by [byId]**, not by the list / stream reads: those can run
  /// between the service's read and its write and would silently re-base a
  /// plan that was made on an older state (the P8 "expected status" check would
  /// then be against the wrong snapshot). [update] consumes the entry.
  final Map<String, _WriteBase> _bases = <String, _WriteBase>{};

  /// `private/admin` reads of the admin viewer, keyed by complaint id and valid
  /// while the public document's `version` + `updatedAt` are unchanged (the
  /// rules only let a client change `private/admin` in the same batch that
  /// bumps the public `version`). Keeps [all] / [watchAll] at one extra read
  /// per *changed* complaint instead of one per complaint per call (risk R2).
  /// Cleared when the session ends or a non-admin takes over.
  final Map<String, _AdminEntry> _adminCache = <String, _AdminEntry>{};

  // ---------------------------------------------------------------------------
  // References
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _complaints =>
      _fb.firestore.collection('complaints');

  CollectionReference<Map<String, dynamic>> _ownedIndex(String uid) => _fb
      .firestore
      .collection('userComplaints')
      .doc(uid)
      .collection('items');

  CollectionReference<Map<String, dynamic>> _claimIndex(String uid) =>
      _fb.firestore.collection('staffClaims').doc(uid).collection('items');

  DocumentReference<Map<String, dynamic>> _adminRef(String complaintId) =>
      _complaints.doc(complaintId).collection('private').doc('admin');

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Every complaint the viewer may see (the whole board; see the class doc on
  /// bounding).
  ///
  /// Reads: public `complaints` (all roles) in parallel with the viewer's own
  /// index sets (non-admin), then, **admin only**, one `private/admin` get per
  /// complaint that is not in the cache (plan R2: N gets on the first call,
  /// only changed complaints afterwards).
  @override
  Future<List<Complaint>> all() => _readQuery(_complaints);

  /// The complaint with [id], or `null` when it does not exist (or nobody is
  /// signed in): **the base of every write** (see the class documentation).
  ///
  /// Reads, in parallel: public `complaints/{id}`, a fresh `private/admin` get
  /// (**every role**, never from the cache, because `ComplaintService`
  /// validates and recomputes against this copy) and a membership get on the
  /// viewer's own `userComplaints` (non-admin) / `staffClaims` (maintenance)
  /// index. The complaint is assembled with the real admin half
  /// (`trustAdminDoc`) and its `version` is remembered for [update].
  ///
  /// A non-admin whose `private/admin` read is `permission-denied` (a ruleset
  /// from before the C3 relaxation) falls back to the placeholder assembly so
  /// the screens keep reading; [update] then refuses to write (it would have to
  /// guess the priority inputs). An admin's denial is rethrown: the token is
  /// not an admin's.
  @override
  Future<Complaint?> byId(String id) async {
    final AppUser? viewer = _viewer.currentUser;
    if (viewer == null || !_isDocumentId(id)) return null;

    final List<Object?> reads = await Future.wait<Object?>(<Future<Object?>>[
      _complaints.doc(id).get(),
      _readAdminForWrite(viewer, id),
      _membershipIndexes(viewer, id),
    ]);
    final DocumentSnapshot<Map<String, dynamic>> doc =
        reads[0]! as DocumentSnapshot<Map<String, dynamic>>;
    if (!doc.exists) return null;
    final Map<String, Object?>? adminJson = reads[1] as Map<String, Object?>?;
    final _Indexes indexes = reads[2]! as _Indexes;

    try {
      final Complaint complaint = assembleComplaint(
        publicDoc: documentToJson(doc.data(), id: doc.id),
        adminDoc: adminJson,
        viewer: viewer,
        ownedByViewer: indexes.owned.contains(doc.id),
        claimedByViewer: indexes.claimed.contains(doc.id),
        trustAdminDoc: true,
      );
      final Object? version = doc.data()?['version'];
      if (version is num) {
        _bases[doc.id] = _WriteBase(
          uid: viewer.id,
          version: version.toInt(),
          hasAdminDetail: adminJson != null,
        );
      }
      return complaint;
    } on Object catch (e) {
      debugPrint('FirebaseComplaintRepository: skipped ${doc.id} ($e)');
      return null;
    }
  }

  /// `private/admin` of [complaintId] as JSON for the write base, or `null`
  /// when it does not exist (or a non-admin is denied, see [byId]).
  Future<Map<String, Object?>?> _readAdminForWrite(
    AppUser viewer,
    String complaintId,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _adminRef(
        complaintId,
      ).get();
      return snap.exists ? documentToJson(snap.data()) : null;
    } on FirebaseException catch (e) {
      if (!_isAdmin(viewer) && e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Complaints filed by [userId].
  ///
  /// Rules only let a user read their own `userComplaints/{uid}/items`, so this
  /// reads that index and then fetches the complaints by id (`whereIn` on the
  /// document id, in chunks of 10). A [userId] that is not the signed-in viewer
  /// yields an empty list: the mock's `reporter.userId` filter cannot be served
  /// for other users, and an admin has no way to list another user's index.
  @override
  Future<List<Complaint>> byReporter(String userId) async {
    final AppUser? viewer = _viewer.currentUser;
    if (viewer == null || viewer.id != userId) return const <Complaint>[];

    final Set<String> ids = await _idsIn(_ownedIndex(userId));
    if (ids.isEmpty) return const <Complaint>[];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
        await _getByIds(ids);
    // The ownership set is already in hand; only a maintenance viewer still
    // needs its claim set.
    final _Indexes indexes = await _loadIndexes(viewer, owned: ids);
    return _finish(viewer, docs, indexes);
  }

  /// Complaints routed to [department].
  ///
  /// Reads: the public `assignedDepartment == department.name` query (public by
  /// design, plan section 5.3; a single-field equality, so no composite index),
  /// then the same per-role reads as [all].
  @override
  Future<List<Complaint>> byDepartment(Department department) => _readQuery(
    _complaints.where('assignedDepartment', isEqualTo: department.name),
  );

  /// Complaints whose current status is [status].
  ///
  /// Reads: the public `status == status.name` query (single-field equality),
  /// then the same per-role reads as [all].
  @override
  Future<List<Complaint>> byStatus(ComplaintStatus status) =>
      _readQuery(_complaints.where('status', isEqualTo: status.name));

  // ---------------------------------------------------------------------------
  // Read helpers
  // ---------------------------------------------------------------------------

  /// Runs [query] over the public documents and assembles the result for the
  /// current viewer (the shared body of [all], [byDepartment], [byStatus]).
  Future<List<Complaint>> _readQuery(Query<Map<String, dynamic>> query) async {
    final AppUser? viewer = _viewer.currentUser;
    if (viewer == null) return const <Complaint>[];

    final (snap, indexes) = await _both(query.get(), _loadIndexes(viewer));
    return _finish(viewer, snap.docs, indexes);
  }

  /// Adds the admin-only half (for an admin viewer) and assembles every [docs]
  /// entry with [assembleComplaint]. [useCache] `false` forces a fresh
  /// `private/admin` read.
  Future<List<Complaint>> _finish(
    AppUser viewer,
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
    _Indexes indexes, {
    bool useCache = true,
  }) async {
    if (!_isAdmin(viewer)) _adminCache.clear(); // never keep admin data around
    final Map<String, Map<String, Object?>?> admin = _isAdmin(viewer)
        ? await _adminJsonFor(docs, useCache: useCache)
        : const <String, Map<String, Object?>?>{};
    return _assembleAll(viewer, docs, indexes: indexes, admin: admin);
  }

  /// The viewer's own index sets: ownership for every non-admin role, claims for
  /// maintenance only (nobody else's placeholders use them). A pre-read [owned]
  /// set skips the ownership read.
  Future<_Indexes> _loadIndexes(AppUser viewer, {Set<String>? owned}) async {
    final List<Future<Set<String>>> reads = <Future<Set<String>>>[
      if (owned != null)
        Future<Set<String>>.value(owned)
      else if (_readsOwnedIndex(viewer))
        _idsIn(_ownedIndex(viewer.id))
      else
        Future<Set<String>>.value(const <String>{}),
      if (_readsClaimIndex(viewer))
        _idsIn(_claimIndex(viewer.id))
      else
        Future<Set<String>>.value(const <String>{}),
    ];
    final List<Set<String>> sets = await Future.wait<Set<String>>(reads);
    return _Indexes(owned: sets[0], claimed: sets[1]);
  }

  /// Like [_loadIndexes] for one complaint: a membership get per index instead
  /// of listing it.
  Future<_Indexes> _membershipIndexes(
    AppUser viewer,
    String complaintId,
  ) async {
    final List<bool> flags = await Future.wait<bool>(<Future<bool>>[
      _isIndexed(
        _readsOwnedIndex(viewer) ? _ownedIndex(viewer.id) : null,
        complaintId,
      ),
      _isIndexed(
        _readsClaimIndex(viewer) ? _claimIndex(viewer.id) : null,
        complaintId,
      ),
    ]);
    return _Indexes(
      owned: flags[0] ? <String>{complaintId} : const <String>{},
      claimed: flags[1] ? <String>{complaintId} : const <String>{},
    );
  }

  /// The document ids of the viewer's own index [index] (the index doc id is the
  /// complaint id; the rules allow listing it for its owner only).
  Future<Set<String>> _idsIn(
    CollectionReference<Map<String, dynamic>> index,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await index.get();
    return <String>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs)
        d.id,
    };
  }

  /// Whether [complaintId] is in [index] (`false` when [index] is `null`).
  Future<bool> _isIndexed(
    CollectionReference<Map<String, dynamic>>? index,
    String complaintId,
  ) async {
    if (index == null) return false;
    return (await index.doc(complaintId).get()).exists;
  }

  /// The public documents with the given [ids] (ids that do not exist are
  /// simply absent), ordered by id.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getByIds(
    Iterable<String> ids,
  ) async {
    final List<String> sorted = <String>[
      for (final String id in ids)
        if (_isDocumentId(id)) id,
    ]..sort();
    final List<Future<QuerySnapshot<Map<String, dynamic>>>> reads =
        <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (int i = 0; i < sorted.length; i += _whereInChunk) {
      final int end = i + _whereInChunk < sorted.length
          ? i + _whereInChunk
          : sorted.length;
      reads.add(
        _complaints
            .where(FieldPath.documentId, whereIn: sorted.sublist(i, end))
            .get(),
      );
    }
    final List<QuerySnapshot<Map<String, dynamic>>> snaps = await Future.wait(
      reads,
    );
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final QuerySnapshot<Map<String, dynamic>> s in snaps) ...s.docs,
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// `private/admin` as JSON per complaint id for [docs] (`null` = the document
  /// does not exist). Admin viewers only: every other role is denied by the
  /// rules (PR-T4). Reads only what the cache cannot serve; [useCache] `false`
  /// re-reads everything. Errors propagate (a `permission-denied` here means the
  /// token is not really an admin's and should not be hidden).
  Future<Map<String, Map<String, Object?>?>> _adminJsonFor(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs, {
    bool useCache = true,
  }) async {
    final Map<String, Map<String, Object?>?> out =
        <String, Map<String, Object?>?>{};
    final List<Future<void>> pending = <Future<void>>[];
    for (final DocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final String id = doc.id;
      final String stamp = _stampOf(doc.data());
      final _AdminEntry? hit = useCache ? _adminCache[id] : null;
      if (hit != null && hit.stamp == stamp) {
        out[id] = hit.json;
      } else {
        pending.add(
          _readAdminJson(id, stamp).then((Map<String, Object?>? json) {
            out[id] = json;
          }),
        );
      }
    }
    if (pending.isNotEmpty) await Future.wait(pending);
    return out;
  }

  /// One `private/admin` get, remembered in [_adminCache] under [stamp].
  Future<Map<String, Object?>?> _readAdminJson(
    String complaintId,
    String stamp,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _adminRef(
      complaintId,
    ).get();
    final Map<String, Object?>? json = snap.exists
        ? documentToJson(snap.data())
        : null;
    _adminCache[complaintId] = _AdminEntry(stamp, json);
    return json;
  }

  /// [assembleComplaint] for every doc in [docs], skipping undecodable ones.
  List<Complaint> _assembleAll(
    AppUser viewer,
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs, {
    required _Indexes indexes,
    required Map<String, Map<String, Object?>?> admin,
  }) {
    final List<Complaint> out = <Complaint>[];
    for (final DocumentSnapshot<Map<String, dynamic>> doc in docs) {
      try {
        out.add(
          assembleComplaint(
            publicDoc: documentToJson(doc.data(), id: doc.id),
            adminDoc: admin[doc.id],
            viewer: viewer,
            ownedByViewer: indexes.owned.contains(doc.id),
            claimedByViewer: indexes.claimed.contains(doc.id),
          ),
        );
      } on Object catch (e) {
        // One bad document must not take the whole board down.
        debugPrint('FirebaseComplaintRepository: skipped ${doc.id} ($e)');
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Writes (C3)
  // ---------------------------------------------------------------------------

  /// Persists a new complaint prepared by `ComplaintService.submit` and returns
  /// it **under its allocated Complaint ID** (seam S-3).
  ///
  /// One Firestore transaction:
  ///
  /// 1. read `counters/complaintIds-{year}` (year of `createdAt`) and take
  ///    `last + 1` (the rule only allows creating the counter at 1 or
  ///    incrementing it by exactly 1, capped at 99999);
  /// 2. write the counter, `complaints/{id}` (the 17 public keys, `version: 1`,
  ///    `claimed: false`), `private/admin`, `private/identity` (the submitting
  ///    reporter) and `userComplaints/{uid}/items/{id}`.
  ///
  /// The draft's own ID (from the service's local `ComplaintIdGenerator`) is
  /// ignored and replaced, including inside the TL-1 event id
  /// ([withAllocatedId]); a Complaint-ID collision (the counter is behind the
  /// data) aborts with a [StateError] instead of overwriting.
  ///
  /// Rules: `validNewComplaint` (id format, status `reported`, version 1,
  /// timeline of one event by the caller's role, ownership marker in the same
  /// batch), `complaintCreatedInThisWrite` for the three side documents, and
  /// the `counters` rule. Needs a signed-in reporter whose uid is the draft's
  /// `reporter.userId`.
  @override
  Future<Complaint> submit(Complaint draft) async {
    final AppUser? viewer = _viewer.currentUser;
    if (viewer == null) {
      throw StateError('FirebaseComplaintRepository.submit: nobody is signed in.');
    }
    if (draft.reporter.userId != viewer.id) {
      // The identity / ownership documents are keyed by the caller's uid.
      throw ArgumentError('The reporter of a new complaint must be the signed-in user.');
    }

    final int year = draft.createdAt.year;
    final DocumentReference<Map<String, dynamic>> counter = _fb.firestore
        .collection('counters')
        .doc(complaintCounterDocId(year));

    return _fb.firestore.runTransaction<Complaint>((Transaction tx) async {
      // A transaction's reads must all come before its writes, and the handler
      // may run again on contention: it only derives values from what it read.
      final DocumentSnapshot<Map<String, dynamic>> counterSnap = await tx.get(
        counter,
      );
      final Object? rawLast = counterSnap.data()?['last'];
      final int last = !counterSnap.exists
          ? 0
          : (rawLast is num ? rawLast.toInt() : -1);
      if (last < 0) {
        throw StateError('counters/${counter.id} is malformed.');
      }
      final int sequence = last + 1;
      if (sequence > kMaxComplaintSequence) {
        throw StateError('Complaint ID sequence exhausted for $year.');
      }
      final String id = complaintIdFor(year, sequence);
      final DocumentReference<Map<String, dynamic>> publicRef = _complaints.doc(
        id,
      );
      if ((await tx.get(publicRef)).exists) {
        throw StateError(
          'Complaint $id already exists: the ID counter is behind the data.',
        );
      }

      final Complaint saved = withAllocatedId(draft, id);
      final NewComplaintDocs docs = newComplaintDocs(saved);
      if (counterSnap.exists) {
        tx.update(counter, <String, Object?>{'last': sequence});
      } else {
        tx.set(counter, <String, Object?>{'last': sequence});
      }
      tx.set(publicRef, docs.publicDoc);
      tx.set(publicRef.collection('private').doc('admin'), docs.adminDoc);
      tx.set(publicRef.collection('private').doc('identity'), docs.identityDoc);
      tx.set(_ownedIndex(viewer.id).doc(id), docs.ownedDoc);
      return saved;
    });
  }

  /// Persists the result of a `ComplaintService` transition or admin edit and
  /// returns [c] (every `ComplaintService` action reads the complaint with
  /// [byId] first; the stored `version` that read saw is checked here).
  ///
  /// One Firestore transaction (the planning is `planComplaintUpdate`):
  ///
  /// * read the public and `private/admin` documents;
  /// * a stored `version` other than the one [byId] saw, a `closed` complaint
  ///   (INV-4) or a timeline that does not extend the stored one throws a
  ///   [ComplaintConflictException] and writes nothing;
  /// * update `complaints/{id}` (`version + 1`, status, effective priority,
  ///   safety flag, department, resolution note, after photos, `updatedAt`,
  ///   `claimed`, and the stored public timeline plus the new events: the
  ///   timeline is append-only), update `private/admin`, and delete / create
  ///   the `staffClaims/{uid}/items/{id}` marker of an assignee that left /
  ///   was set.
  ///
  /// `private/identity` is never touched: it is written once, at submit.
  ///
  /// Every role goes through here; which role may take which edge is the
  /// rules' status-transition mirror (`legalRoles`, `validStatusChange`,
  /// `validSameStatusEdit`), so a transition the role may not take (a verifier
  /// closing, a reporter doing anything) is rejected by the server with
  /// `permission-denied`.
  ///
  /// Throws a [StateError] when [c] was not read with [byId] by the signed-in
  /// user, or that read could not see `private/admin` (writing from
  /// placeholders would corrupt the priority inputs).
  @override
  Future<Complaint> update(Complaint c) async {
    final AppUser? viewer = _viewer.currentUser;
    if (viewer == null) {
      throw StateError('FirebaseComplaintRepository.update: nobody is signed in.');
    }
    final _WriteBase? base = _bases[c.id];
    if (base == null || base.uid != viewer.id) {
      throw StateError(
        'FirebaseComplaintRepository.update: read the complaint with byId '
        'first (the write is checked against the version that read saw).',
      );
    }
    if (!base.hasAdminDetail) {
      throw StateError(
        'FirebaseComplaintRepository.update: private/admin was not readable '
        'for this complaint, so its priority inputs and assignment are '
        'unknown (deploy the C3 firestore.rules: any signed-in user may read '
        'private/admin).',
      );
    }

    final DocumentReference<Map<String, dynamic>> publicRef = _complaints.doc(
      c.id,
    );
    final DocumentReference<Map<String, dynamic>> adminRef = _adminRef(c.id);
    await _fb.firestore.runTransaction<void>((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> publicSnap = await tx.get(
        publicRef,
      );
      final DocumentSnapshot<Map<String, dynamic>> adminSnap = await tx.get(
        adminRef,
      );
      final Map<String, dynamic>? storedPublic = publicSnap.data();
      if (storedPublic == null) {
        throw ComplaintConflictException(c.id, 'This complaint no longer exists.');
      }
      final ComplaintUpdatePlan plan = planComplaintUpdate(
        storedPublic: storedPublic,
        storedAdmin: adminSnap.data(),
        next: c,
        expectedVersion: base.version,
      );
      tx.update(publicRef, plan.publicFields);
      tx.update(adminRef, plan.adminFields);
      final String? release = plan.releaseClaimOf;
      if (release != null) tx.delete(_claimIndex(release).doc(c.id));
      final String? take = plan.takeClaimFor;
      if (take != null) {
        tx.set(_claimIndex(take).doc(c.id), <String, Object?>{
          'complaintId': c.id,
        });
      }
    });
    // The base is spent: the next write must start from a fresh read.
    _bases.remove(c.id);
    return c;
  }

  /// The full list now and whenever it changes.
  ///
  /// Joins, per subscription (plan section 5.3): the public `complaints`
  /// snapshot listener with the viewer's own `userComplaints` listener
  /// (non-admin) and `staffClaims` listener (maintenance), and re-assembles the
  /// list on every event from any of them. An admin has no index listeners; each
  /// public snapshot instead triggers `private/admin` gets for the complaints
  /// whose `version` / `updatedAt` changed (the rules only change `private/admin`
  /// together with a public `version` bump, so the public listener is a complete
  /// change signal).
  ///
  /// Nothing is emitted until every source the viewer's role needs has delivered
  /// its first snapshot, so there is no flash of "not mine" ownership.
  ///
  /// **The stream follows the session.** The apps keep one long-lived raw
  /// provider over this stream and do not re-subscribe on sign-out / sign-in, so
  /// when the [AuthRepository] is a [FirebaseAuthRepository] the stream listens
  /// to [FirebaseAuthRepository.authChanges]: on sign-out it cancels every
  /// Firestore listener and emits an empty list (dropping the previous user's
  /// data), and on sign-in (or a role / department change) it re-subscribes as
  /// the new viewer. Listener errors that are only the session ending are
  /// swallowed; any other error is delivered as a stream error (the app's
  /// Retry re-subscribes).
  @override
  Stream<List<Complaint>> watchAll() => _ComplaintFeed(this).stream;
}

// -----------------------------------------------------------------------------
// Viewer-scoped read plumbing (file-private)
// -----------------------------------------------------------------------------

/// Largest id list handed to one `whereIn` (Firestore allows 30; 10 is safe on
/// every backend).
const int _whereInChunk = 10;

/// Admins are the only viewers who read `private/admin` (rules, PR-T4); this is
/// `UserRole.canSeeReporterIdentity`.
bool _isAdmin(AppUser viewer) => viewer.role.canSeeReporterIdentity;

/// Every non-admin role reads its own `userComplaints` index to set the
/// `reporter.userId` placeholder (plan section 5.3).
bool _readsOwnedIndex(AppUser viewer) => !_isAdmin(viewer);

/// Only maintenance reads its own `staffClaims` index: it is the only role
/// whose `assignment.assigneeId` placeholder depends on it.
bool _readsClaimIndex(AppUser viewer) => viewer.role == UserRole.maintenance;

/// Whether two sessions are the same viewer for read purposes (same uid and the
/// same claims-derived role and department).
bool _sameViewer(AppUser? a, AppUser? b) =>
    a?.id == b?.id && a?.role == b?.role && a?.department == b?.department;

/// A usable Firestore document id (non-empty, no path separator).
bool _isDocumentId(String id) =>
    id.isNotEmpty && !id.contains('/') && id != '.' && id != '..';

/// Change stamp of a public document: its `version` plus `updatedAt`. Equal
/// stamps mean `private/admin` has not changed either.
String _stampOf(Map<String, dynamic>? data) {
  final Object? updated = data?['updatedAt'];
  final Object? millis = updated is Timestamp
      ? updated.millisecondsSinceEpoch
      : updated;
  return '${data?['version']}@$millis';
}

/// Awaits [a] and [b] concurrently. Unlike a record's `.wait`, a failure
/// propagates as the original exception (callers catch `FirebaseException`).
Future<(A, B)> _both<A, B>(Future<A> a, Future<B> b) async {
  final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
    a,
    b,
  ]);
  return (results[0] as A, results[1] as B);
}

/// The ids of the viewer's own complaints and claims (plan section 5.3).
class _Indexes {
  const _Indexes({
    this.owned = const <String>{},
    this.claimed = const <String>{},
  });

  /// Complaint ids in `userComplaints/{uid}/items`.
  final Set<String> owned;

  /// Complaint ids in `staffClaims/{uid}/items`.
  final Set<String> claimed;
}

/// One cached `private/admin` read (null [json] = the document does not exist).
class _AdminEntry {
  const _AdminEntry(this.stamp, this.json);

  final String stamp;
  final Map<String, Object?>? json;
}

/// What the last `byId` of one complaint saw: the optimistic-concurrency base
/// of the next `update` (see `FirebaseComplaintRepository._bases`).
class _WriteBase {
  const _WriteBase({
    required this.uid,
    required this.version,
    required this.hasAdminDetail,
  });

  /// The user who read it; another user's base is never reused.
  final String uid;

  /// The public document's `version` at that read.
  final int version;

  /// Whether the real `private/admin` was assembled (false: placeholders, so a
  /// write would corrupt the priority inputs and is refused).
  final bool hasAdminDetail;
}

/// One [FirebaseComplaintRepository.watchAll] subscription: the public
/// `complaints` listener joined with the viewer's own index listeners (plan
/// section 5.3), re-attached whenever the session's viewer changes.
///
/// Created per `watchAll()` call; listeners start on the first listen and are
/// cancelled when the subscriber cancels.
class _ComplaintFeed {
  _ComplaintFeed(this._repo) {
    _controller = StreamController<List<Complaint>>(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final FirebaseComplaintRepository _repo;
  late final StreamController<List<Complaint>> _controller;

  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _publicSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _claimedSub;

  /// The viewer the current listeners were opened for (`null` = signed out).
  AppUser? _user;

  /// Latest snapshot / id sets (`null` until the source has delivered).
  QuerySnapshot<Map<String, dynamic>>? _public;
  Set<String>? _owned;
  Set<String>? _claimed;

  /// Bumped on every (re)attach so late events of cancelled listeners and
  /// in-flight admin reads are dropped.
  int _epoch = 0;

  /// Bumped on every assembly so only the newest in-flight admin read emits.
  int _generation = 0;
  bool _stopped = false;

  Stream<List<Complaint>> get stream => _controller.stream;

  void _start() {
    final AuthRepository auth = _repo._viewer;
    if (auth is FirebaseAuthRepository) {
      // Subscribe before reading currentUser so no change can fall in between.
      _authSub = auth.authChanges.listen((AppUser? user) => _attach(user));
    }
    _attach(auth.currentUser, force: true);
  }

  Future<void> _stop() async {
    _stopped = true;
    final StreamSubscription<AppUser?>? auth = _authSub;
    _authSub = null;
    _detach();
    await auth?.cancel();
  }

  /// (Re)opens the listeners for [next]; a no-op when it is the viewer already
  /// attached (unless [force]).
  void _attach(AppUser? next, {bool force = false}) {
    if (_stopped) return;
    if (!force && _sameViewer(_user, next)) return;

    _detach();
    _user = next;
    if (next == null) {
      // Signed out: drop the previous user's data from the app's state.
      _repo._adminCache.clear();
      _repo._bases.clear();
      _emit(const <Complaint>[]);
      return;
    }
    if (!_isAdmin(next)) _repo._adminCache.clear();

    final int epoch = _epoch;
    _publicSub = _repo._complaints.snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        if (epoch != _epoch) return;
        _public = snap;
        _refresh();
      },
      onError: (Object error, StackTrace stack) => _fail(epoch, error, stack),
    );
    if (_readsOwnedIndex(next)) {
      _ownedSub = _repo._ownedIndex(next.id).snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snap) {
          if (epoch != _epoch) return;
          _owned = <String>{for (final d in snap.docs) d.id};
          _refresh();
        },
        onError: (Object error, StackTrace stack) =>
            _fail(epoch, error, stack),
      );
    }
    if (_readsClaimIndex(next)) {
      _claimedSub = _repo._claimIndex(next.id).snapshots().listen(
        (QuerySnapshot<Map<String, dynamic>> snap) {
          if (epoch != _epoch) return;
          _claimed = <String>{for (final d in snap.docs) d.id};
          _refresh();
        },
        onError: (Object error, StackTrace stack) =>
            _fail(epoch, error, stack),
      );
    }
  }

  /// Cancels every Firestore listener and forgets the data they delivered.
  void _detach() {
    _epoch++;
    _generation++;
    final List<StreamSubscription<Object?>?> subs =
        <StreamSubscription<Object?>?>[_publicSub, _ownedSub, _claimedSub];
    _publicSub = null;
    _ownedSub = null;
    _claimedSub = null;
    for (final StreamSubscription<Object?>? sub in subs) {
      if (sub != null) unawaited(sub.cancel());
    }
    _public = null;
    _owned = null;
    _claimed = null;
  }

  /// Re-assembles and emits the list once every source the viewer needs has
  /// delivered.
  void _refresh() {
    final AppUser? viewer = _user;
    final QuerySnapshot<Map<String, dynamic>>? snap = _public;
    if (viewer == null || snap == null) return;
    if (_readsOwnedIndex(viewer) && _owned == null) return;
    if (_readsClaimIndex(viewer) && _claimed == null) return;

    final _Indexes indexes = _Indexes(
      owned: _owned ?? const <String>{},
      claimed: _claimed ?? const <String>{},
    );
    final int generation = ++_generation;
    if (_isAdmin(viewer)) {
      unawaited(_refreshAdmin(viewer, snap, _epoch, generation));
    } else {
      _emit(
        _repo._assembleAll(
          viewer,
          snap.docs,
          indexes: indexes,
          admin: const <String, Map<String, Object?>?>{},
        ),
      );
    }
  }

  /// The admin path of [_refresh]: fetches the changed `private/admin`
  /// documents, then emits unless a newer snapshot or a re-attach superseded
  /// this one while the reads were in flight.
  Future<void> _refreshAdmin(
    AppUser viewer,
    QuerySnapshot<Map<String, dynamic>> snap,
    int epoch,
    int generation,
  ) async {
    try {
      final Map<String, Map<String, Object?>?> admin = await _repo
          ._adminJsonFor(snap.docs);
      if (_stopped || epoch != _epoch || generation != _generation) return;
      _emit(
        _repo._assembleAll(
          viewer,
          snap.docs,
          indexes: const _Indexes(),
          admin: admin,
        ),
      );
    } on Object catch (e, st) {
      _fail(epoch, e, st);
    }
  }

  /// Forwards a listener / read error, except when it is only the session
  /// ending or switching: Firestore revokes the old viewer's listeners before
  /// the auth event that re-attaches (or empties) the feed has been delivered.
  void _fail(int epoch, Object error, StackTrace stack) {
    if (_stopped || epoch != _epoch) return;
    final AppUser? live = _repo._viewer.currentUser;
    if (live == null || !_sameViewer(live, _user)) return;
    _controller.addError(error, stack);
  }

  void _emit(List<Complaint> complaints) {
    if (_stopped || _controller.isClosed) return;
    _controller.add(complaints);
  }
}
