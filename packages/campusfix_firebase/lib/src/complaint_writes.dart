import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'firestore_codec.dart';

// The pure half of the MVP client-side write path (phase-2-mvp.md, chunk C3).
//
// `FirebaseComplaintRepository.submit` / `update` are thin Firestore
// transactions around the functions in this file, so everything that decides
// *what is written* is unit-testable without Firebase or an emulator
// (`test/complaint_write_test.dart`). The shapes below are exactly what
// `backend/firestore.rules` accepts: `validNewComplaint`, `validUpdate`,
// `validPrivateAdmin`, the `staffClaims` / `userComplaints` index rules and the
// `counters` rule. Change one side and the other must follow.

/// Highest Complaint ID sequence the 5-digit format holds (the same cap as
/// core's `ComplaintIdGenerator`, and the cap in the `counters` rule).
const int kMaxComplaintSequence = ComplaintIdGenerator.maxSequence;

/// The `counters/{doc}` id that holds the last Complaint ID sequence of [year]:
/// `complaintIds-YYYY` (the shape the `counters` rule requires). Plan seam S-3,
/// MVP rule delta (e).
String complaintCounterDocId(int year) =>
    'complaintIds-${year.toString().padLeft(4, '0')}';

/// The Complaint ID `CF-YYYY-NNNNN` for [sequence] of [year] (the format of
/// core's `ComplaintIdGenerator` and of `validNewComplaint`).
String complaintIdFor(int year, int sequence) =>
    'CF-${year.toString().padLeft(4, '0')}-'
    '${sequence.toString().padLeft(5, '0')}';

/// Thrown by [FirebaseComplaintRepository.update] when the complaint cannot be
/// written because it is not the one the caller read: somebody changed it in
/// between (optimistic concurrency, rule P8), it is `closed` (INV-4), or its
/// history no longer matches. Nothing was written; re-read and retry.
///
/// The message never contains complaint content or identity.
class ComplaintConflictException implements Exception {
  const ComplaintConflictException(this.complaintId, this.message);

  /// The complaint that conflicted.
  final String complaintId;

  /// What is wrong, in a sentence.
  final String message;

  @override
  String toString() => 'ComplaintConflictException($complaintId): $message';
}

/// [draft] under its allocated Complaint ID [id].
///
/// `ComplaintService.submit` fills the draft with an ID from its local
/// `ComplaintIdGenerator`, which the Firebase repository ignores (S-3): the
/// real ID comes from the `counters` transaction. The ID is also embedded in
/// the TL-1 event ids (`ev-<id>-NN`), so those are rewritten too.
Complaint withAllocatedId(Complaint draft, String id) => draft.copyWith(
  id: id,
  timeline: <StatusEvent>[
    for (int i = 0; i < draft.timeline.length; i++)
      draft.timeline[i].copyWith(
        id: 'ev-$id-${(i + 1).toString().padLeft(2, '0')}',
      ),
  ],
);

/// `private/admin` of [c] (plan section 5.2): priority inputs, the full
/// assignment and the actor-bearing timeline, dates as Firestore `Timestamp`s,
/// plus [reporterId].
///
/// **[reporterId]** is the reporter's opaque uid and nothing else (never the
/// name, ID number, e-mail or phone, which stay in `private/identity`). It lets
/// the writing client address the *owner* notification without reading the
/// admin-only identity document (chunk C4); `private/admin` is readable by every
/// signed-in user since C3. It is set at submit and carried over unchanged on
/// every update (the rules make it immutable). The app never shows it.
Map<String, Object?> adminDocFor(Complaint c, {required String reporterId}) =>
    jsonToFirestore(<String, Object?>{
          'reporterId': reporterId,
          'priority': c.priority.name,
          'priorityOverride': c.priorityOverride?.name,
          'severity': c.severity.name,
          'peopleAffected': c.peopleAffected.name,
          'assignment': c.assignment?.toJson(),
          'timeline': <Object?>[
            for (final StatusEvent e in c.timeline) e.toJson(),
          ],
        })!
        as Map<String, Object?>;

