import 'package:campusfix_core/campusfix_core.dart';

import 'campus_fix_firebase.dart';

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
/// it for admins only). Both must already be passed through `documentToJson`
/// (Timestamps converted to ISO strings).
///
/// Restricted fields are filled with inert placeholders so the providers stay
/// untouched:
///
/// | field | admin | other viewers |
/// |---|---|---|
/// | `reporter` | placeholder, `userId` = viewer id only when [ownedByViewer] | same |
/// | `assignment.assigneeId` | real (from [adminDoc]) | maintenance: viewer id if [claimedByViewer], [kClaimedByColleagueId] if `claimed`, else null; others: null |
/// | `assignment.assignedBy` / `isManual` / `assignedAt` | real | placeholders |
/// | `timeline[].actorId` / `id` | real | empty / derived (`ev-<id>-NN`) |
/// | `priority`, `priorityOverride`, `severity`, `peopleAffected` | real | `priority = effectivePriority`, override null, inert defaults |
///
/// The real reporter identity is never assembled here: an admin gets it only
/// through the audited reveal (`private/identity`, TODO(C3)).
Complaint assembleComplaint({
  required Map<String, Object?> publicDoc,
  Map<String, Object?>? adminDoc,
  required AppUser viewer,
  bool ownedByViewer = false,
  bool claimedByViewer = false,
}) {
  final PublicComplaintView pub = PublicComplaintView.fromJson(publicDoc);
  final bool claimed = publicDoc['claimed'] == true;
  final Map<String, Object?>? admin = viewer.role.canSeeReporterIdentity
      ? adminDoc
      : null;

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
/// Skeleton: the signatures are final; the bodies land in
/// **C2 (reads)** and **C3 (writes)**.
class FirebaseComplaintRepository implements ComplaintRepository {
  FirebaseComplaintRepository(
    CampusFixFirebase fb, {
    required AuthRepository viewer,
  }) : _fb = fb,
       _viewer = viewer;

  // TODO(C2): used by the read methods; unused while they are stubs.
  // ignore: unused_field
  final CampusFixFirebase _fb;
  // ignore: unused_field
  final AuthRepository _viewer;

  /// `version` of each complaint as last read (optimistic concurrency, rule
  /// P8). `Complaint` has no version field, so the repository remembers it and
  /// writes `version + 1` on [update].
  // TODO(C3): populate on every read; used by update().
  // ignore: unused_field
  final Map<String, int> _versions = <String, int>{};

  /// All complaints visible to the viewer.
  ///
  /// TODO(C2): query `complaints` (bound it per plan S-11: open complaints plus
  /// recent closed), `documentToJson` each, load the viewer's `userComplaints`
  /// and `staffClaims` id sets (owner-only reads), and [assembleComplaint] each.
  /// For an admin also `get` `private/admin` per complaint (the rules have no
  /// list rule on it; see the OPEN note in firestore.rules).
  @override
  Future<List<Complaint>> all() => Future<List<Complaint>>.error(
    UnimplementedError('TODO(C2): FirebaseComplaintRepository.all'),
  );

  /// TODO(C2): `complaints/{id}` get (+ `private/admin` for an admin) +
  /// membership of the viewer's `userComplaints` / `staffClaims`; `null` when
  /// the document does not exist.
  @override
  Future<Complaint?> byId(String id) => Future<Complaint?>.error(
    UnimplementedError('TODO(C2): FirebaseComplaintRepository.byId'),
  );

  /// Complaints filed by [userId].
  ///
  /// TODO(C2): rules only let a user read their own `userComplaints/{uid}/items`,
  /// so this reads that index and fetches each complaint by id; a [userId] that
  /// is not the viewer yields an empty list (the mock's `reporter.userId`
  /// filter cannot be served for other users).
  @override
  Future<List<Complaint>> byReporter(String userId) =>
      Future<List<Complaint>>.error(
        UnimplementedError('TODO(C2): FirebaseComplaintRepository.byReporter'),
      );

  /// TODO(C2): query the public `assignedDepartment == department.name` (public
  /// by design; index `assignedDepartment` + `status`).
  @override
  Future<List<Complaint>> byDepartment(Department department) =>
      Future<List<Complaint>>.error(
        UnimplementedError(
          'TODO(C2): FirebaseComplaintRepository.byDepartment',
        ),
      );

  /// TODO(C2): query the public `status == status.name` (index `status` +
  /// `updatedAt` for the bounded variant).
  @override
  Future<List<Complaint>> byStatus(ComplaintStatus status) =>
      Future<List<Complaint>>.error(
        UnimplementedError('TODO(C2): FirebaseComplaintRepository.byStatus'),
      );

  /// Persists a new complaint prepared by `ComplaintService.submit`.
  ///
  /// TODO(C3): one `WriteBatch` / transaction: `complaints/{id}` (the 17
  /// public keys from `toPublicView(draft).toJson()` via `jsonToFirestore`,
  /// plus `version: 1`, `claimed: false`), `private/admin` (priority,
  /// priorityOverride, severity, peopleAffected, assignment, actor timeline),
  /// `private/identity` (the submitting reporter, `userId == auth.uid`) and
  /// `userComplaints/{uid}/items/{id}`; all rules in firestore.rules
  /// (`validNewComplaint`, `complaintCreatedInThisWrite`) assume this batch.
  /// Complaint ID allocation (`counters/complaintIds-{year}` transaction) is
  /// also C3; see the chunk report for the client-ID-collision caveat.
  @override
  Future<Complaint> submit(Complaint draft) => Future<Complaint>.error(
    UnimplementedError('TODO(C3): FirebaseComplaintRepository.submit'),
  );

  /// Persists changes made by `ComplaintService` (a transition or an admin edit).
  ///
  /// TODO(C3): one batch: public doc with `version + 1` (from [_versions]),
  /// appended timeline, `claimed`, `updatedAt`; `private/admin` (**diff-based**:
  /// non-admin viewers only hold placeholders for restricted fields, so write
  /// with `FieldValue.arrayUnion` for the timeline and never overwrite fields
  /// the viewer could not read); maintain `staffClaims` markers when the
  /// assignee changes. The rules (`validUpdate`, `legalRoles`) reject anything
  /// else.
  @override
  Future<Complaint> update(Complaint c) => Future<Complaint>.error(
    UnimplementedError('TODO(C3): FirebaseComplaintRepository.update'),
  );

  /// The full list now and whenever it changes.
  ///
  /// TODO(C2): bounded `complaints` snapshot listener combined with the
  /// viewer's `userComplaints` and `staffClaims` listeners (plan section 5.3),
  /// assembling each emission with [assembleComplaint].
  @override
  Stream<List<Complaint>> watchAll() => Stream<List<Complaint>>.error(
    UnimplementedError('TODO(C2): FirebaseComplaintRepository.watchAll'),
  );
}
