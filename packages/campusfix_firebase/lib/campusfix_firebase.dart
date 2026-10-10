/// CampusFix AI Firebase layer: implementations of the four `campusfix_core`
/// repository interfaces over Firebase Auth and Cloud Firestore, plus the
/// init / emulator helper.
///
/// Only this package (and the apps' `main_firebase.dart` entrypoints) imports
/// Firebase plugins. Wire it at the `ProviderScope` with provider overrides;
/// see `apps/*/lib/main_firebase.dart` and `backend/README.md`.
library;

export 'src/campus_fix_firebase.dart';
export 'src/firebase_auth_repository.dart';
export 'src/firebase_complaint_repository.dart';
export 'src/firebase_notification_repository.dart';
export 'src/firebase_user_repository.dart';
export 'src/firestore_codec.dart';
