import 'package:campusfix_core/campusfix_core.dart';

/// A [NotificationService] whose **producer half is switched off**, so that
/// `ComplaintService` writes succeed on the Firebase backend before in-app
/// notifications exist (MVP chunk C3; the real fan-out is chunk C4).
///
/// ## Why it is needed
///
/// `ComplaintService.submit` and every transition call
/// `NotificationService.buildFor` **before** they persist, and `buildFor`
/// (a) lists the whole user directory through `UserRepository.all()` and
/// (b) addresses the *owner* audience at `Complaint.reporter.userId`. Under the
/// MVP rules neither works for a client:
///
/// * `users/` is listable by an admin only, and only for staff
///   (`FirebaseUserRepository.all()` throws `permission-denied` for a reporter,
///   a maintenance worker or a verifier), so the call would abort the write
///   before it reaches Firestore;
/// * the reporter's uid lives in `private/identity`, which only an admin reads,
///   and the assembled `Complaint.reporter.userId` is `''` for everyone but the
///   complaint's own reporter, so even an admin would build a notification
///   addressed to `''` (rejected by the `notifications` rule).
///
/// This class overrides [buildFor] to return nothing, so [deliver] / [emitFor]
/// store nothing and the transition commits. The **consumer half**
/// ([byRecipient], [watchByRecipient], [markRead], [markAllRead],
/// [unreadCount]) is inherited unchanged and keeps working over
/// `NotificationRepository`.
///
/// ## TODO(C4) - remove this class
///
/// C4 must give the writing client a way to resolve recipients without reading
/// the user directory or the identity document, e.g. a non-PII recipients
/// document (`complaints/{id}/private/admin.reporterId`, readable by every
/// signed-in user since the C3 rules change, plus a roster of staff ids per
/// department / role), and must build the notifications **after** `submit`
/// returns (the draft's Complaint ID is replaced by the counter-allocated ID
/// inside `FirebaseComplaintRepository.submit`, so the ids that
/// `ComplaintService.submit` builds from the draft would be wrong). Then swap
/// this for the real client fan-out, keeping the `ntf-<eventId>-<recipientId>`
/// ids.
class DeferredNotificationService extends NotificationService {
  DeferredNotificationService({
    required super.notifications,
    required super.users,
  });

  /// Always empty: no notification is produced in the MVP write path yet (see
  /// the class documentation, TODO(C4)).
  @override
  Future<List<AppNotification>> buildFor(
    Complaint? before,
    Complaint after,
    StatusEvent event,
  ) async => const <AppNotification>[];
}
