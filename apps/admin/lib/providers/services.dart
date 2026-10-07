import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';

/// In-app notification service over the notification and user repositories.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    notifications: ref.watch(notificationRepositoryProvider),
    users: ref.watch(userRepositoryProvider),
  ),
);

/// The L3 transition executor and complaint creator. Complaint IDs continue
/// after the seed's last sequence so a new ID never collides.
final complaintServiceProvider = Provider<ComplaintService>((ref) {
  final seed = ref.watch(seedDataProvider);
  return ComplaintService(
    complaints: ref.watch(complaintRepositoryProvider),
    notifications: ref.watch(notificationRepositoryProvider),
    users: ref.watch(userRepositoryProvider),
    ids: ComplaintIdGenerator(initialCounters: seed.lastSequenceByYear),
    notificationService: ref.watch(notificationServiceProvider),
  );
});
