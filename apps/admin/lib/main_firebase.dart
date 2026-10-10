import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/firebase_overrides.dart';

/// Firebase entrypoint (Phase 2 MVP) for the admin web console: the same app as
/// `lib/main.dart`, with the four repository providers overridden by the
/// Firebase implementations.
///
/// Run against the local emulators (see backend/README.md):
///
///     flutter run -d chrome -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true
///
/// Build for Firebase Hosting (dev):
///
///     flutter build web -t lib/main_firebase.dart --dart-define=CF_ENV=dev
///
/// Defines: `CF_ENV` (dev|prod), `CF_USE_EMULATOR`, `CF_EMULATOR_HOST`,
/// `CF_ALIAS_DOMAIN` (must equal the seed script's `ALIAS_DOMAIN`), and the
/// existing `SHOW_DEMO_ACCOUNTS` switch: the login screen's "Demo accounts"
/// quick-fill honours it as usual. Leave it on for the dev demo (the seeded users
/// share the demo password), pass `SHOW_DEMO_ACCOUNTS=false` for anything else.
///
/// `lib/main.dart` (mock, offline demo, CI) is untouched and keeps working.
Future<void> main() async {
  // initializeApp + (optionally) the Auth/Firestore emulators.
  // TODO(C1/C5): the web build always needs real options: pass
  // `options: DefaultFirebaseOptions.currentPlatform` from `flutterfire
  // configure` for the dev project (the demo-* placeholder is emulator-only).
  final CampusFixFirebase fb = await CampusFixFirebase.init(env: kCfEnv);

  // Awaits the SDK's session restore and caches the AppUser from the ID-token
  // claims, so `AuthRepository.currentUser` stays synchronous (seam S-1).
  final FirebaseAuthRepository auth = await FirebaseAuthRepository.restore(fb);

  runApp(
    ProviderScope(
      retry: noAutoRetry,
      // Overrides live in providers/firebase_overrides.dart (keeps repository
      // providers inside the providers layer for the architecture guard).
      overrides: firebaseOverrides(fb, auth),
      child: const CampusFixAdminApp(),
    ),
  );
}
