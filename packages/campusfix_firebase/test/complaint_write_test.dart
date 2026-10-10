// Pure unit tests (NO Firebase, NO emulator: run with `flutter test` in this
// package) for the MVP client-side WRITE path (chunk C3).
//
// `FirebaseComplaintRepository.submit` / `update` are thin Firestore
// transactions around `newComplaintDocs` / `planComplaintUpdate`
// (`lib/src/complaint_writes.dart`). These tests drive core's REAL
// `ComplaintService` for every role over an in-memory stand-in for Firestore
// that runs exactly those two functions and then checks the result against a
// Dart port of the `firestore.rules` write rules (`validNewComplaint`,
// `validUpdate`, `legalRoles`, the index rules). So they prove, without a
// server, that:
//
//   * each transition's write has the shape the deployed rules accept for the
//     role that takes it (submit / review & route / start / resolve / verify /
//     reject / close / reassign / priority override / safety flag);
//   * the allocated Complaint ID comes from the counter, not from the service;
//   * priorities are recomputed from the REAL inputs for every role (a
//     placeholder-based recompute would silently lower them);
//   * the no-op notification producer keeps writes independent of the user
//     directory;
//   * the Dart port of the rules has not drifted from `backend/firestore.rules`
//     (the public key set, the transition table, and the two read decisions:
//     `private/admin` is signed-in-readable, `private/identity` admin-only).
//
// What these tests do NOT cover (they need the emulator; see the C3 report):
// the real transactions, the real rules engine (access-call limits, `getAfter`
// batch semantics) and the Timestamp round trip through a server.
import 'dart:convert';
import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// The rules, as the tests see them (a Dart port, checked against the file)
// ---------------------------------------------------------------------------

const Set<String> _publicKeys = <String>{
  'id',
  'category',
  'title',
  'building',
  'floor',
  'room',
  'description',
  'beforePhotos',
  'afterPhotos',
  'effectivePriority',
  'status',
  'safetyFlag',
  'assignedDepartment',
  'resolutionNote',
  'timeline',
  'createdAt',
  'updatedAt',
  'version',
  'claimed',
};

const Set<String> _adminKeys = <String>{
  'priority',
  'priorityOverride',
  'severity',
  'peopleAffected',
  'assignment',
  'timeline',
};

const Set<String> _identityKeys = <String>{
  'userId',
  'fullName',
  'idNumber',
  'email',
  'phone',
};

/// `legalRoles(from, to)` of `firestore.rules`.
const Map<String, Set<String>> _legalRoles = <String, Set<String>>{
  'reported>reviewed': <String>{'verifier', 'admin'},
  'reported>assigned': <String>{'verifier', 'admin'},
  'reviewed>assigned': <String>{'verifier', 'admin'},
  'assigned>inProgress': <String>{'maintenance', 'admin'},
  'inProgress>resolved': <String>{'maintenance', 'admin'},
  'resolved>verified': <String>{'verifier', 'admin'},
  'verified>closed': <String>{'admin'},
  'resolved>inProgress': <String>{'verifier', 'admin'},
  'inProgress>assigned': <String>{'admin'},
};

/// The write the rules refused (stands in for Firestore's `permission-denied`).
class _RulesDenied implements Exception {
  _RulesDenied(this.reason);

  final String reason;

  @override
  String toString() => 'permission-denied: $reason';
}

void _require(bool condition, String reason) {
  if (!condition) throw _RulesDenied(reason);
}

bool _deepEquals(Object? a, Object? b) =>
    equals(a).matches(b, <Object?, Object?>{});

/// `validNewComplaint` + `complaintCreatedInThisWrite` + the identity / owner
/// index rules, for [viewer] creating complaint [id] with [docs].
void _checkNewComplaint(AppUser viewer, String id, NewComplaintDocs docs) {
  final Map<String, Object?> d = docs.publicDoc;
  _require(
    d.keys.toSet().containsAll(_publicKeys) &&
        _publicKeys.containsAll(d.keys),
    'the public key set must be exactly the 19 keys',
  );
  _require(
    RegExp(r'^CF-[0-9]{4}-[0-9]{5}$').hasMatch(id),
    'complaint id format',
  );
  _require(d['id'] == id, 'id field must equal the document id');
  _require(d['status'] == 'reported', 'a new complaint is `reported`');
  _require(d['version'] == 1, 'a new complaint is version 1');
  _require(d['claimed'] == false, 'a new complaint is not claimed');
  final List<Object?> timeline = d['timeline']! as List<Object?>;
  _require(timeline.length == 1, 'one timeline event');
  final Map<String, dynamic> first = timeline.first! as Map<String, dynamic>;
  _require(first['status'] == 'reported', 'first event is `reported`');
  _require(
    first['actorRole'] == viewer.role.name,
    'first event is by the caller\'s role',
  );
  _require(
    docs.adminDoc.keys.every(_adminKeys.contains) &&
        (docs.adminDoc['timeline']! as List<Object?>).length == 1,
    'private/admin key set and timeline length',
  );
  _require(
    docs.identityDoc.keys.every(_identityKeys.contains) &&
        docs.identityDoc['userId'] == viewer.id,
    'private/identity: allowed keys, userId == auth.uid',
  );
}

