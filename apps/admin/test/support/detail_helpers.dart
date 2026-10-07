import 'package:campusfix_admin/features/complaint_detail/complaint_detail_screen.dart';
import 'package:campusfix_admin/features/complaint_detail/manage_bar.dart';
import 'package:campusfix_admin/providers/repositories.dart'
    show complaintRepositoryProvider;
import 'package:campusfix_admin/router/routes.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';
import 'rendered_text.dart';

// The seed complaints the A-04 tests act on (deterministic seed).
const String kReportedPlumbing = 'CF-2026-00025'; // reported, auto-routes
const String kReportedOther = 'CF-2026-00029'; // reported, no route
const String kReviewedSafety = 'CF-2026-00023'; // reviewed, unrouted
const String kAssignedCarpenter = 'CF-2026-00014'; // assigned, override low
const String kAssignedOverridden = 'CF-2026-00010'; // assigned, override high
const String kInProgressElectrical = 'CF-2026-00011';
const String kInProgressManual = 'CF-2026-00005'; // reassigned by the admin
const String kResolvedIt = 'CF-2026-00012';
const String kVerifiedCivil = 'CF-2026-00007';
const String kClosedFurniture = 'CF-2026-00001';

/// Signs in as [role] and opens complaint [id] (A-04).
Future<ProviderContainer> openDetail(
  WidgetTester tester,
  UserRole role,
  String id, {
  Size size = desktopSize,
  List<Override> overrides = const <Override>[],
  Duration latency = Duration.zero,
}) async {
  // A second call in one test starts from a fresh app: drop the previous one
  // (and its session) first.
  await tester.pumpWidget(const SizedBox.shrink());
  final ProviderContainer container = await pumpAdmin(
    tester,
    size: size,
    overrides: overrides,
    latency: latency,
  );
  await signInAs(tester, role);
  await openRoute(tester, container, AppRoutes.complaint(id));
  return container;
}

/// The A-04 screen.
Finder get detailScreen => find.byType(ComplaintDetailScreen);

/// Every string the A-04 screen renders (its own subtree only: the shell's
/// own "Signed in as ..." is not part of the screen).
String detailText(WidgetTester tester) =>
    allRenderedText(tester, within: detailScreen);

/// The button labelled [label] among [scope] (the whole screen by default).
Finder buttonIn(String label, {Finder? scope}) {
  final Finder button = find.widgetWithText(AppButton, label);
  return scope == null ? button : find.descendant(of: scope, matching: button);
}

/// A button of the Manage bar.
Finder barButton(String label) =>
    buttonIn(label, scope: find.byType(ManageBar));

/// A button of the open dialog.
Finder dialogButton(String label) =>
    buttonIn(label, scope: find.byType(AppDialog));

bool isEnabled(WidgetTester tester, Finder button) =>
    tester.widget<AppButton>(button).onPressed != null;

/// Scrolls [target] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The labels of the buttons of the Manage bar, in order.
List<String> barLabels(WidgetTester tester) => <String>[
  for (final AppButton b in tester.widgetList<AppButton>(
    find.descendant(
      of: find.byType(ManageBar),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

/// The stored complaint [id] (read through the repository, outside the UI).
Future<Complaint> storedComplaint(
  WidgetTester tester,
  ProviderContainer container,
  String id,
) async => (await tester.runAsync(
  () => container.read(complaintRepositoryProvider).byId(id),
))!;

/// Writes [c] to the store, like another admin's change would, and settles.
Future<void> writeComplaint(
  WidgetTester tester,
  ProviderContainer container,
  Complaint c,
) async {
  await tester.runAsync(
    () => container.read(complaintRepositoryProvider).update(c),
  );
  await tester.pumpAndSettle();
}

Complaint seed(String id) => testSeed.complaints.firstWhere((c) => c.id == id);

/// The strings that identify the reporter of [c] (name, ID, e-mail, phone, id
/// and the name's words of four letters or more).
List<String> reporterSentinels(Complaint c) {
  final ReporterIdentity r = c.reporter;
  return <String>[
    r.userId,
    r.fullName,
    r.idNumber,
    r.email,
    ?r.phone,
    ...r.fullName.split(' ').where((String t) => t.length >= 4),
  ];
}

/// The identity strings of every reporter of the seed.
List<String> allReporterSentinels() => <String>[
  for (final Complaint c in testSeed.complaints) ...reporterSentinels(c),
];

/// The identity strings of every staff user (maintenance, verifier, admin) of
/// the seed.
List<String> allStaffSentinels() => <String>[
  for (final AppUser u in testSeed.users)
    if (u.role != UserRole.reporter) ...<String>[
      u.id,
      u.displayName,
      u.idNumber,
      u.email,
      ...u.displayName.split(' ').where((String t) => t.length >= 4),
    ],
];

/// The sentinels of [sentinels] that occur in [text] (case-insensitive).
List<String> leaksIn(String text, Iterable<String> sentinels) {
  final String hay = text.toLowerCase();
  return <String>{
    for (final String s in sentinels)
      if (hay.contains(s.toLowerCase())) s,
  }.toList();
}
