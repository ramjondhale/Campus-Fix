import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards for the admin console's two house rules.
///
/// **Privacy boundary** (data-model-spec section 3.5, privacy-spec section
/// 5.1): raw `Complaint`s and reporter identity must never reach a widget. Only
/// `lib/providers/` may touch the complaint repository and raw models; screens,
/// the shell and the router consume `PublicComplaintView`s. The dashboard
/// (A-02) and the list (A-03) are built from public views only, and until the
/// A-04 detail (S5.4) exists NO file in the app may reference reporter or
/// admin-view types at all.
///
/// TODO(S5.4): the admin detail screen is the one place that builds an
/// `AdminComplaintView` and renders the reporter-identity reveal panel. When it
/// lands, extend [adminDetailDirs] / [adminIdentityPanel] below the way core's
/// PR-T14 guard (`packages/campusfix_core/test/logic/privacy_test.dart`) does:
/// `AdminComplaintView` / `toAdminView` / the raw complaint repository only
/// under `lib/features/complaint_detail/`, and `ReporterIdentity` / `.reporter`
/// only in `lib/features/complaint_detail/identity_panel.dart`. Keep the
/// "nothing else" assertions and the allow-list exact (no stale entries).
///
/// **Design system is law** (CLAUDE.md rule 1): no raw colours, ad-hoc text
/// styles or hard-coded type metrics in app code.
void main() {
  final RegExp blockComment = RegExp(r'/\*[\s\S]*?\*/');
  final RegExp lineComment = RegExp(r'//[^\n]*');
  String strip(String source) =>
      source.replaceAll(blockComment, '').replaceAll(lineComment, '');

  // Matches whole words only, so `UserRole.reporter`, `PublicComplaintView`,
  // `ComplaintService` and `ComplaintListScreen` are fine.
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

  // S5.4 fills these in (see the TODO above). Today nothing is allow-listed.
  const Set<String> adminDetailDirs = <String>{};
  const Set<String> adminIdentityPanel = <String>{};

  List<File> dartFiles(Iterable<String> roots) => roots
      .map(Directory.new)
      .where((d) => d.existsSync())
      .expand((d) => d.listSync(recursive: true))
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  List<File> uiFiles() =>
      dartFiles(<String>['lib/features', 'lib/shell', 'lib/router'])
        ..add(File('lib/app.dart'))
        ..add(File('lib/main.dart'));

  test('the scanner flags violations (positive controls)', () {
    expect(
      forbidden['ReporterIdentity']!.hasMatch('ReporterIdentity r;'),
      isTrue,
    );
    expect(
      forbidden['AdminComplaintView']!.hasMatch('AdminComplaintView v;'),
      isTrue,
    );
    expect(forbidden['toAdminView']!.hasMatch('toAdminView(c, u)'), isTrue);
    expect(
      forbidden['.reporter access']!.hasMatch('c.reporter.fullName'),
      isTrue,
    );
    expect(
      forbidden['.reporter access']!.hasMatch('UserRole.reporter'),
      isFalse,
    );
    expect(forbidden['actorId / assigneeId']!.hasMatch('e.actorId'), isTrue);
    expect(
      forbidden['complaintRepositoryProvider']!.hasMatch(
        'ref.watch(complaintRepositoryProvider)',
      ),
      isTrue,
    );
    expect(
      forbidden['raw Complaint type']!.hasMatch('List<Complaint> all'),
      isTrue,
    );
    expect(
      forbidden['raw Complaint type']!.hasMatch('PublicComplaintView v'),
      isFalse,
    );
    expect(
      forbidden['raw Complaint type']!.hasMatch('ComplaintListScreen('),
      isFalse,
    );
    expect(
      forbidden['ComplaintRepository']!.hasMatch('ComplaintService s;'),
      isFalse,
    );
  });

  test('screens, shell and router never see raw complaints or identity', () {
    final List<File> files = uiFiles();
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
    // PublicComplaintView.
    expect(RegExp(r'final _rawComplaintsProvider').hasMatch(text), isTrue);
    final Iterable<RegExpMatch> publicProviders = RegExp(
      r'^final (\w+) =\s*Provider(?:\.family)?<([^(]+?)>\(',
      multiLine: true,
    ).allMatches(text);
    expect(publicProviders.map((m) => m.group(1)), <String?>[
      'allComplaintsProvider',
      'complaintViewProvider',
    ]);
    for (final RegExpMatch m in publicProviders) {
      expect(m.group(2), contains('PublicComplaintView'), reason: m.group(1));
      expect(m.group(2), isNot(contains('<Complaint>')), reason: m.group(1));
      expect(m.group(2), isNot(matches(RegExp(r'\bComplaint\b'))));
    }
    // Public API of the library: nothing else mentions a raw complaint.
    expect(
      RegExp(
        r'^final (?!_)\w+ = StreamProvider',
        multiLine: true,
      ).hasMatch(text),
      isFalse,
      reason: 'the raw stream must stay file-private',
    );
  });

  test('the provider barrel does not re-export the raw complaint repo', () {
    final String text = strip(
      File('lib/providers/providers.dart').readAsStringSync(),
    );
    expect(
      RegExp(
        r"export 'repositories\.dart'\s+hide\s+complaintRepositoryProvider;",
      ).hasMatch(text),
      isTrue,
    );
  });

  test('reporter and admin-view types appear nowhere in lib yet', () {
    // Until S5.4 the allow-list is empty: no file may build an admin view or
    // touch reporter identity (A-02 / A-03 are aggregates and public views).
    final List<String> violations = <String>[];
    final List<String> referencing = <String>[];
    for (final File file in dartFiles(<String>['lib'])) {
      final String text = strip(file.readAsStringSync());
      for (final String name in <String>[
        'ReporterIdentity',
        'AdminComplaintView',
        'toAdminView',
        '.reporter access',
      ]) {
        if (!forbidden[name]!.hasMatch(text)) continue;
        referencing.add(file.path);
        final bool allowed =
            (name == 'ReporterIdentity' || name == '.reporter access')
            ? adminIdentityPanel.contains(file.path)
            : adminDetailDirs.any(file.path.startsWith);
        if (!allowed) violations.add('${file.path}: $name');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // The allow-list is exact: nothing is allowed that does not need it.
    expect(referencing, isEmpty);
  });

  test('only the providers library reads the complaint repository', () {
    final List<String> offenders = <String>[
      for (final File file in dartFiles(<String>['lib']))
        if (!file.path.startsWith('lib/providers/') &&
            forbidden['complaintRepositoryProvider']!.hasMatch(
              strip(file.readAsStringSync()),
            ))
          file.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('design system', () {
    // `Colors.transparent` is the one allowed literal.
    final Map<String, RegExp> rawStyle = <String, RegExp>{
      'raw Colors.*': RegExp(r'\bColors\.(?!transparent\b)\w+'),
      'Color(...) literal': RegExp(r'\bColor(?:\.fromARGB|\.fromRGBO)?\('),
      'hex literal': RegExp(r'#[0-9a-fA-F]{6}\b|0x[0-9a-fA-F]{8}\b'),
      'ad-hoc TextStyle': RegExp(r'\bTextStyle\('),
      'font metrics': RegExp(r'\b(fontSize|fontFamily|fontWeight)\s*:'),
      'literal radius': RegExp(r'\b(BorderRadius|Radius)\.circular\('),
    };

    test('the scanner flags raw styling (positive controls)', () {
      expect(rawStyle['raw Colors.*']!.hasMatch('Colors.red'), isTrue);
      expect(rawStyle['raw Colors.*']!.hasMatch('Colors.transparent'), isFalse);
      expect(
        rawStyle['Color(...) literal']!.hasMatch('Color(0xFF112233)'),
        isTrue,
      );
      expect(rawStyle['hex literal']!.hasMatch("'#0F4B59'"), isTrue);
      expect(
        rawStyle['ad-hoc TextStyle']!.hasMatch('const TextStyle('),
        isTrue,
      );
      expect(rawStyle['font metrics']!.hasMatch('fontSize: 14'), isTrue);
      expect(
        rawStyle['literal radius']!.hasMatch('BorderRadius.circular(8)'),
        isTrue,
      );
      expect(
        rawStyle['Color(...) literal']!.hasMatch('scheme.primary'),
        isFalse,
      );
      expect(
        rawStyle['ad-hoc TextStyle']!.hasMatch('theme.textTheme.bodySmall'),
        isFalse,
      );
    });

    test('app code styles only through the design system', () {
      final List<File> files = dartFiles(<String>['lib']);
      expect(files, isNotEmpty);
      final List<String> violations = <String>[];
      for (final File file in files) {
        final String text = strip(file.readAsStringSync());
        rawStyle.forEach((String name, RegExp pattern) {
          if (pattern.hasMatch(text)) violations.add('${file.path}: $name');
        });
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}