/// `validUpdate` + `validPrivateAdmin` + the `staffClaims` index rules for
/// [viewer] changing [prev] into [next] (the merged documents).
void _checkUpdate({
  required AppUser viewer,
  required Map<String, dynamic> prev,
  required Map<String, dynamic> next,
  required Map<String, dynamic> nextAdmin,
  required ComplaintUpdatePlan plan,
}) {
  final String role = viewer.role.name;
  _require(prev['status'] != 'closed', 'closed is immutable (INV-4)');
  _require(
    next.keys.every(_publicKeys.contains),
    'no key outside the public key set',
  );
  _require(
    next['version'] == (prev['version'] as int) + 1,
    'version must be previous + 1 (P8)',
  );
  for (final String core in <String>[
    'id',
    'category',
    'title',
    'building',
    'floor',
    'room',
    'description',
    'createdAt',
  ]) {
    _require(_deepEquals(next[core], prev[core]), 'core field $core changed');
  }
  final List<Object?> before = prev['timeline'] as List<Object?>;
  final List<Object?> after = next['timeline'] as List<Object?>;
  _require(after.length >= before.length, 'the timeline shrank');
  for (int i = 0; i < before.length; i++) {
    _require(_deepEquals(after[i], before[i]), 'timeline[$i] was rewritten');
  }
  final int appended = after.length - before.length;
  final String from = prev['status'] as String;
  final String to = next['status'] as String;
  if (from != to) {
    _require(
      _legalRoles['$from>$to']?.contains(role) ?? false,
      '$role may not take $from>$to',
    );
    _require(
      appended == (from == 'reported' && to == 'assigned' ? 2 : 1),
      'wrong number of appended events for $from>$to',
    );
  } else {
    _require(role == 'admin', 'a same-status edit is admin-only');
    _require(appended == 0 || appended == 1, 'same-status edit appends 0 or 1');
  }
  _require(
    nextAdmin.keys.every(_adminKeys.contains) &&
        (nextAdmin['timeline'] as List<Object?>).length == after.length,
    'private/admin key set and timeline length',
  );
  // staffClaims create / delete: the claimer or an admin.
  for (final String? uid in <String?>[plan.releaseClaimOf, plan.takeClaimFor]) {
    if (uid == null) continue;
    _require(
      uid == viewer.id || role == 'admin',
      'only the claimer or an admin may touch staffClaims/$uid',
    );
  }
}

// ---------------------------------------------------------------------------
// An in-memory Firestore stand-in that runs the production write planning
// ---------------------------------------------------------------------------

class _Doc {
  _Doc({
    required this.publicDoc,
    required this.adminDoc,
    required this.identity,
  });

  Map<String, dynamic> publicDoc;
  Map<String, dynamic> adminDoc;
  final Map<String, dynamic> identity;
}

class _FakeFirestoreComplaints implements ComplaintRepository {
  /// The signed-in user (set by the test before each action).
  AppUser? viewer;

  final Map<int, int> counters = <int, int>{};
  final Map<String, _Doc> docs = <String, _Doc>{};

  /// `userComplaints` markers as `<uid>/<complaintId>`.
  final Set<String> owned = <String>{};

  /// `staffClaims` markers as `<uid>/<complaintId>`.
  final Set<String> claims = <String>{};

  final Map<String, int> _bases = <String, int>{};

  @override
  Future<Complaint> submit(Complaint draft) async {
    final AppUser v = viewer!;
    _require(draft.reporter.userId == v.id, 'reporter must be the caller');
    final int year = draft.createdAt.year;
    final int sequence = (counters[year] ?? 0) + 1;
    counters[year] = sequence;
    final Complaint saved = withAllocatedId(
      draft,
      complaintIdFor(year, sequence),
    );
    final NewComplaintDocs created = newComplaintDocs(saved);
    _checkNewComplaint(v, saved.id, created);
    docs[saved.id] = _Doc(
      publicDoc: <String, dynamic>{...created.publicDoc},
      adminDoc: <String, dynamic>{...created.adminDoc},
      identity: <String, dynamic>{...created.identityDoc},
    );
    owned.add('${v.id}/${saved.id}');
    return saved;
  }

