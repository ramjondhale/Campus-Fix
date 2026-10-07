import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaints.dart';
import 'services.dart';
import 'session.dart';

/// The signed-in user's in-app notifications, newest first. `AppNotification`
/// is PII-free by contract (privacy-spec LK-1), so it may reach widgets
/// directly. Empty when signed out. The first value goes through
/// `byRecipient` so the simulated latency yields a loading state.
final notificationsProvider = StreamProvider<List<AppNotification>>((
  ref,
) async* {
  final user = ref.watch(sessionProvider);
  if (user == null) {
    yield const [];
    return;
  }
  final service = ref.watch(notificationServiceProvider);
  yield await service.byRecipient(user.id);
  yield* service.watchByRecipient(user.id);
});

/// How many of the user's notifications are unread (Home bell / nav badge).
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref
      .watch(notificationsProvider)
      .maybeWhen(
        data: (items) => items.where((n) => !n.read).length,
        orElse: () => 0,
      ),
);

/// Re-reads the notifications (pull-to-refresh / Retry); see
/// `refreshComplaints`.
Future<void> refreshNotifications(WidgetRef ref) async {
  ref.invalidate(notificationsProvider);
  try {
    await ref.read(notificationsProvider.future);
  } catch (_) {
    // Shown by the screens as an error state with Retry.
  }
}

/// Marks one notification read (screens-spec M-12: tapping an item). The list
/// updates through the repository's change stream.
Future<void> markNotificationRead(WidgetRef ref, String id) async {
  await ref.read(notificationServiceProvider).markRead(id);
}

/// Marks all of the signed-in user's notifications read ("Mark all as read").
Future<void> markAllNotificationsRead(WidgetRef ref) async {
  final user = ref.read(sessionProvider);
  if (user == null) return;
  await ref.read(notificationServiceProvider).markAllRead(user.id);
}

/// The IDs of the complaints the signed-in user can still open from a
/// notification (screens-spec M-12): a reporter's own complaints, a
/// maintenance worker's queue, a verifier's verification queue. Anything else
/// is "No longer available". Built from the public role providers, so no raw
/// complaint is involved. Empty for any other role.
final reachableComplaintIdsProvider = Provider<AsyncValue<Set<String>>>((ref) {
  final user = ref.watch(sessionProvider);
  switch (user?.role) {
    case UserRole.reporter:
      return ref
          .watch(myComplaintsProvider)
          .whenData((mine) => {for (final c in mine) c.id});
    case UserRole.maintenance:
      return ref
          .watch(workQueueProvider)
          .whenData(
            (q) => {
              for (final c in [...q.toStart, ...q.inProgress, ...q.rework])
                c.id,
            },
          );
    case UserRole.verifier:
      return ref
          .watch(verificationQueueProvider)
          .whenData((waiting) => {for (final c in waiting) c.id});
    case UserRole.admin:
    case null:
      return const AsyncData(<String>{});
  }
});
