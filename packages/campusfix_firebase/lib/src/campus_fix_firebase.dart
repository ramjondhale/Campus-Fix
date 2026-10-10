import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

/// Environment name, from `--dart-define=CF_ENV=dev|prod` (default `dev`). The
/// MVP has two environments (dev now, prod later; no staging).
const String kCfEnv = String.fromEnvironment('CF_ENV', defaultValue: 'dev');

/// Whether to talk to the local Firebase Emulator Suite instead of a real
/// project (`--dart-define=CF_USE_EMULATOR=true`).
const bool kCfUseEmulator = bool.fromEnvironment('CF_USE_EMULATOR');

/// Optional emulator host override (`--dart-define=CF_EMULATOR_HOST=...`), e.g.
/// the LAN address of the dev machine for a **physical** Android device. When
/// empty the host is `10.0.2.2` on the Android emulator and `localhost`
/// elsewhere (web, desktop, iOS simulator).
const String kCfEmulatorHost = String.fromEnvironment('CF_EMULATOR_HOST');

/// Domain of the synthetic alias e-mails derived from ID numbers (plan
/// section 4). **Must equal** the seed script's `ALIAS_DOMAIN`.
const String kCfAliasDomain = String.fromEnvironment(
  'CF_ALIAS_DOMAIN',
  defaultValue: 'id.campusfix.test',
);

/// Local emulator ports; keep in sync with `backend/firebase.json`.
const int kAuthEmulatorPort = 9099;
const int kFirestoreEmulatorPort = 8080;
const int kStorageEmulatorPort = 9199;

/// Placeholder options used only in emulator mode when the caller passes none:
/// a `demo-*` project id never touches a real Firebase project, so the emulator
/// flow needs no `firebase_options.dart` and no `google-services.json`.
const FirebaseOptions _emulatorDemoOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:web:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-campusfix',
);

/// Handle on the initialized Firebase services that every `Firebase*Repository`
/// shares. Create it once in `main_firebase.dart` with [init].
class CampusFixFirebase {
  CampusFixFirebase._({
    required this.env,
    required this.app,
    required this.firestore,
    required this.auth,
    required this.usingEmulator,
    required this.aliasDomain,
  });

  /// `dev` or `prod` (see [kCfEnv]).
  final String env;
  final FirebaseApp app;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  /// True when wired to the local emulators ([kCfUseEmulator]).
  final bool usingEmulator;

  /// Domain of the alias e-mails (see [kCfAliasDomain]).
  final String aliasDomain;

  /// Initializes Firebase for [env] and, when [kCfUseEmulator] is set, points
  /// Auth and Firestore at the local emulators.
  ///
  /// [options] are the generated `DefaultFirebaseOptions.currentPlatform` of the
  /// target project. TODO(C1/C5): generate `firebase_options_<env>.dart` with
  /// `flutterfire configure` against the dev project and pass them from
  /// `main_firebase.dart` (web always needs them; Android can also use
  /// `google-services.json`). In emulator mode a `demo-campusfix` placeholder is
  /// used when [options] is null.
  static Future<CampusFixFirebase> init({
    required String env,
    FirebaseOptions? options,
    String aliasDomain = kCfAliasDomain,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    // On an Android hot restart the native app survives, so reuse it.
    final FirebaseApp app = Firebase.apps.isNotEmpty
        ? Firebase.app()
        : await Firebase.initializeApp(
            options: options ?? (kCfUseEmulator ? _emulatorDemoOptions : null),
          );

    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(app: app);
    final FirebaseAuth auth = FirebaseAuth.instanceFor(app: app);

    if (kCfUseEmulator) {
      final String host = _emulatorHost();
      try {
        // Must run before any other use of the instances.
        await auth.useAuthEmulator(host, kAuthEmulatorPort);
        firestore.useFirestoreEmulator(host, kFirestoreEmulatorPort);
        // TODO(photos): add `firebase_storage` and wire
        // `FirebaseStorage.instanceFor(app: app).useStorageEmulator(host, kStorageEmulatorPort)`
        // when photo upload lands (the MVP chunks still use sample photos).
      } on Object catch (e) {
        // A hot restart can re-run this after the SDK is already started; the
        // emulator settings from the first run are still in force.
        debugPrint('CampusFixFirebase: emulator wiring skipped ($e)');
      }
    }

    return CampusFixFirebase._(
      env: env,
      app: app,
      firestore: firestore,
      auth: auth,
      usingEmulator: kCfUseEmulator,
      aliasDomain: aliasDomain,
    );
  }

  /// Host of the emulator machine as seen from this device (see
  /// [kCfEmulatorHost]). The Android emulator cannot reach the host through
  /// `localhost`; it uses the `10.0.2.2` alias.
  static String _emulatorHost() {
    if (kCfEmulatorHost.isNotEmpty) return kCfEmulatorHost;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }
}
