import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';

/// Result of a sign-in attempt, decided by [SessionNotifier.signIn].
enum SignInOutcome {
  /// A session was started.
  success,

  /// Unknown ID or wrong password. Deliberately does not say which
  /// (non-enumerating, screens-spec M-01).
  invalidCredentials,

  /// The credentials are an admin's. The admin console is on the web; no
  /// session is started on mobile (screens-spec G-2, SC-OI-2).
  adminUsesWeb,
}

/// The signed-in user (`null` when signed out) and the sign-in / sign-out
/// actions. The state is the app's single source of truth for "who is using
/// the app": the router redirects on it and every role-aware screen reads it.
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => ref.read(authRepositoryProvider).currentUser;

  /// Signs in with [idNumber] and [password]. The password is passed straight
  /// to the auth repository and never stored.
  Future<SignInOutcome> signIn(String idNumber, String password) async {
    final auth = ref.read(authRepositoryProvider);
    final user = await auth.signIn(idNumber, password);
    if (user == null) return SignInOutcome.invalidCredentials;
    if (user.role == UserRole.admin) {
      // The repository opened a session for the admin; close it again so
      // nothing on mobile ever acts as an admin.
      await auth.signOut();
      return SignInOutcome.adminUsesWeb;
    }
    state = user;
    return SignInOutcome.success;
  }

  /// Ends the session; the router sends the user back to Login.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

/// The current session user.
final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(
  SessionNotifier.new,
);
