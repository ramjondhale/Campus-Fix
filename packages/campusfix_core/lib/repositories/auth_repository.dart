import '../models/app_user.dart';

/// Authentication and the current session. The prototype binds a mock; Phase 2
/// swaps in Firebase Auth.
abstract class AuthRepository {
  /// Signs in with a student/staff [idNumber] and [password]. Returns the
  /// signed-in user, or `null` if the credentials are invalid.
  Future<AppUser?> signIn(String idNumber, String password);

  /// The signed-in user, or `null` when signed out.
  AppUser? get currentUser;

  /// Ends the current session.
  Future<void> signOut();
}
