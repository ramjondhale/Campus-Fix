import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'campus_fix_firebase.dart';

/// Firebase Auth codes that mean "bad credentials". They map to `null` so the
/// login screens keep rendering the non-enumerating "ID or password is
/// incorrect". With email-enumeration protection on, unknown-user and
/// wrong-password collapse into `invalid-credential`; the older codes stay for
/// projects without it. `invalid-email` covers an ID number that cannot form a
/// valid alias address. Anything else (network, too-many-requests, ...) is
/// rethrown: both login screens already show "Couldn't sign you in" with Retry.
const Set<String> _badCredentialCodes = <String>{
  'invalid-credential',
  'user-not-found',
  'wrong-password',
  'user-disabled',
  'invalid-email',
};

/// [AuthRepository] over Firebase Auth (plan section 4).
///
/// * **Alias e-mail.** Firebase Auth has no username, so an ID number maps to
///   `<idNumber trimmed and lowercased>@<aliasDomain>`; [signIn] applies the
///   same normalization as `MockAuthRepository`.
/// * **Roles from claims.** The signed-in [AppUser]'s `role` / `department`
///   come from the ID-token **custom claims** (set by `backend/seed/seed.mjs`),
///   never from `users/{uid}`, so a profile edit can never grant a role. The
///   profile supplies `displayName`, `idNumber` and `email`.
/// * **Synchronous [currentUser] (S-1).** Cached in a field; build the
///   repository with [restore] so a persisted session is loaded before
///   `runApp`.
/// * **Additive [authChanges]** emits the session user (or `null`) whenever it
///   changes outside [signIn] / [signOut]: sign-out elsewhere, a revoked token,
///   changed claims. TODO(C1): have the apps' `SessionNotifier` listen to it
///   (an existing-file change, listed in the chunk report).
class FirebaseAuthRepository implements AuthRepository {
  /// Creates the repository without restoring a session or listening for
  /// token changes (use [restore] in the app; this is for tests).
  FirebaseAuthRepository(CampusFixFirebase fb, {String? aliasDomain})
    : _fb = fb,
      _aliasDomain = aliasDomain ?? fb.aliasDomain;

  final CampusFixFirebase _fb;
  final String _aliasDomain;

  AppUser? _current;
  bool _signingIn = false;
  StreamSubscription<User?>? _tokenSub;
  final StreamController<AppUser?> _changes =
      StreamController<AppUser?>.broadcast();

  /// Builds the repository, waits for the SDK to restore a persisted session
  /// (on the web the first auth event arrives asynchronously) and caches the
  /// signed-in [AppUser] so [currentUser] is correct on the first frame (S-1).
  /// A signed-in account without a valid `role` claim (not provisioned) is
  /// signed out.
  static Future<FirebaseAuthRepository> restore(
    CampusFixFirebase fb, {
    String? aliasDomain,
  }) async {
    final FirebaseAuthRepository repo = FirebaseAuthRepository(
      fb,
      aliasDomain: aliasDomain,
    );
    final User? user = await fb.auth.authStateChanges().first;
    if (user != null) {
      try {
        repo._current = await repo._userFor(user);
      } on FirebaseException catch (e) {
        debugPrint('FirebaseAuthRepository.restore: ${e.code}');
      }
      if (repo._current == null) await fb.auth.signOut();
    }
    repo._tokenSub = fb.auth.idTokenChanges().listen(repo._onTokenChange);
    return repo;
  }

  /// ID numbers are matched after trimming, ignoring case (same as
  /// `MockAuthRepository`).
  static String normalizeIdNumber(String idNumber) =>
      idNumber.trim().toLowerCase();

  /// The alias e-mail Firebase Auth knows [idNumber] by:
  /// `<normalized idNumber>@<aliasDomain>`. Must match what the seed script
  /// created (`ALIAS_DOMAIN`).
  static String aliasEmailFor(
    String idNumber, {
    String aliasDomain = kCfAliasDomain,
  }) => '${normalizeIdNumber(idNumber)}@$aliasDomain';

  @override
  AppUser? get currentUser => _current;

  /// Emits the session user whenever it changes outside [signIn] / [signOut]
  /// (additive seam S-1; the default `AuthRepository` has no such stream).
  Stream<AppUser?> get authChanges => _changes.stream;

