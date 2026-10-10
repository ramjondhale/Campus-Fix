import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'identity_revealer.dart';
import 'repositories.dart';
import 'services.dart' show notificationServiceProvider;

/// Riverpod overrides that swap the four repository providers for their Firebase
/// implementations, used by the Firebase entrypoint (`main_firebase.dart`).
///
/// This lives under `lib/providers/` on purpose: the architecture guard requires
/// that `complaintRepositoryProvider` (and the other repository providers) be
/// referenced only here and in the A-04 detail, so the entrypoint stays free of
/// direct repository wiring and the privacy boundary is preserved.
///
/// MVP (C3/C4): the four repository providers are overridden, plus
/// `notificationServiceProvider` and `reporterIdentityRevealerProvider` (see
/// below). `complaintServiceProvider` keeps its default on purpose: writes run
/// client-side through core's `ComplaintService` over
/// `FirebaseComplaintRepository` (no server executor, no Cloud Functions; the
/// repository allocates the Complaint ID from the `counters` document, so the
/// service's local ID generator is ignored). Prod replaces it with
/// RemoteComplaintService (plan seam S-2).
///
/// **Notifications (C4).** `FirebaseNotificationService` keeps core's consumer
/// half (feed, badge, mark-read) and replaces the producer half: core's
/// `NotificationService.buildFor` needs the user directory and the reporter's
/// uid, which a non-admin client cannot read under the MVP rules, so recipients
/// are resolved from the non-PII `private/admin.reporterId` and `rosters/staff`
/// documents instead. `ComplaintService` reads `notificationServiceProvider`, so
/// swapping it here is all the wiring the fan-out needs.
///
/// **Identity reveal (plan S-5, decision D4).** The revealer makes A-04's
/// "Reveal reporter identity" ask for a reason, write the audit entry and only
/// then return the identity (`FirebaseReporterIdentityRevealer`). Without it
/// (the mock entrypoint) the panel reveals the identity the offline demo already
/// holds, as before.
List<Override> firebaseOverrides(
  CampusFixFirebase fb,
  FirebaseAuthRepository auth,
) {
  return <Override>[
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(FirebaseUserRepository(fb)),
    complaintRepositoryProvider.overrideWithValue(
      FirebaseComplaintRepository(fb, viewer: auth),
    ),
    notificationRepositoryProvider.overrideWithValue(
      FirebaseNotificationRepository(fb),
    ),
    notificationServiceProvider.overrideWith(
      (ref) => FirebaseNotificationService(
        fb: fb,
        notifications: ref.watch(notificationRepositoryProvider),
        users: ref.watch(userRepositoryProvider),
      ),
    ),
    reporterIdentityRevealerProvider.overrideWithValue(
      FirebaseReporterIdentityRevealer(fb, viewer: auth),
    ),
  ];
}
