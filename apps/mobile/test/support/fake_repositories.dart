import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';

/// A complaint repository whose first [failures] reads throw (to show the
/// error state and Retry); later reads return the seed.
class FlakyComplaintRepository extends MockComplaintRepository {
  FlakyComplaintRepository({required super.initial, this.failures = 1});

  int failures;

  @override
  Future<List<Complaint>> all() async {
    if (failures > 0) {
      failures--;
      throw StateError('simulated outage');
    }
    return super.all();
  }
}

/// A complaint repository whose first read never completes (loading state).
class StalledComplaintRepository extends MockComplaintRepository {
  final Completer<List<Complaint>> never = Completer<List<Complaint>>();

  @override
  Future<List<Complaint>> all() => never.future;
}

/// A notification repository whose first read never completes (loading).
class StalledNotificationRepository extends MockNotificationRepository {
  final Completer<List<AppNotification>> never =
      Completer<List<AppNotification>>();

  @override
  Future<List<AppNotification>> byRecipient(String recipientId) => never.future;
}
