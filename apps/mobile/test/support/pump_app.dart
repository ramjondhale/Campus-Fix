import 'dart:ui' show Size;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/app.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The deterministic seed the app tests run on.
final SeedData testSeed = SeedData.build();

/// The provider overrides every test uses: no simulated latency and the
/// deterministic [testSeed], so state settles without real timers.
List<Override> testOverrides() => <Override>[
  mockLatencyProvider.overrideWithValue(Duration.zero),
  seedDataProvider.overrideWithValue(testSeed),
];

/// A container wired like the app, for provider-level tests.
ProviderContainer testContainer() {
  final ProviderContainer container = ProviderContainer(
    overrides: testOverrides(),
    retry: noAutoRetry,
  );
  addTearDown(container.dispose);
  return container;
}

/// Boots the whole app (router, theme, providers) on a phone-sized view.
/// Reduced motion is on so skeleton shimmers settle and `pumpAndSettle`
/// terminates.
Future<ProviderContainer> pumpCampusFix(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(),
      retry: noAutoRetry,
      child: const CampusFixApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CampusFixApp)));
}

/// The seeded demo account of [role].
MockAccount demoAccount(UserRole role) =>
    testSeed.demoAccounts.firstWhere((a) => a.user.role == role);

/// Taps the Login quick-fill for [role], then Sign in, and settles.
Future<void> signInAs(WidgetTester tester, UserRole role) async {
  await tester.tap(find.byKey(ValueKey<String>('demo-${role.name}')));
  await tester.pump();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}