  @override
  Future<Complaint?> byId(String id) async {
    final _Doc? doc = docs[id];
    if (doc == null) return null;
    final AppUser v = viewer!;
    _bases[id] = doc.publicDoc['version'] as int;
    return assembleComplaint(
      publicDoc: documentToJson(doc.publicDoc, id: id),
      adminDoc: documentToJson(doc.adminDoc),
      viewer: v,
      ownedByViewer: owned.contains('${v.id}/$id'),
      trustAdminDoc: true,
    );
  }

  @override
  Future<Complaint> update(Complaint c) async {
    final AppUser v = viewer!;
    final _Doc doc = docs[c.id]!;
    final int? base = _bases[c.id];
    if (base == null) throw StateError('update() before byId()');
    final ComplaintUpdatePlan plan = planComplaintUpdate(
      storedPublic: doc.publicDoc,
      storedAdmin: doc.adminDoc,
      next: c,
      expectedVersion: base,
    );
    final Map<String, dynamic> nextPublic = <String, dynamic>{
      ...doc.publicDoc,
      ...plan.publicFields,
    };
    final Map<String, dynamic> nextAdmin = <String, dynamic>{
      ...doc.adminDoc,
      ...plan.adminFields,
    };
    _checkUpdate(
      viewer: v,
      prev: doc.publicDoc,
      next: nextPublic,
      nextAdmin: nextAdmin,
      plan: plan,
    );
    doc.publicDoc = nextPublic;
    doc.adminDoc = nextAdmin;
    final String? release = plan.releaseClaimOf;
    if (release != null) claims.remove('$release/${c.id}');
    final String? take = plan.takeClaimFor;
    if (take != null) claims.add('$take/${c.id}');
    _bases.remove(c.id);
    return c;
  }

  @override
  Future<List<Complaint>> all() => throw UnimplementedError();

  @override
  Future<List<Complaint>> byReporter(String userId) =>
      throw UnimplementedError();

  @override
  Future<List<Complaint>> byDepartment(Department department) =>
      throw UnimplementedError();

  @override
  Future<List<Complaint>> byStatus(ComplaintStatus status) =>
      throw UnimplementedError();

  @override
  Stream<List<Complaint>> watchAll() => const Stream<List<Complaint>>.empty();
}

/// A user directory that must never be read: the write path may not depend on
/// it (the rules only let an admin list staff).
class _NoDirectory implements UserRepository {
  const _NoDirectory();

  @override
  Future<List<AppUser>> all() =>
      Future<List<AppUser>>.error(StateError('directory read'));

  @override
  Future<AppUser?> byId(String id) =>
      Future<AppUser?>.error(StateError('directory read'));

  @override
  Future<List<AppUser>> maintenanceByDepartment(Department department) =>
      Future<List<AppUser>>.error(StateError('directory read'));
}

// ---------------------------------------------------------------------------
// The world a scenario runs in
// ---------------------------------------------------------------------------

/// The instant the scenarios are relative to.
final DateTime t0 = DateTime.utc(2026, 10, 6, 9);

DateTime at(int hours) => t0.add(Duration(hours: hours));

class _World {
  _World._(this.seed, this.repo, this.service);

  factory _World() {
    final SeedData seed = SeedData.build();
    final _FakeFirestoreComplaints repo = _FakeFirestoreComplaints();
    final MockNotificationRepository notifications =
        MockNotificationRepository();
    return _World._(
      seed,
      repo,
      ComplaintService(
        complaints: repo,
        notifications: notifications,
        users: MockUserRepository.seeded(seed: seed),
        // The service's own generator is ahead of the counter on purpose: the
        // stored ID must come from the counter.
        ids: ComplaintIdGenerator(initialCounters: <int, int>{2026: 500}),
        notificationService: DeferredNotificationService(
          notifications: notifications,
          users: const _NoDirectory(),
        ),
        clock: () => t0,
      ),
    );
  }

  final SeedData seed;
  final _FakeFirestoreComplaints repo;
  final ComplaintService service;

  AppUser get reporter => seed.userById('u-rep-01')!;
  AppUser get verifier => seed.userById('u-ver-01')!;
  AppUser get admin => seed.userById('u-adm-01')!;

