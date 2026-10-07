import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';

/// The roles that may use the admin web console (screens-spec A-01, G-2):
/// admins (full) and verifiers (limited). Reporters and maintenance staff
/// authenticate fine but get E-403 on every console route.
const Set<UserRole> kConsoleRoles = <UserRole>{
  UserRole.admin,
  UserRole.verifier,
};

/// Whether [role] may use the admin web console.
bool mayUseConsole(UserRole role) => kConsoleRoles.contains(role);

/// Result of a sign-in attempt, decided by [SessionNotifier.signIn].
enum SignInOutcome {
  /// A console session (admin or verifier) was started.
  success,

  /// Unknown ID or wrong password. Deliberately does not say which
  /// (non-enumerating, screens-spec M-01).
  invalidCredentials,

  /// The credentials are valid but belong to a role that has no business on
  /// the admin web (reporter, maintenance). The session is kept so the router
  /// can show E-403 with a Sign out action (AC-45); no console route or data
  /// is reachable with it (screens-spec G-2).
  notAuthorized,
}

/// The signed-in user (`null` when signed out) and the sign-in / sign-out
/// actions. The state is the console's single source of truth for "who is
/// using the app": the router redirects on it and every role-aware widget
/// reads it.
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => ref.read(authRepositoryProvider).currentUser;

  /// Signs in with [idNumber] and [password]. The password is passed straight
  /// to the auth repository and never stored.
  Future<SignInOutcome> signIn(String idNumber, String password) async {
    final auth = ref.read(authRepositoryProvider);
    final user = await auth.signIn(idNumber, password);
    if (user == null) return SignInOutcome.invalidCredentials;
    state = user;
    return mayUseConsole(user.role)
        ? SignInOutcome.success
        : SignInOutcome.notAuthorized;
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
