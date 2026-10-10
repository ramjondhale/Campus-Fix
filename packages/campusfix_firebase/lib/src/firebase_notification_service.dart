import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'campus_fix_firebase.dart';

// The MVP client-side notification producer (phase-2-mvp.md, chunk C4).
//
// `ComplaintService` already calls `NotificationService.buildFor` / `deliver`
// around every write; this class is what it is given on the Firebase backend. It
// replaces core's default recipient resolution, which cannot run for a non-admin
// writer: it lists the user directory (`users/` is admin-only) and addresses the
// owner at `Complaint.reporter.userId` (`private/identity`, admin-only; the
// assembled complaint carries `''`).

/// The non-PII ids the producer needs, grouped by audience: the document
/// `rosters/staff` (written by the seed, readable by every signed-in user).
///
/// ```text
/// { maintenance: { <Department.name>: [uid, ...] },   // e.g. "itTeam"
///   verifiers:   [uid, ...],                          // verifier role only
///   admins:      [uid, ...] }                         // admin role only
/// ```
///
/// uids only: never a name, e-mail or ID number. `backend/seed/seed.mjs`
/// (`buildStaffRoster`) writes this exact shape; keep both in sync.
class StaffRoster {
  const StaffRoster({
    this.maintenance = const <String, List<String>>{},
    this.verifiers = const <String>[],
    this.admins = const <String>[],
  });

  /// Parses the `rosters/staff` data. Missing or malformed parts read as empty
  /// (a roster that cannot be parsed addresses nobody; it never throws).
  factory StaffRoster.fromJson(Map<String, Object?>? json) {
    if (json == null) return empty;
    final Object? rawMaintenance = json['maintenance'];
    return StaffRoster(
      maintenance: <String, List<String>>{
        if (rawMaintenance is Map)
          for (final Object? department in rawMaintenance.keys)
            if (department is String)
              department: _uids(rawMaintenance[department]),
      },
      verifiers: _uids(json['verifiers']),
      admins: _uids(json['admins']),
    );
  }

  /// Addresses nobody.
  static const StaffRoster empty = StaffRoster();

  /// `maintenance` uids per [Department.name].
  final Map<String, List<String>> maintenance;

  /// `verifier` uids (admins are not included; see [verifiersAndAdmins]).
  final List<String> verifiers;

  /// `admin` uids.
  final List<String> admins;

  /// Whether the roster names nobody (a missing / unseeded document).
  bool get isEmpty =>
      verifiers.isEmpty &&
      admins.isEmpty &&
      maintenance.values.every((List<String> ids) => ids.isEmpty);

  /// The `maintenance` staff of [department].
  List<String> maintenanceOf(Department department) =>
      maintenance[department.name] ?? const <String>[];

  /// The "verifiers" audience of the notification templates: every verifier
  /// **and** every admin.
  List<String> get verifiersAndAdmins => <String>[...verifiers, ...admins];

  static List<String> _uids(Object? value) => <String>[
    if (value is List)
      for (final Object? id in value)
        if (id is String && id.isNotEmpty) id,
  ];
}

/// The two lookups the producer makes, as a seam so the recipient logic is
/// unit-testable without Firestore ([FirestoreNotificationRecipientSource] is the
/// real one).
abstract interface class NotificationRecipientSource {
  /// The uid of the reporter of [complaintId] (`private/admin.reporterId`), or
  /// `null` when it is not there.
  Future<String?> reporterIdOf(String complaintId);

  /// The staff roster (`rosters/staff`); [StaffRoster.empty] when absent.
  Future<StaffRoster> staffRoster();
}

