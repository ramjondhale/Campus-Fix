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

/// An auth backend whose sign-in always throws (to show the "couldn't sign
/// you in" error with Retry).
class ThrowingAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => null;

  @override
  Future<AppUser?> signIn(String idNumber, String password) async =>
      throw StateError('simulated outage');

  @override
  Future<void> signOut() async {}
}