  AppUser staff(Department department, [int n = 1]) => seed.users
      .where(
        (AppUser u) =>
            u.role == UserRole.maintenance && u.department == department,
      )
      .toList()[n - 1];

  ReporterIdentity identityOf(AppUser u) => ReporterIdentity(
    userId: u.id,
    fullName: u.displayName,
    idNumber: u.idNumber,
    email: u.email,
    phone: '+91 90000 11001',
  );

  /// A severe, many-people electrical complaint (priority `high`; the
  /// placeholder inputs would give `medium`).
  Future<Complaint> submit() {
    repo.viewer = reporter;
    return service.submit(
      reporter: identityOf(reporter),
      category: ProblemCategory.electrical,
      description: 'The breaker keeps tripping near the entrance.',
      building: 'Science Block',
      floor: '2',
      room: 'Lab 204',
      beforePhotos: <Attachment>[
        Attachment(
          id: 'att-before-1',
          kind: AttachmentKind.beforePhoto,
          ref: 'assets/seed/before.jpg',
          createdAt: t0,
        ),
      ],
      severity: Severity.severe,
      peopleAffected: PeopleAffected.many,
      now: t0,
    );
  }

  /// Reads complaint [id] as [user], like a controller does before acting.
  Future<Complaint> read(AppUser user, String id) async {
    repo.viewer = user;
    return (await repo.byId(id))!;
  }

  /// Runs [act] as [user].
  Future<ComplaintActionResult> by(
    AppUser user,
    Future<ComplaintActionResult> Function() act,
  ) {
    repo.viewer = user;
    return act();
  }

  /// [by], expecting success.
  Future<Complaint> ok(
    AppUser user,
    Future<ComplaintActionResult> Function() act,
  ) async {
    final ComplaintActionResult r = await by(user, act);
    if (!r.ok) throw StateError('blocked by ${r.codes}');
    return r.complaint!;
  }

  /// submit -> review & route (verifier) -> start (maintenance); `inProgress`.
  Future<String> toInProgress() async {
    final Complaint filed = await submit();
    await ok(
      verifier,
      () => service.reviewAndRoute(filed, verifier, now: at(1)),
    );
    final AppUser worker = staff(Department.electrician);
    final Complaint assigned = await read(worker, filed.id);
    await ok(worker, () => service.startWork(assigned, worker, now: at(2)));
    return filed.id;
  }

  /// [toInProgress] -> resolve (maintenance); `resolved`.
  Future<String> toResolved() async {
    final String id = await toInProgress();
    final AppUser worker = staff(Department.electrician);
    final Complaint started = await read(worker, id);
    await ok(
      worker,
      () => service.resolve(
        started,
        worker,
        resolutionNote: 'Replaced the faulty breaker.',
        afterPhotos: <Attachment>[
          Attachment(
            id: 'att-after-1',
            kind: AttachmentKind.afterPhoto,
            ref: 'assets/seed/after.jpg',
            createdAt: at(3),
          ),
        ],
        now: at(4),
      ),
    );
    return id;
  }

  /// [toResolved] -> verify (verifier); `verified`.
  Future<String> toVerified() async {
    final String id = await toResolved();
    final Complaint resolved = await read(verifier, id);
    await ok(verifier, () => service.verify(resolved, verifier, now: at(5)));
    return id;
  }
}

// ---------------------------------------------------------------------------
// The seed split into stored documents (for the assembly test)
// ---------------------------------------------------------------------------

const ReporterIdentity _placeholder = ReporterIdentity(
  userId: '',
  fullName: '',
  idNumber: '',
  email: '',
);

class _Stored {
  const _Stored(this.publicDoc, this.adminDoc);

  final Map<String, Object?> publicDoc;
  final Map<String, Object?> adminDoc;
}

_Stored _store(Complaint c, AppUser admin) {
  final Map<String, Object?> full = toAdminView(c, admin)!.toJson();
  final Map<String, Object?> publicJson = <String, Object?>{
    ...toPublicView(c).toJson(),
    'version': 1,
    'claimed': c.assignment?.assigneeId != null,
  };
  final Map<String, Object?> adminJson = <String, Object?>{
    for (final String k in _adminKeys) k: full[k],
  };
  return _Stored(
    documentToJson(
      jsonToFirestore(publicJson) as Map<String, dynamic>,
      id: c.id,
    ),
    documentToJson(jsonToFirestore(adminJson) as Map<String, dynamic>),
  );
}