/// The four documents one new complaint is written as, in one batch (rules
/// `validNewComplaint` + `complaintCreatedInThisWrite`).
class NewComplaintDocs {
  const NewComplaintDocs({
    required this.publicDoc,
    required this.adminDoc,
    required this.identityDoc,
    required this.ownedDoc,
  });

  /// `complaints/{id}`: the 17 `PublicComplaintView` keys plus `version: 1`
  /// and `claimed: false` (19 keys, every one present, as the rule requires).
  final Map<String, Object?> publicDoc;

  /// `complaints/{id}/private/admin`.
  final Map<String, Object?> adminDoc;

  /// `complaints/{id}/private/identity`: the reporter (PII; the rule requires
  /// `userId == auth.uid`).
  final Map<String, Object?> identityDoc;

  /// `userComplaints/{reporterUid}/items/{id}`: the ownership marker.
  final Map<String, Object?> ownedDoc;
}

/// The documents for a **new** complaint [c] (already carrying its allocated
/// ID, see [withAllocatedId]): status `reported`, one timeline event.
NewComplaintDocs newComplaintDocs(Complaint c) {
  final Map<String, Object?> publicJson = <String, Object?>{
    ...toPublicView(c).toJson(),
    'version': 1,
    'claimed': false,
  };
  return NewComplaintDocs(
    publicDoc: jsonToFirestore(publicJson)! as Map<String, Object?>,
    adminDoc: adminDocFor(c, reporterId: c.reporter.userId),
    identityDoc: <String, Object?>{...c.reporter.toJson()},
    ownedDoc:
        jsonToFirestore(<String, Object?>{
              'complaintId': c.id,
              'createdAt': c.createdAt.toIso8601String(),
            })!
            as Map<String, Object?>,
  );
}

/// What one `update` writes (the output of [planComplaintUpdate]).
class ComplaintUpdatePlan {
  const ComplaintUpdatePlan({
    required this.version,
    required this.publicFields,
    required this.adminFields,
    this.releaseClaimOf,
    this.takeClaimFor,
  });

  /// The `version` the complaint has after the write (`expected + 1`, rule P8).
  final int version;

  /// Fields to `update` on `complaints/{id}`: only the mutable ones (status,
  /// effective priority, safety flag, department, resolution note, after
  /// photos, the timeline, `updatedAt`, `version`, `claimed`). The core fields
  /// (id, category, title, location, description, `createdAt`) and the
  /// before photos are never rewritten, so the rule's `coreFieldsUnchanged`
  /// holds by construction.
  final Map<String, Object?> publicFields;

  /// Fields to `update` on `complaints/{id}/private/admin` (all seven keys,
  /// `reporterId` carried over from the stored document).
  final Map<String, Object?> adminFields;

  /// The assignee whose `staffClaims/{uid}/items/{id}` marker must be deleted
  /// (the assignee left or changed), or `null`.
  final String? releaseClaimOf;

  /// The assignee whose `staffClaims/{uid}/items/{id}` marker must be created
  /// (an assignee was set or changed), or `null`.
  final String? takeClaimFor;
}

