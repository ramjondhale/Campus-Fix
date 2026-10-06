import 'dart:async';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../src/mock_support.dart';
import 'seed_data.dart';

/// In-memory [NotificationRepository] for the prototype. Lists are newest
/// first (ties broken by id, descending).
class MockNotificationRepository implements NotificationRepository {
  /// Creates a repository holding [initial]. [latency] simulates a network
  /// delay on every call.
  ///
  /// Throws an [ArgumentError] if [initial] contains a duplicate id.
  MockNotificationRepository({
    Iterable<AppNotification> initial = const [],
    this.latency = Duration.zero,
  }) {
    for (final n in initial) {
      if (_store.containsKey(n.id)) {
        throw ArgumentError('Duplicate notification id ${n.id}.');
      }
      _store[n.id] = n;
    }
  }

  /// A repository pre-loaded with the notifications of [seed] (default:
  /// `SeedData.build()`).
  factory MockNotificationRepository.seeded({
    SeedData? seed,
    Duration latency = Duration.zero,
  }) => MockNotificationRepository(
    initial: (seed ?? SeedData.build()).notifications,
    latency: latency,
  );

  /// Simulated delay applied to every call.
  final Duration latency;

  final Map<String, AppNotification> _store = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  static int _newestFirst(AppNotification a, AppNotification b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  List<AppNotification> _forRecipient(String recipientId) => [
    for (final n in _store.values)
      if (n.recipientId == recipientId) n,
  ]..sort(_newestFirst);

  @override
  Future<List<AppNotification>> all() async {
    await simulateLatency(latency);
    return _store.values.toList()..sort(_newestFirst);
  }

  @override
  Future<List<AppNotification>> byRecipient(String recipientId) async {
    await simulateLatency(latency);
    return _forRecipient(recipientId);
  }

  @override
  Future<AppNotification> add(AppNotification notification) async {
    await simulateLatency(latency);
    if (_store.containsKey(notification.id)) {
      throw StateError('Notification ${notification.id} already exists.');
    }
    _store[notification.id] = notification;
    _changes.add(null);
    return notification;
  }

  @override
  Future<AppNotification?> markRead(String id) async {
    await simulateLatency(latency);
    final current = _store[id];
    if (current == null) return null;
    if (current.read) return current;
    final updated = current.copyWith(read: true);
    _store[id] = updated;
    _changes.add(null);
    return updated;
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    await simulateLatency(latency);
    var changed = false;
    for (final entry in _store.entries.toList()) {
      final n = entry.value;
      if (n.recipientId == recipientId && !n.read) {
        _store[entry.key] = n.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _changes.add(null);
  }

  @override
  Stream<List<AppNotification>> watchByRecipient(String recipientId) =>
      snapshotStream(_changes.stream, () => _forRecipient(recipientId));
}
