import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two themes every widget test runs under.
const List<Brightness> kBrightnesses = <Brightness>[
  Brightness.light,
  Brightness.dark,
];

/// Pumps [child] inside a themed `MaterialApp` + `Scaffold`.
///
/// Reduced motion is on, so skeleton shimmers and animated controls settle
/// and `pumpAndSettle` terminates. [size] is the logical viewport size.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(800, 1200),
  double textScale = 1,
}) {
  return pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
    brightness: brightness,
    size: size,
    textScale: textScale,
  );
}

/// Pumps a whole screen (it brings its own `Scaffold`) inside a themed
/// `MaterialApp`.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  Size size = const Size(800, 1200),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(brightness),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pump();
}
