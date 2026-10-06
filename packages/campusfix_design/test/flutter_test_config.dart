import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Test-wide setup, run by `flutter test` before each test file.
///
/// `google_fonts` would otherwise try to fetch fonts over the network. With
/// fetching disabled, text falls back to the test font; styles and metrics
/// are unaffected. google_fonts still logs a "font not found" line per font
/// to the test output (via `debugPrint`, which the test binding does not let
/// us silence); the lines are harmless.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
