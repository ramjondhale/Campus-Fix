import 'package:campusfix_admin/app.dart';
import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_admin/router/app_router.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// The deterministic seed the app tests run on.
final SeedData testSeed = SeedData.build();

/// The desktop window the console tests run in by default (expanded class).
const Size desktopSize = Size(1440, 900);

/// The provider overrides every test uses: no simulated latency (unless a
/// test wants to observe a loading state) and the deterministic [testSeed], so
/// state settles without real timers. A provider may be overridden only once,
/// so extra overrides must not repeat these two.
List<Override> testOverrides({Duration latency = Duration.zero}) => <Override>[
  mockLatencyProvider.overrideWithValue(latency),
  seedDataProvider.overrideWithValue(testSeed),
];

/// A container wired like the app, for provider-level tests.
ProviderContainer testContainer({List<Override> overrides = const []}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[...testOverrides(), ...overrides],
    retry: noAutoRetry,
  );
  addTearDown(container.dispose);
  return container;
}

/// Boots the whole console (router, theme, providers) in a window of [size]
/// (desktop by default). Reduced motion is on so skeleton shimmers settle and
/// `pumpAndSettle` terminates.
///
/// [overrides] are added after the standard ones (e.g. a failing repository);
/// [latency] is the simulated repository latency (zero by default).
Future<ProviderContainer> pumpAdmin(
  WidgetTester tester, {
  Size size = desktopSize,
  Duration latency = Duration.zero,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...testOverrides(latency: latency),
        ...overrides,
      ],
      retry: noAutoRetry,
      child: const CampusFixAdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(CampusFixAdminApp)),
  );
}

/// Resizes the test window (e.g. to cross a window-class breakpoint) and
/// settles.
Future<void> resizeTo(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// The seeded demo account of [role].
MockAccount demoAccount(UserRole role) =>
    testSeed.demoAccounts.firstWhere((a) => a.user.role == role);

/// Fills the Login form with the credentials of [role]'s seeded demo account
/// (whether or not the console lists it) and taps Sign in.
Future<void> signInAs(WidgetTester tester, UserRole role) async {
  final MockAccount account = demoAccount(role);
  await tester.enterText(
    find.byType(EditableText).at(0),
    account.user.idNumber,
  );
  await tester.enterText(find.byType(EditableText).at(1), account.password);
  await tester.pump();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

/// Opens [location] and settles.
Future<void> openRoute(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
}
