import 'package:meta/meta.dart';

import '../models/app_user.dart';

/// A prototype login: a [user] and the [password] that signs in as them.
///
/// Mock/seed data only - Phase 2 replaces this with Firebase Auth. Passwords
/// are never part of `AppUser`.
@immutable
class MockAccount {
  const MockAccount({required this.user, required this.password});

  final AppUser user;
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockAccount && other.user == user && other.password == password;

  @override
  int get hashCode => Object.hash(user, password);

  /// Never prints the password.
  @override
  String toString() => 'MockAccount(user: ${user.id})';
}
