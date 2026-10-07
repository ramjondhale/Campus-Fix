import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards for the admin console's two house rules.
///
/// **Privacy boundary** (data-model-spec section 3.5, privacy-spec section
/// 5.1): raw `Complaint`s and reporter identity must never reach a widget. Only
/// `lib/providers/` may touch the complaint repository and raw models for the
/// public-view feeds; screens, the shell and the router consume
/// `PublicComplaintView`s. The dashboard (A-02) and the list (A-03) are built
/// from public views only.
///
/// The one exception is the A-04 detail (S5.4), the single place that builds an
/// `AdminComplaintView` and renders the reporter-identity reveal panel. The
/// allow-list mirrors core's PR-T14 guard
/// (`packages/campusfix_core/test/logic/privacy_test.dart`):
///
/// * `AdminComplaintView` / `toAdminView`, the raw complaint repository, the
///   raw `Complaint` type and `actorId` / `assigneeId` appear only under
///   [adminDetailDirs] (`lib/features/complaint_detail/`);
/// * `ReporterIdentity` / `.reporter` appear only in [adminIdentityPanel]
///   (`lib/features/complaint_detail/identity_panel.dart`).
///
/// Everything else stays fully forbidden, and the allow-list is **exact**:
/// every allow-listed path must really be used (no stale entries).
///
/// **Design system is law** (CLAUDE.md rule 1): no raw colours, ad-hoc text
/// styles or hard-coded type metrics in app code, the detail screen included.
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

  // The A-04 allow-list (mirrors core's PR-T14): the detail directory may use
  // the admin view, the raw complaint and the complaint repository; only the
  // identity panel may touch the reporter.
  const Set<String> adminDetailDirs = <String>{
    'lib/features/complaint_detail/',
  };
  const Set<String> adminIdentityPanel = <String>{
    'lib/features/complaint_detail/identity_panel.dart',
  };

  // The names only the identity panel may use; every other forbidden name is
  // allowed anywhere under the detail directory.
  const Set<String> identityNames = <String>{
    'ReporterIdentity',
    '.reporter access',
  };

  /// Whether the file at [path] may use [name] (a key of [forbidden]).
  bool isAllowed(String path, String name) => identityNames.contains(name)
      ? adminIdentityPanel.contains(path)
      : adminDetailDirs.any(path.startsWith);

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

  test('the allow-list exempts only the detail directory and the panel '
      '(positive controls)', () {
    const String panel = 'lib/features/complaint_detail/identity_panel.dart';
    const String controller =
        'lib/features/complaint_detail/complaint_detail_controller.dart';
    // The detail directory may use the admin view, the repo and raw types ...
    for (final String name in <String>[
      'AdminComplaintView',
      'toAdminView',
      'actorId / assigneeId',
      'ComplaintRepository',
      'complaintRepositoryProvider',
      'raw Complaint type',
    ]) {
      expect(isAllowed(controller, name), isTrue, reason: name);
      expect(isAllowed(panel, name), isTrue, reason: name);
      expect(
        isAllowed('lib/features/dashboard/dashboard_screen.dart', name),
        isFalse,
        reason: name,
      );
      expect(isAllowed('lib/shell/admin_shell.dart', name), isFalse);
      expect(isAllowed('lib/router/app_router.dart', name), isFalse);
      expect(isAllowed('lib/features/complaints/x.dart', name), isFalse);
    }
    // ... but the reporter only in the identity panel itself.
    for (final String name in identityNames) {
      expect(isAllowed(panel, name), isTrue, reason: name);
      expect(isAllowed(controller, name), isFalse, reason: name);
      expect(
        isAllowed('lib/features/complaint_detail/manage_dialogs.dart', name),
        isFalse,
        reason: name,
      );
      expect(isAllowed('lib/providers/complaints.dart', name), isFalse);
      expect(isAllowed('lib/features/complaints/x.dart', name), isFalse);
    }
    // A look-alike directory is not the detail directory.
    expect(
      isAllowed('lib/features/complaint_detail_extra/x.dart', 'toAdminView'),
      isFalse,
    );
  });

  test('screens, shell and router never see raw complaints or identity '
      '(outside the A-04 detail)', () {
    final List<File> files = uiFiles();
    expect(files, isNotEmpty);

    final List<String> violations = <String>[];
    for (final File file in files) {
      final String text = strip(file.readAsStringSync());
      forbidden.forEach((String name, RegExp pattern) {
        if (pattern.hasMatch(text) && !isAllowed(file.path, name)) {
          violations.add('${file.path}: $name');
        }
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

  test('reporter and admin-view types appear only in the A-04 detail '
      'directory and its identity panel', () {
    final List<String> violations = <String>[];
    // Files that really use each family of types, for the exactness checks.
    final Set<String> adminViewFiles = <String>{};
    final Set<String> identityFiles = <String>{};
    for (final File file in dartFiles(<String>['lib'])) {
      final String text = strip(file.readAsStringSync());
      for (final String name in <String>[
        'ReporterIdentity',
        'AdminComplaintView',
        'toAdminView',
        '.reporter access',
      ]) {
        if (!forbidden[name]!.hasMatch(text)) continue;
        (identityNames.contains(name) ? identityFiles : adminViewFiles).add(
          file.path,
        );
        if (!isAllowed(file.path, name)) violations.add('${file.path}: $name');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));

    // The allow-list is exact: nothing is allowed that does not need it.
    expect(
      identityFiles,
      adminIdentityPanel,
      reason: 'the identity panel must be the one file that uses the reporter',
    );
    for (final String path in adminIdentityPanel) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(
        adminDetailDirs.any(path.startsWith),
        isTrue,
        reason: 'the identity panel lives in the detail directory',
      );
    }
    for (final String dir in adminDetailDirs) {
      expect(Directory(dir).existsSync(), isTrue, reason: dir);
      expect(
        adminViewFiles.any((String f) => f.startsWith(dir)),
        isTrue,
        reason:
            'stale allow-list entry: nothing under $dir builds an admin view',
      );
    }
  });

  test('only the providers library and the A-04 detail read the complaint '
      'repository', () {
    final List<String> readers = <String>[
      for (final File file in dartFiles(<String>['lib']))
        if (forbidden['complaintRepositoryProvider']!.hasMatch(
          strip(file.readAsStringSync()),
        ))
          file.path,
    ];
    final List<String> offenders = <String>[
      for (final String path in readers)
        if (!path.startsWith('lib/providers/') &&
            !adminDetailDirs.any(path.startsWith))
          path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    // The detail's exemption is real, not a stale entry.
    for (final String dir in adminDetailDirs) {
      expect(
        readers.any((String f) => f.startsWith(dir)),
        isTrue,
        reason: 'nothing under $dir reads the complaint repository',
      );
    }
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