/// Plans the write of [next] (the complaint after a `ComplaintService`
/// transition or admin edit) on top of the **stored** documents.
///
/// * [storedPublic] / [storedAdmin] are the raw Firestore data of
///   `complaints/{id}` and `complaints/{id}/private/admin` read **inside the
///   transaction** (so they cannot change before the commit); [storedAdmin] is
///   `null` when that document does not exist.
/// * [expectedVersion] is the `version` the caller's read saw. A different
///   stored version means somebody wrote in between: the plan is refused with
///   a [ComplaintConflictException] (the same check the rules make with
///   `version == previous + 1`, made early with a clear error).
///
/// **Append-only timeline.** The public timeline is the *stored* list, passed
/// back untouched, plus one public event per `next.timeline` entry the store
/// does not have yet. Re-encoding the stored events would risk changing a
/// value, and the rules require the stored prefix to be equal.
///
/// **Claim markers.** The old assignee comes from the stored `private/admin`,
/// the new one from [next]; [ComplaintUpdatePlan.releaseClaimOf] /
/// [ComplaintUpdatePlan.takeClaimFor] are set only when they differ.
///
/// **`reporterId`.** [next] is assembled for the acting user, so its
/// `reporter.userId` is `''` unless the actor is the reporter; the uid written
/// back to `private/admin` is the stored one (falling back to [next]'s when the
/// stored document predates the field). Throws a [StateError] when neither
/// names a reporter: writing `''` would break the owner notification.
///
/// Throws a [ComplaintConflictException] when the stored version differs, the
/// complaint is `closed` (INV-4), or [next]'s timeline does not extend the
/// stored one.
ComplaintUpdatePlan planComplaintUpdate({
  required Map<String, dynamic> storedPublic,
  required Map<String, dynamic>? storedAdmin,
  required Complaint next,
  required int expectedVersion,
}) {
  final Object? storedVersion = storedPublic['version'];
  if (storedVersion is! num || storedVersion.toInt() != expectedVersion) {
    throw ComplaintConflictException(
      next.id,
      'This complaint changed since it was read.',
    );
  }
  if (storedPublic['status'] == ComplaintStatus.closed.name) {
    throw ComplaintConflictException(
      next.id,
      'This complaint is closed and cannot be changed.',
    );
  }

  final Object? rawTimeline = storedPublic['timeline'];
  final List<Object?> storedTimeline = rawTimeline is List
      ? List<Object?>.from(rawTimeline)
      : <Object?>[];
  if (next.timeline.length < storedTimeline.length) {
    throw ComplaintConflictException(
      next.id,
      'The status history is shorter than the stored one.',
    );
  }
  for (int i = 0; i < storedTimeline.length; i++) {
    final Object? stored = storedTimeline[i];
    if (stored is! Map || stored['status'] != next.timeline[i].status.name) {
      throw ComplaintConflictException(
        next.id,
        'The status history does not extend the stored one.',
      );
    }
  }

  final List<Object?> publicTimeline = <Object?>[
    ...storedTimeline,
    for (final StatusEvent e in next.timeline.skip(storedTimeline.length))
      jsonToFirestore(
        PublicStatusEvent(
          status: e.status,
          actorRole: e.actorRole,
          note: e.note,
          at: e.at,
        ).toJson(),
      ),
  ];

  final Object? storedReporterId = storedAdmin?['reporterId'];
  final String reporterId =
      storedReporterId is String && storedReporterId.isNotEmpty
      ? storedReporterId
      : next.reporter.userId;
  if (reporterId.isEmpty) {
    throw StateError(
      'private/admin of ${next.id} has no reporterId (a document from before '
      'chunk C4): re-run the seed.',
    );
  }

  final int version = expectedVersion + 1;
  final String? assignee = next.assignment?.assigneeId;
  final Object? rawAssignment = storedAdmin?['assignment'];
  final String? previousAssignee = rawAssignment is Map
      ? rawAssignment['assigneeId'] as String?
      : null;

  return ComplaintUpdatePlan(
    version: version,
    publicFields: <String, Object?>{
      'status': next.status.name,
      'effectivePriority': next.effectivePriority.name,
      'safetyFlag': next.safetyFlag,
      'assignedDepartment': next.assignment?.department.name,
      'resolutionNote': next.resolutionNote,
      'afterPhotos': jsonToFirestore(<Object?>[
        for (final Attachment a in next.afterPhotos) a.toJson(),
      ]),
      'timeline': publicTimeline,
      'updatedAt': Timestamp.fromDate(next.updatedAt),
      'version': version,
      'claimed': assignee != null,
    },
    adminFields: adminDocFor(next, reporterId: reporterId),
    releaseClaimOf: previousAssignee != null && previousAssignee != assignee
        ? previousAssignee
        : null,
    takeClaimFor: assignee != null && assignee != previousAssignee
        ? assignee
        : null,
  );
}
