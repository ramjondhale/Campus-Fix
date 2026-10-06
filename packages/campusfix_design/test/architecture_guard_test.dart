import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards for the two rules the widget library lives by:
///
/// * the package is PII-free (privacy-spec PR-T14): no file under `lib/`
///   references `ReporterIdentity`, `AdminComplaintView` or `.reporter`;
/// * widgets consume the theme: no literal colours outside the token files.
void main() {
  final RegExp blockComment = RegExp(r'/\*[\s\S]*?\*/');
  final RegExp lineComment = RegExp(r'//[^\n]*');
  String strip(String source) =>
      source.replaceAll(blockComment, '').replaceAll(lineComment, '');

  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  group('PR-T14 privacy guard for campusfix_design/lib', () {
    final RegExp reporterType = RegExp(r'\bReporterIdentity\b');
    final RegExp reporterAccess = RegExp(r'\.reporter\b');
    final RegExp adminView = RegExp(r'\bAdminComplaintView\b');

    test('the scanner flags violations (positive controls)', () {
      expect(reporterType.hasMatch('final r = ReporterIdentity(x);'), isTrue);
      expect(reporterAccess.hasMatch('c.reporter.name'), isTrue);
      expect(reporterAccess.hasMatch('UserRole.reporter'), isTrue);
      expect(adminView.hasMatch('AdminComplaintView v;'), isTrue);
      expect(reporterAccess.hasMatch("byName('reporter')"), isFalse);
    });

    test('no widget or gallery file references identity types', () {
      final List<File> files = dartFiles('lib');
      expect(files, isNotEmpty);
      final List<String> violations = <String>[];
      for (final File file in files) {
        final String text = strip(file.readAsStringSync());
        if (reporterType.hasMatch(text) ||
            reporterAccess.hasMatch(text) ||
            adminView.hasMatch(text)) {
          violations.add(file.path);
        }
      }
      expect(violations, isEmpty, reason: 'PII references in: $violations');
    });

    test('no IdentityRevealPanel in this package (admin app, S5)', () {
      for (final File file in dartFiles('lib')) {
        expect(
          strip(file.readAsStringSync()).contains('IdentityRevealPanel'),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('nothing under lib logs a complaint', () {
      final RegExp log = RegExp(r'(?<![\w.])(print|debugPrint|log)\s*\(');
      for (final File file in dartFiles('lib')) {
        expect(
          log.hasMatch(strip(file.readAsStringSync())),
          isFalse,
          reason: file.path,
        );
      }
    });
  });

  group('theme consumption', () {
    final RegExp literalColor = RegExp(
      r'Color\(\s*0x|Color\.from(ARGB|RGBO)|(?<!\w)Colors\.(?!transparent\b)\w+',
    );

    test('widgets and gallery use no literal colours', () {
      final List<String> violations = <String>[];
      for (final String dir in <String>['lib/widgets', 'lib/gallery']) {
        for (final File file in dartFiles(dir)) {
          if (literalColor.hasMatch(strip(file.readAsStringSync()))) {
            violations.add(file.path);
          }
        }
      }
      expect(violations, isEmpty, reason: 'literal colours in: $violations');
    });

    test('widgets and gallery declare no TextStyle with a font family', () {
      final RegExp family = RegExp(r'fontFamily\s*:|GoogleFonts\.');
      for (final String dir in <String>['lib/widgets', 'lib/gallery']) {
        for (final File file in dartFiles(dir)) {
          expect(
            family.hasMatch(strip(file.readAsStringSync())),
            isFalse,
            reason: file.path,
          );
        }
      }
    });
  });
}
