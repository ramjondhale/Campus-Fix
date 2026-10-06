import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Test-wide setup, run by `flutter test` before each test file.
///
/// `google_fonts` would otherwise try to fetch fonts over the network. With
/// fetching disabled, text falls back to the test font; styles and metrics
/// are unaffected. google_fonts still logs a "font not found" line per font
/// to the test output (via `debugPrint`, which the test binding does not let
/// us silence); the lines are harmless.
///
/// The test font (Ahem) draws every glyph as a 1 em square, which is far
/// wider than Archivo, Public Sans or JetBrains Mono and makes layout tests
/// report overflows that cannot happen on a device. When the Flutter SDK's
/// bundled Roboto files are available, they are registered under the family
/// names `google_fonts` asks for, so text has realistic proportional widths.
/// If the files are missing the tests still run, with the Ahem fallback.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadProportionalFonts();
  await testMain();
}

/// google_fonts family name -> bundled Roboto file with a similar weight.
const Map<String, String> _standIns = <String, String>{
  'regular': 'Roboto-Regular.ttf',
  '500': 'Roboto-Medium.ttf',
  '600': 'Roboto-Bold.ttf',
  '700': 'Roboto-Bold.ttf',
};

const List<String> _families = <String>[
  'Archivo',
  'PublicSans',
  'JetBrainsMono',
];

Future<void> _loadProportionalFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final String dir = '$root/bin/cache/artifacts/material_fonts';
  for (final MapEntry<String, String> weight in _standIns.entries) {
    final File file = File('$dir/${weight.value}');
    if (!file.existsSync()) continue;
    final Uint8List bytes = file.readAsBytesSync();
    for (final String family in _families) {
      final FontLoader loader = FontLoader('${family}_${weight.key}')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  }
}
