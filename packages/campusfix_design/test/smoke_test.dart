import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  for (final Brightness b in kBrightnesses) {
    testWidgets('gallery builds ($b)', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        WidgetGalleryScreen(initialBrightness: b),
        brightness: b,
        size: const Size(1280, 900),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gallery builds at phone width', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const WidgetGalleryScreen(),
      size: const Size(390, 844),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