/// [NotificationRecipientSource] over Firestore: one `get` on
/// `complaints/{id}/private/admin` (readable by every signed-in user since C3)
/// and one on `rosters/staff`. Neither document holds PII.
class FirestoreNotificationRecipientSource
    implements NotificationRecipientSource {
  FirestoreNotificationRecipientSource(FirebaseFirestore firestore)
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<String?> reporterIdOf(String complaintId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('private')
        .doc('admin')
        .get();
    final Object? id = snap.data()?['reporterId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  Future<StaffRoster> staffRoster() async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('rosters')
        .doc('staff')
        .get();
    return StaffRoster.fromJson(snap.data());
  }
}

/// A [NotificationService] whose **producer half** resolves recipients without
/// the user directory or `private/identity`, so every role's client can fan
/// notifications out (MVP chunk C4; the production design is a server-side
/// executor).
///
/// What it changes against core's [NotificationService]: only who the
/// templated messages are addressed to ([buildFor]) and how a re-delivery is
/// treated ([deliver]). Templates, the one-message-per-person rule, the
/// `ntf-<event id>-<recipient id>` ids and `createdAt = event.at` are the same,
/// and the consumer half (feed, badge, mark-read) is inherited unchanged.
///
/// ## Recipients (all non-PII)
///
/// | audience | resolved from |
/// |---|---|
/// | owner | `after.reporter.userId` when set (the submit path), else `complaints/{id}/private/admin.reporterId` (one `get`, cached per complaint) |
/// | department | `rosters/staff.maintenance[<department>]` |
/// | verifiers | `rosters/staff.verifiers` + `rosters/staff.admins` |
/// | admins | `rosters/staff.admins` |
///
/// `rosters/staff` is read once per instance and kept. An audience that cannot
/// be resolved (no reporter id, a roster that is missing or unreadable) is
/// skipped: a notification with an empty `recipientId` is rejected by the rules,
/// and a notification problem must not fail the complaint write it belongs to
/// (a failed lookup is logged with `debugPrint`, never rethrown).
///
/// ## Idempotent delivery
///
/// Ids are deterministic, so a retried write produces the same document. The
/// rules allow creating a notification but not overwriting one (the recipient
/// may only flip `read`), and the writer cannot read the document to check, so a
/// re-delivery surfaces as a `permission-denied` `FirebaseException` from
/// `FirebaseNotificationRepository.add`. [deliver] treats that as "already
/// delivered" and carries on; any other error is rethrown.
///
/// Ordering note: `ComplaintService.submit` calls [buildFor] **after**
/// `FirebaseComplaintRepository.submit` returns (the repository replaces the
/// draft's Complaint ID with the counter-allocated one), so the notification
/// ids and `complaintId` carry the stored ID.
class FirebaseNotificationService extends NotificationService {
  FirebaseNotificationService({
    required CampusFixFirebase fb,
    required NotificationRepository notifications,
    required UserRepository users,
  }) : this.withSource(
         recipients: FirestoreNotificationRecipientSource(fb.firestore),
         notifications: notifications,
         users: users,
       );

  /// The producer over an explicit [recipients] lookup (the seam used by the
  /// unit tests). [users] is required by the base class and never read.
  FirebaseNotificationService.withSource({
    required NotificationRecipientSource recipients,
    required super.notifications,
    required super.users,
  }) : _recipients = recipients,
       _store = notifications;

  final NotificationRecipientSource _recipients;
  final NotificationRepository _store;

  /// `rosters/staff`, once read (an empty / failed read is not kept, so a roster
  /// seeded later is picked up).
  StaffRoster? _roster;

  /// `reporterId` per complaint id (immutable once written, rules), so a
  /// Review & Route composite (two events) reads it once.
  final Map<String, String> _reporterIds = <String, String>{};

  @override
  Future<List<AppNotification>> buildFor(
    Complaint? before,
    Complaint after,
    StatusEvent event,
  ) async {
    final NotificationTrigger? trigger = NotificationTemplates.triggerFor(
      before?.status,
      event.status,
    );
    if (trigger == null) return const <AppNotification>[];

    final List<NotificationDraft> drafts = NotificationTemplates.plan(
      trigger,
      after,
      previousDepartment: before?.assignment?.department,
      note: event.note,
    );

    final List<AppNotification> built = <AppNotification>[];
    final Set<String> addressed = <String>{};
    for (final NotificationDraft draft in drafts) {
      for (final String recipientId in await _recipientsOf(draft, after)) {
        // First message of the template wins; never address an empty id.
        if (recipientId.isEmpty || !addressed.add(recipientId)) continue;
        built.add(
          AppNotification(
            id: 'ntf-${event.id}-$recipientId',
            recipientId: recipientId,
            complaintId: after.id,
            type: draft.type,
            title: draft.title,
            body: draft.body,
            createdAt: event.at,
          ),
        );
      }
    }
    return List<AppNotification>.unmodifiable(built);
  }

  /// Stores [items] (in parallel). A `permission-denied` on a deterministic id
  /// is an idempotent re-delivery and counts as stored; see the class
  /// documentation.
  @override
  Future<List<AppNotification>> deliver(Iterable<AppNotification> items) async {
    final List<AppNotification> batch = List<AppNotification>.of(items);
    await Future.wait<void>(<Future<void>>[
      for (final AppNotification n in batch) _put(n),
    ]);
    return List<AppNotification>.unmodifiable(batch);
  }

  Future<void> _put(AppNotification n) async {
    try {
      await _store.add(n);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint(
        'FirebaseNotificationService: ${n.id} already delivered '
        '(permission-denied on a deterministic id)',
      );
    }
  }

  Future<List<String>> _recipientsOf(
    NotificationDraft draft,
    Complaint c,
  ) async {
    switch (draft.audience) {
      case NotificationAudience.owner:
        final String direct = c.reporter.userId;
        if (direct.isNotEmpty) return <String>[direct];
        final String? stored = await _reporterIdOf(c.id);
        return stored == null ? const <String>[] : <String>[stored];
      case NotificationAudience.department:
        final Department? department = draft.department;
        if (department == null) return const <String>[];
        return (await _staffRoster()).maintenanceOf(department);
      case NotificationAudience.verifiers:
        return (await _staffRoster()).verifiersAndAdmins;
      case NotificationAudience.admins:
        return (await _staffRoster()).admins;
    }
  }

  Future<String?> _reporterIdOf(String complaintId) async {
    final String? cached = _reporterIds[complaintId];
    if (cached != null) return cached;
    try {
      final String? id = await _recipients.reporterIdOf(complaintId);
      if (id == null || id.isEmpty) return null;
      return _reporterIds[complaintId] = id;
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseNotificationService: no reporterId for $complaintId '
        '(${e.code}); the owner is not notified',
      );
      return null;
    }
  }

  Future<StaffRoster> _staffRoster() async {
    final StaffRoster? cached = _roster;
    if (cached != null) return cached;
    try {
      final StaffRoster read = await _recipients.staffRoster();
      if (!read.isEmpty) _roster = read;
      return read;
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseNotificationService: rosters/staff unreadable (${e.code}); '
        'staff are not notified',
      );
      return StaffRoster.empty;
    }
  }
}