void main() {
  // -------------------------------------------------------------------------
  group('the Dart port of the rules matches backend/firestore.rules', () {
    const String rulesPath = '../../backend/firestore.rules';
    final bool haveRules = File(rulesPath).existsSync();
    const String skip = 'run from packages/campusfix_firebase (rules not found)';

    test(
      'publicKeys() is exactly the 19 keys the repository writes',
      () {
        final String rules = File(rulesPath).readAsStringSync();
        final RegExpMatch? m = RegExp(
          r'function publicKeys\(\)\s*\{\s*return\s*\[([^\]]*)\]',
        ).firstMatch(rules);
        expect(m, isNotNull, reason: 'publicKeys() not found');
        final Set<String> ruleKeys = <String>{
          for (final RegExpMatch k in RegExp(
            r"'([^']+)'",
          ).allMatches(m!.group(1)!))
            k.group(1)!,
        };
        expect(ruleKeys, _publicKeys);
      },
      skip: haveRules ? false : skip,
    );

    test(
      'legalRoles() is the transition table the tests use',
      () {
        final String rules = File(rulesPath).readAsStringSync();
        final RegExpMatch? fn = RegExp(
          r'function legalRoles\([^)]*\)\s*\{([\s\S]*?)return edges\.get',
        ).firstMatch(rules);
        expect(fn, isNotNull, reason: 'legalRoles() not found');
        final Map<String, Set<String>> edges = <String, Set<String>>{
          for (final RegExpMatch e in RegExp(
            r"'(\w+>\w+)':\s*\[([^\]]*)\]",
          ).allMatches(fn!.group(1)!))
            e.group(1)!: <String>{
              for (final RegExpMatch r in RegExp(
                r"'(\w+)'",
              ).allMatches(e.group(2)!))
                r.group(1)!,
            },
        };
        expect(edges, _legalRoles);
      },
      skip: haveRules ? false : skip,
    );

    test(
      'private/admin is readable by any signed-in user, private/identity by '
      'an admin only (decision: do not weaken the identity document)',
      () {
        final String rules = File(rulesPath).readAsStringSync();
        final RegExpMatch? admin = RegExp(
          r'match /private/admin \{\s*allow get:\s*if ([^;]+);',
        ).firstMatch(rules);
        final RegExpMatch? identity = RegExp(
          r'match /private/identity \{\s*allow get:\s*if ([^;]+);',
        ).firstMatch(rules);
        expect(admin?.group(1), 'signedIn()');
        expect(identity?.group(1), 'isAdmin()');
      },
      skip: haveRules ? false : skip,
    );

    test(
      'close is admin-only and the identity document can never be updated',
      () {
        final String rules = File(rulesPath).readAsStringSync();
        expect(
          RegExp(r"'verified>closed':\s*\['admin'\]").hasMatch(rules),
          isTrue,
        );
        expect(
          RegExp(
            r'match /private/identity \{[\s\S]*?allow update, delete: if false;',
          ).hasMatch(rules),
          isTrue,
        );
      },
      skip: haveRules ? false : skip,
    );
  });

  // -------------------------------------------------------------------------
  group('IDs and new-complaint documents', () {
    test('complaintIdFor / complaintCounterDocId follow the rules\' formats', () {
      expect(complaintIdFor(2026, 1), 'CF-2026-00001');
      expect(complaintIdFor(2026, 99999), 'CF-2026-99999');
      expect(complaintCounterDocId(2026), 'complaintIds-2026');
      expect(
        RegExp(r'^complaintIds-[0-9]{4}$').hasMatch(complaintCounterDocId(7)),
        isTrue,
      );
      expect(kMaxComplaintSequence, 99999);
    });

    test('withAllocatedId re-keys the draft and its TL-1 event id', () async {
      final _World w = _World();
      final Complaint draft = await w.submit();
      final Complaint moved = withAllocatedId(draft, 'CF-2026-00042');
      expect(moved.id, 'CF-2026-00042');
      expect(moved.timeline.single.id, 'ev-CF-2026-00042-01');
      expect(moved.copyWith(id: draft.id), isNot(equals(draft)));
      expect(
        moved.copyWith(
          id: draft.id,
          timeline: draft.timeline,
        ),
        draft,
      );
    });

    test('submit writes the ID from the counter, the four documents and no '
        'identity in the public document', () async {
      final _World w = _World();
      final Complaint first = await w.submit();

      expect(first.id, 'CF-2026-00001', reason: 'from the counter');
      expect(first.timeline.single.id, 'ev-CF-2026-00001-01');
      final _Doc doc = w.repo.docs[first.id]!;
      expect(doc.publicDoc.keys.toSet(), _publicKeys);
      expect(doc.publicDoc['version'], 1);
      expect(doc.publicDoc['claimed'], false);
      expect(doc.publicDoc['status'], 'reported');
      expect(doc.adminDoc.keys.toSet(), _adminKeys);
      expect(doc.identity.keys.toSet(), _identityKeys);
      expect(doc.identity['userId'], w.reporter.id);
      expect(w.repo.owned, contains('${w.reporter.id}/${first.id}'));

      final String publicText = jsonEncode(
        firestoreToJson(doc.publicDoc),
      ).toLowerCase();
      final String adminText = jsonEncode(
        firestoreToJson(doc.adminDoc),
      ).toLowerCase();
      for (final String s in <String>[
        w.reporter.displayName,
        w.reporter.idNumber,
        w.reporter.email,
        w.reporter.id,
      ]) {
        expect(publicText, isNot(contains(s.toLowerCase())), reason: s);
      }
      for (final String s in <String>[
        w.reporter.displayName,
        w.reporter.idNumber,
        w.reporter.email,
      ]) {
        expect(adminText, isNot(contains(s.toLowerCase())), reason: s);
      }

      final Complaint second = await w.submit();
      expect(second.id, 'CF-2026-00002');
    });
  });

  // -------------------------------------------------------------------------
  group('every role\'s transition commits against the rules', () {
    test('the whole lifecycle: reporter, verifier, maintenance, verifier, '
        'admin close', () async {
      final _World w = _World();
      final Complaint filed = await w.submit();
      final String id = filed.id;
      final _Doc doc = w.repo.docs[id]!;

      // Verifier: Review & Route = T1 + T2 in ONE write (two events).
      await w.ok(
        w.verifier,
        () => w.service.reviewAndRoute(filed, w.verifier, now: at(1)),
      );
      expect(doc.publicDoc['status'], 'assigned');
      expect(doc.publicDoc['assignedDepartment'], 'electrician');
      expect(doc.publicDoc['version'], 2);
      expect((doc.publicDoc['timeline'] as List<Object?>).length, 3);
      expect(doc.publicDoc['claimed'], false);

      // Priority fidelity: recomputed from the REAL inputs by a verifier.
      final Priority real = computePriority(
        const PriorityInputs(
          category: ProblemCategory.electrical,
          safetyFlag: false,
          severity: Severity.severe,
          peopleAffected: PeopleAffected.many,
          waitingTime: Duration(hours: 1),
        ),
      );
      final Priority fromPlaceholders = computePriority(
        const PriorityInputs(
          category: ProblemCategory.electrical,
          safetyFlag: false,
          severity: Severity.minor,
          peopleAffected: PeopleAffected.individual,
          waitingTime: Duration(hours: 1),
        ),
      );
      expect(real.weight, greaterThan(fromPlaceholders.weight));
      expect(doc.adminDoc['priority'], real.name);
      expect(doc.publicDoc['effectivePriority'], real.name);
      expect(doc.adminDoc['severity'], 'severe');
      expect(doc.adminDoc['peopleAffected'], 'many');

      // Maintenance: start (claims the work, creates the staffClaims marker).
      final AppUser worker = w.staff(Department.electrician);
      final Complaint assigned = await w.read(worker, id);
      await w.ok(
        worker,
        () => w.service.startWork(assigned, worker, now: at(2)),
      );
      expect(doc.publicDoc['status'], 'inProgress');
      expect(doc.publicDoc['claimed'], true);
      expect(w.repo.claims, <String>{'${worker.id}/$id'});
      expect(
        (doc.adminDoc['assignment'] as Map<String, dynamic>)['assigneeId'],
        worker.id,
      );
      expect(doc.adminDoc['priority'], real.name);

      // Maintenance: resolve (after photo + note; priority freezes).
      final Complaint started = await w.read(worker, id);
      await w.ok(
        worker,
        () => w.service.resolve(
          started,
          worker,
          resolutionNote: 'Replaced the faulty breaker.',
          afterPhotos: <Attachment>[
            Attachment(
              id: 'att-after-1',
              kind: AttachmentKind.afterPhoto,
              ref: 'assets/seed/after.jpg',
              createdAt: at(3),
            ),
          ],
          now: at(4),
        ),
      );
      expect(doc.publicDoc['status'], 'resolved');
      expect(doc.publicDoc['resolutionNote'], 'Replaced the faulty breaker.');
      expect((doc.publicDoc['afterPhotos'] as List<Object?>).length, 1);

      // Verifier: verify.
      final Complaint resolved = await w.read(w.verifier, id);
      await w.ok(
        w.verifier,
        () => w.service.verify(resolved, w.verifier, now: at(5)),
      );
      expect(doc.publicDoc['status'], 'verified');

      // Admin: close (admin only).
      final Complaint verified = await w.read(w.admin, id);
      await w.ok(w.admin, () => w.service.close(verified, w.admin, now: at(6)));
      expect(doc.publicDoc['status'], 'closed');
      expect(doc.publicDoc['version'], 6);

      // The history: roles only in the public timeline, actors in private.
      final List<Map<String, dynamic>> publicTimeline = <Map<String, dynamic>>[
        for (final Object? e in doc.publicDoc['timeline'] as List<Object?>)
          e! as Map<String, dynamic>,
      ];
      expect(<Object?>[for (final e in publicTimeline) e['actorRole']], <String>[
        'reporter',
        'verifier',
        'verifier',
        'maintenance',
        'maintenance',
        'verifier',
        'admin',
      ]);
      expect(
        publicTimeline.every((Map<String, dynamic> e) => !e.containsKey('actorId')),
        isTrue,
      );
      final List<Object?> adminTimeline = doc.adminDoc['timeline'] as List<Object?>;
      expect(adminTimeline.length, 7);
      expect(
        (adminTimeline[3]! as Map<String, dynamic>)['actorId'],
        worker.id,
      );

      // Closed is immutable: every further action is blocked (never written).
      final Complaint closed = await w.read(w.admin, id);
      final ComplaintActionResult afterClose = await w.by(
        w.admin,
        () => w.service.setPriorityOverride(closed, w.admin, Priority.low),
      );
      expect(afterClose.ok, isFalse);
      expect(doc.publicDoc['version'], 6);
    });

    test('a verifier cannot close (rules: close is admin-only)', () async {
      final _World w = _World();
      final String id = await w.toVerified();
      final Complaint verified = await w.read(w.verifier, id);

      await expectLater(
        w.by(w.verifier, () => w.service.close(verified, w.verifier, now: at(6))),
        throwsA(isA<_RulesDenied>()),
      );
      expect(w.repo.docs[id]!.publicDoc['status'], 'verified');
    });

    test('reject sends it back and unfreezes; an admin reassign moves the '
        'staffClaims marker', () async {
      final _World w = _World();
      final String id = await w.toResolved();
      final _Doc doc = w.repo.docs[id]!;
      final AppUser worker = w.staff(Department.electrician);
      expect(w.repo.claims, <String>{'${worker.id}/$id'});

      final Complaint resolved = await w.read(w.verifier, id);
      await w.ok(
        w.verifier,
        () => w.service.reject(
          resolved,
          w.verifier,
          note: 'Still tripping.',
          now: at(5),
        ),
      );
      expect(doc.publicDoc['status'], 'inProgress');
      expect(w.repo.claims, <String>{'${worker.id}/$id'}, reason: 'unchanged');

      final AppUser civil = w.staff(Department.civilMaintenance);
      final Complaint back = await w.read(w.admin, id);
      await w.ok(
        w.admin,
        () => w.service.reassign(
          back,
          w.admin,
          department: Department.civilMaintenance,
          assigneeId: civil.id,
          reason: 'Needs a civil fix.',
          now: at(6),
        ),
      );
      expect(doc.publicDoc['status'], 'assigned');
      expect(doc.publicDoc['assignedDepartment'], 'civilMaintenance');
      expect(doc.publicDoc['claimed'], true);
      expect(w.repo.claims, <String>{'${civil.id}/$id'});
      final Map<String, dynamic> assignment =
          doc.adminDoc['assignment'] as Map<String, dynamic>;
      expect(assignment['assigneeId'], civil.id);
      expect(assignment['isManual'], true);
    });

    test('admin same-status edits: override and safety flag append nothing '
        'and leave updatedAt alone; reassign while assigned appends one',
        () async {
      final _World w = _World();
      final Complaint filed = await w.submit();
      final String id = filed.id;
      final _Doc doc = w.repo.docs[id]!;
      await w.ok(
        w.verifier,
        () => w.service.reviewAndRoute(filed, w.verifier, now: at(1)),
      );
      final Object? updatedAt = doc.publicDoc['updatedAt'];
      final int events = (doc.publicDoc['timeline'] as List<Object?>).length;

      final Complaint c1 = await w.read(w.admin, id);
      await w.ok(
        w.admin,
        () => w.service.setPriorityOverride(c1, w.admin, Priority.critical),
      );
      expect(doc.publicDoc['effectivePriority'], 'critical');
      expect(doc.adminDoc['priorityOverride'], 'critical');
      expect(doc.publicDoc['version'], 3);
      expect(doc.publicDoc['updatedAt'], updatedAt);
      expect((doc.publicDoc['timeline'] as List<Object?>).length, events);

      final Complaint c2 = await w.read(w.admin, id);
      await w.ok(
        w.admin,
        () => w.service.setSafetyFlag(c2, w.admin, true, now: at(3)),
      );
      expect(doc.publicDoc['safetyFlag'], true);
      expect(doc.publicDoc['version'], 4);
      expect((doc.publicDoc['timeline'] as List<Object?>).length, events);

      final Complaint c3 = await w.read(w.admin, id);
      await w.ok(
        w.admin,
        () => w.service.reassign(
          c3,
          w.admin,
          department: Department.civilMaintenance,
          reason: 'Civil work needed.',
          now: at(4),
        ),
      );
      expect(doc.publicDoc['status'], 'assigned');
      expect(doc.publicDoc['assignedDepartment'], 'civilMaintenance');
      expect((doc.publicDoc['timeline'] as List<Object?>).length, events + 1);
      expect(doc.publicDoc['version'], 5);
    });

    test('a stale read or a closed complaint is a conflict and writes nothing',
        () async {
      final _World w = _World();
      final Complaint filed = await w.submit();
      final _Doc doc = w.repo.docs[filed.id]!;

      final Complaint seen = await w.read(w.verifier, filed.id);
      doc.publicDoc['version'] = 7; // somebody else wrote in between
      await expectLater(
        w.repo.update(seen.copyWith(status: ComplaintStatus.reviewed)),
        throwsA(isA<ComplaintConflictException>()),
      );
      expect(doc.publicDoc['version'], 7);
      expect(doc.publicDoc['status'], 'reported');

      final Complaint reread = await w.read(w.verifier, filed.id);
      doc.publicDoc['status'] = 'closed';
      await expectLater(
        w.repo.update(reread),
        throwsA(isA<ComplaintConflictException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('notifications are deferred (C3)', () {
    final SeedData seed = SeedData.build();
    final Complaint c = seed.complaints.first;

    test('DeferredNotificationService produces nothing and never reads the '
        'user directory', () async {
      final MockNotificationRepository store = MockNotificationRepository();
      final DeferredNotificationService service = DeferredNotificationService(
        notifications: store,
        users: const _NoDirectory(),
      );
      expect(await service.buildFor(null, c, c.timeline.first), isEmpty);
      expect(await service.emitFor(null, c, c.timeline.first), isEmpty);
      expect(await store.all(), isEmpty);
    });

    test('(positive control) the stock NotificationService reads the '
        'directory, which a non-admin client cannot', () async {
      final NotificationService stock = NotificationService(
        notifications: MockNotificationRepository(),
        users: const _NoDirectory(),
      );
      await expectLater(
        stock.buildFor(null, c, c.timeline.first),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('assembleComplaint - trustAdminDoc (the write base)', () {
    final SeedData seed = SeedData.build();
    final AppUser admin = seed.usersWithRole(UserRole.admin).first;
    final AppUser verifier = seed.usersWithRole(UserRole.verifier).first;
    final AppUser reporter = seed.userById(
      seed.complaints.first.reporter.userId,
    )!;
    final AppUser maintenance = seed.userById(
      seed.complaints
          .firstWhere((Complaint c) => c.assignment?.assigneeId != null)
          .assignment!
          .assigneeId!,
    )!;

    test('every role gets the real priority inputs, assignment and timeline '
        '(only the reporter stays a placeholder)', () {
      for (final AppUser v in <AppUser>[admin, verifier, reporter, maintenance]) {
        for (final Complaint c in seed.complaints) {
          final _Stored s = _store(c, admin);
          final Complaint got = assembleComplaint(
            publicDoc: s.publicDoc,
            adminDoc: s.adminDoc,
            viewer: v,
            trustAdminDoc: true,
          );
          expect(got, c.copyWith(reporter: _placeholder), reason: '${v.id} ${c.id}');
        }
      }
    });

    test('without trustAdminDoc a non-admin still ignores the admin document',
        () {
      final Complaint c = seed.complaints.firstWhere(
        (Complaint x) => x.assignment != null,
      );
      final _Stored s = _store(c, admin);
      final Complaint got = assembleComplaint(
        publicDoc: s.publicDoc,
        adminDoc: s.adminDoc,
        viewer: verifier,
      );
      expect(got.timeline.every((StatusEvent e) => e.actorId.isEmpty), isTrue);
      expect(got.assignment?.assignedBy, isEmpty);
    });
  });
}
