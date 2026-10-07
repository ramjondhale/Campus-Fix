import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard for the privacy boundary (data-model-spec section 3.5): raw
/// `Complaint`s and reporter identity must never reach a widget. Only
/// `lib/providers/` may touch the complaint repository and raw models; screens,
/// the shell and the router consume `PublicComplaintView`s.
void main() {
  final RegExp blockComment = RegExp(r'/\*[\s\S]*?\*/');
  final RegExp lineComment = RegExp(r'//[^\n]*');
  String strip(String source) =>
      source.replaceAll(blockComment, '').replaceAll(lineComment, '');

  // Matches whole words only, so `UserRole.reporter`, `PublicComplaintView`
  // and `ComplaintCard` are fine.
  final Map<String, RegExp> forbidden = <String, RegExp>{
    'ReporterIdentity': RegExp(r'\bReporterIdentity\b'),
    'AdminComplaintView': RegExp(r'\bAdminComplaintView\b'),
    'toAdminView': RegExp(r'\btoAdminView\b'),
    '.reporter access': RegExp(r'(?<!UserRole)\.reporter\b'),
    'actorId / assigneeId': RegExp(r'\b(actorId|assigneeId)\b'),
    'ComplaintRepository': RegExp(r'\bComplaintRepository\b'),
    'complaintRepositoryProvider': RegExp(r'\bcomplaintRepositoryProvider\b'),
    'raw Complaint type': RegExp(r'<Complaint>|\bComplaint\('),
  };

  test('the scanner flags violations (positive controls)', () {
    expect(
      forbidden['ReporterIdentity']!.hasMatch('ReporterIdentity r;'),
      isTrue,
    );
    expect(
      forbidden['.reporter access']!.hasMatch('c.reporter.fullName'),
      isTrue,
    );
    expect(
      forbidden['.reporter access']!.hasMatch('UserRole.reporter'),
      isFalse,
    );
    expect(
      forbidden['raw Complaint type']!.hasMatch('List<Complaint> all'),
      isTrue,
    );
    expect(
      forbidden['raw Complaint type']!.hasMatch('PublicComplaintView v'),
      isFalse,
    );
  });

  test('screens, shell and router never see raw complaints or identity', () {
    final List<File> files =
        <Directory>[
              Directory('lib/features'),
              Directory('lib/shell'),
              Directory('lib/router'),
            ]
            .expand((d) => d.listSync(recursive: true))
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..add(File('lib/app.dart'));
    expect(files, isNotEmpty);

    final List<String> violations = <String>[];
    for (final File file in files) {
      final String text = strip(file.readAsStringSync());
      forbidden.forEach((String name, RegExp pattern) {
        if (pattern.hasMatch(text)) violations.add('${file.path}: $name');
      });
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('providers expose complaints to widgets only as public views', () {
    final String text = strip(
      File('lib/providers/complaints.dart').readAsStringSync(),
    );
    // The raw stream is file-private; every public provider is typed on
    // PublicComplaintView or WorkQueue (which holds public views).
    expect(RegExp(r'final _rawComplaintsProvider').hasMatch(text), isTrue);
    final Iterable<RegExpMatch> publicProviders = RegExp(
      r'^final (\w+) =\s*Provider<([^(]+?)>\(',
      multiLine: true,
    ).allMatches(text);
    expect(publicProviders, isNotEmpty);
    for (final RegExpMatch m in publicProviders) {
      expect(m.group(2), isNot(contains('<Complaint>')), reason: m.group(1));
      expect(m.group(2), isNot(matches(RegExp(r'\bComplaint\b'))));
    }
  });

  // The ONE file that may build a `ReporterIdentity` (privacy-spec section 5.1):
  // the report-submit controller that turns the signed-in user into the
  // reporter of the new complaint. Core's PR-T14 guard allow-lists the same
  // path (as `apps/mobile/lib/providers/report_submit.dart`).
  const Set<String> reporterAllowList = <String>{
    'lib/providers/report_submit.dart',
  };

  List<File> allLibFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('ReporterIdentity appears only in the allow-listed submit file', () {
    final List<String> violations = <String>[];
    final List<String> referencing = <String>[];
    for (final File file in allLibFiles()) {
      final String text = strip(file.readAsStringSync());
      if (forbidden['ReporterIdentity']!.hasMatch(text)) {
        referencing.add(file.path);
        if (!reporterAllowList.contains(file.path)) violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // The allow-list is exact: no stale entries, nothing else on it.
    expect(referencing, unorderedEquals(reporterAllowList));
  });

  test('the submit controller never touches admin identity views', () {
    for (final String path in reporterAllowList) {
      final String text = strip(File(path).readAsStringSync());
      expect(forbidden['AdminComplaintView']!.hasMatch(text), isFalse);
      expect(forbidden['toAdminView']!.hasMatch(text), isFalse);
    }
  });
}