  /// Signs in with [idNumber] (trimmed, case-insensitive) and [password].
  /// Returns the user, or `null` for bad credentials (any existing session is
  /// left untouched). Rethrows network and unexpected errors.
  @override
  Future<AppUser?> signIn(String idNumber, String password) async {
    if (normalizeIdNumber(idNumber).isEmpty || password.isEmpty) return null;
    _signingIn = true;
    try {
      User? user;
      try {
        final UserCredential credential = await _fb.auth
            .signInWithEmailAndPassword(
              email: aliasEmailFor(idNumber, aliasDomain: _aliasDomain),
              password: password,
            );
        user = credential.user;
      } on FirebaseAuthException catch (e) {
        if (_badCredentialCodes.contains(e.code)) return null;
        rethrow;
      }
      if (user == null) return null;

      // Force a refresh so claims set after a previous session are current.
      final AppUser? appUser = await _userFor(user, forceRefresh: true);
      if (appUser == null) {
        // Authenticated but not provisioned (no / unknown role claim): treat as
        // bad credentials (non-enumerating) and do not keep the session.
        await _fb.auth.signOut();
        return null;
      }
      _emit(appUser);
      return appUser;
    } finally {
      _signingIn = false;
    }
  }

  @override
  Future<void> signOut() async {
    _current = null; // before the await, so the token listener stays quiet
    await _fb.auth.signOut();
    _emit(null);
  }

  /// Stops listening and closes [authChanges].
  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _changes.close();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Builds the [AppUser] for [user] from its token claims (role, department)
  /// and `users/{uid}` (display name, ID number, e-mail). `null` when the
  /// token has no valid `role` claim.
  ///
  /// TODO(C1): verify against the emulator once the seed has provisioned
  /// claims; the profile fallbacks below only matter for half-provisioned
  /// accounts.
  Future<AppUser?> _userFor(User user, {bool forceRefresh = false}) async {
    final IdTokenResult token = await user.getIdTokenResult(forceRefresh);
    final Map<String, dynamic> claims =
        token.claims ?? const <String, dynamic>{};
    final UserRole? role = _enumNamed(UserRole.values, claims['role']);
    if (role == null) return null;
    final Department? department = _enumNamed(
      Department.values,
      claims['department'],
    );

    Map<String, dynamic> profile = const <String, dynamic>{};
    try {
      final snap = await _fb.firestore.collection('users').doc(user.uid).get();
      profile = snap.data() ?? const <String, dynamic>{};
    } on FirebaseException catch (e) {
      // Profile unreadable (not seeded, rules, offline): fall back to the
      // claims and the alias address rather than failing the sign-in.
      debugPrint('FirebaseAuthRepository: users/{uid} read failed (${e.code})');
    }

    final String alias = user.email ?? '';
    final String idNumber =
        (profile['idNumber'] as String?) ?? alias.split('@').first;
    return AppUser(
      id: user.uid, // uid == AppUser.id (the seed creates users that way)
      idNumber: idNumber,
      displayName: (profile['displayName'] as String?) ?? idNumber,
      role: role,
      email: (profile['email'] as String?) ?? '',
      department: department,
    );
  }

  /// Reacts to session changes that did not come from [signIn] / [signOut].
  Future<void> _onTokenChange(User? user) async {
    if (_signingIn) return; // signIn() sets the state itself
    try {
      final AppUser? cur = _current;
      if (user == null) {
        if (cur != null) _emit(null); // signed out elsewhere / token revoked
        return;
      }
      if (cur == null || cur.id != user.uid) {
        // A session appeared (e.g. another tab).
        final AppUser? appeared = await _userFor(user);
        _emit(appeared);
        if (appeared == null) await _fb.auth.signOut(); // not provisioned
        return;
      }
      // Same user, refreshed token: pick up changed claims.
      final IdTokenResult token = await user.getIdTokenResult();
      final UserRole? role = _enumNamed(UserRole.values, token.claims?['role']);
      if (role == null) {
        _emit(null); // claims were removed: end the session
        await _fb.auth.signOut();
        return;
      }
      final Department? department = _enumNamed(
        Department.values,
        token.claims?['department'],
      );
      if (role != cur.role || department != cur.department) {
        _emit(
          cur.copyWith(
            role: role,
            department: department,
            clearDepartment: department == null,
          ),
        );
      }
    } on Object catch (e) {
      debugPrint('FirebaseAuthRepository: token change not applied ($e)');
    }
  }

  void _emit(AppUser? user) {
    _current = user;
    if (!_changes.isClosed) _changes.add(user);
  }

  static T? _enumNamed<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
