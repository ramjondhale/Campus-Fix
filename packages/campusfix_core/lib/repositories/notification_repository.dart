import '../models/app_notification.dart';

/// Access to in-app notifications (R11). The prototype binds an in-memory
/// mock; Phase 2 swaps in a server-backed implementation (push via FCM).
///
/// Lists are returned newest first (by `createdAt`).
abstract class NotificationRepository {
  /// Every notification, for every recipient.
  Future<List<AppNotification>> all();

  /// Notifications addressed to [recipientId].
  Future<List<AppNotification>> byRecipient(String recipientId);

  /// Stores [notification] and returns it. Throws a [StateError] if a
  /// notification with the same id already exists.
  Future<AppNotification> add(AppNotification notification);

  /// Marks the notification with [id] as read and returns the updated copy,
  /// or `null` if there is no such notification. Idempotent.
  Future<AppNotification?> markRead(String id);

  /// Marks every notification addressed to [recipientId] as read.
  Future<void> markAllRead(String recipientId);

  /// Emits [recipientId]'s notifications now and again whenever they change.
  Stream<List<AppNotification>> watchByRecipient(String recipientId);
}
