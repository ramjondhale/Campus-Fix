import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'repositories.dart';

/// Riverpod overrides that swap the four repository providers for their Firebase
/// implementations, used by the Firebase entrypoint (`main_firebase.dart`).
///
/// This lives under `lib/providers/` on purpose: it keeps the repository
/// providers referenced only inside the providers layer, so the entrypoint stays
/// free of direct repository wiring and the privacy boundary is preserved.
///
/// MVP: only the four repository providers are overridden.
/// `complaintServiceProvider` and `notificationServiceProvider` keep their
/// defaults on purpose — writes run client-side through core's ComplaintService /
/// NotificationService over the repositories below (no server executor, no Cloud
/// Functions). Prod replaces them with RemoteComplaintService /
/// ClientNotificationService (plan seams S-2, S-9). The service's local
/// Complaint-ID generator is a known C3 item (see the chunk report).
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
  ];
}
