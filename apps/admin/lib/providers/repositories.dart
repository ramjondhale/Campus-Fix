import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simulated repository latency (screens-spec G-3: 300-600 ms) so loading
/// states are demonstrable. Tests override this with [Duration.zero].
final mockLatencyProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// The prototype seed, built relative to the real clock so the demo looks
/// fresh (users, logins, complaints, notifications). Tests may override it
/// with a deterministic `SeedData.build()`.
final seedDataProvider = Provider<SeedData>(
  (ref) => SeedData.build(now: DateTime.now()),
);

/// Authentication backend (mock; Phase 2 swaps in Firebase Auth).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository.seeded(
    seed: ref.watch(seedDataProvider),
    latency: ref.watch(mockLatencyProvider),
  ),
);

/// Complaint store. **Returns raw `Complaint`s (with reporter PII)**: only the
/// providers in this directory (`lib/providers/`) may read it, and they
/// project to `PublicComplaintView` before anything reaches a widget
/// (data-model §3.5). Not re-exported by `providers.dart`.
final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => MockComplaintRepository.seeded(
    seed: ref.watch(seedDataProvider),
    latency: ref.watch(mockLatencyProvider),
  ),
);

/// In-app notification store.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => MockNotificationRepository.seeded(
    seed: ref.watch(seedDataProvider),
    latency: ref.watch(mockLatencyProvider),
  ),
);

/// Read-only user directory.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => MockUserRepository.seeded(
    seed: ref.watch(seedDataProvider),
    latency: ref.watch(mockLatencyProvider),
  ),
);
