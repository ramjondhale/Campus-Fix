import 'dart:ui' show CheckedState;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  for (final Brightness brightness in kBrightnesses) {
    group('StatusBadge ($brightness)', () {
      testWidgets('shows every status label, never abbreviated', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ComplaintStatus s in ComplaintStatus.values)
                StatusBadge(status: s),
              for (final ComplaintStatus s in ComplaintStatus.values)
                StatusBadge(status: s, size: AppTagSize.sm),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        for (final ComplaintStatus s in ComplaintStatus.values) {
          // One md and one sm badge per status.
          expect(find.text(s.label), findsNWidgets(2));
        }
      });

      testWidgets('uses the status palette and the pill shape', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const StatusBadge(status: ComplaintStatus.closed),
          brightness: brightness,
        );
        final BuildContext context = tester.element(find.byType(StatusBadge));
        final SemanticStyle style = context.statusStyle(ComplaintStatus.closed);
        final Container container = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusBadge),
            matching: find.byType(Container),
          ),
        );
        final BoxDecoration decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, style.bg);
        expect(decoration.borderRadius, AppRadius.brFull);
        final Text text = tester.widget<Text>(find.text('Closed'));
        expect(text.style!.color, style.fg);
      });

      testWidgets('semantics: "Status: In Progress"', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          const StatusBadge(status: ComplaintStatus.inProgress),
          brightness: brightness,
        );
        expect(find.bySemanticsLabel('Status: In Progress'), findsOneWidget);
        handle.dispose();
      });
    });

    group('PriorityTag ($brightness)', () {
      testWidgets('shows every priority label in both sizes', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Priority p in Priority.values)
                PriorityTag(priority: p),
              for (final Priority p in Priority.values)
                PriorityTag(priority: p, size: AppTagSize.sm),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        for (final Priority p in Priority.values) {
          expect(find.text(p.label), findsNWidgets(2));
        }
      });

      testWidgets('critical is a solid block; the others are tonal', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const Column(
            children: <Widget>[
              PriorityTag(priority: Priority.critical),
              PriorityTag(priority: Priority.low),
            ],
          ),
          brightness: brightness,
        );
        final BuildContext context = tester.element(
          find.byType(PriorityTag).first,
        );
        expect(context.priorityStyle(Priority.critical).isSolid, isTrue);
        expect(context.priorityStyle(Priority.low).isSolid, isFalse);
      });

      testWidgets('Overridden marker only when requested', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const PriorityTag(priority: Priority.high),
          brightness: brightness,
        );
        expect(find.text('Overridden'), findsNothing);
        await pumpApp(
          tester,
          const PriorityTag(priority: Priority.high, overridden: true),
          brightness: brightness,
        );
        expect(find.text('Overridden'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
      });

      testWidgets('semantics: "Priority: Critical"', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          const PriorityTag(priority: Priority.critical),
          brightness: brightness,
        );
        expect(find.bySemanticsLabel('Priority: Critical'), findsOneWidget);
        handle.dispose();
      });
    });

    group('CategoryTile and CategoryChip ($brightness)', () {
      testWidgets('one tile per ProblemCategory with its label', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final ProblemCategory c in ProblemCategory.values)
                SizedBox(
                  width: 240,
                  child: CategoryTile(
                    category: c,
                    selected: c == ProblemCategory.civil,
                    onTap: () {},
                  ),
                ),
            ],
          ),
          brightness: brightness,
          size: const Size(1100, 900),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CategoryTile), findsNWidgets(8));
        for (final ProblemCategory c in ProblemCategory.values) {
          expect(find.text(c.label), findsOneWidget);
        }
        // Exactly one tile shows the selected check badge.
        expect(
          find.descendant(
            of: find.byType(CategoryTile),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
      });

      testWidgets('safety and other carry their fixed helper text', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Column(
            children: <Widget>[
              CategoryTile(
                category: ProblemCategory.safety,
                selected: false,
                onTap: () {},
              ),
              CategoryTile(
                category: ProblemCategory.other,
                selected: false,
                onTap: () {},
              ),
              CategoryTile(
                category: ProblemCategory.it,
                selected: false,
                onTap: () {},
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(
          find.text('For immediate danger contact campus security directly'),
          findsOneWidget,
        );
        expect(find.text('Will be reviewed manually'), findsOneWidget);
      });

      testWidgets('tap selects; disabled tile ignores taps', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          Column(
            children: <Widget>[
              CategoryTile(
                category: ProblemCategory.electrical,
                selected: false,
                onTap: () => taps++,
              ),
              CategoryTile(
                category: ProblemCategory.plumbing,
                selected: false,
                onTap: () => taps += 100,
                enabled: false,
              ),
            ],
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Electrical'));
        await tester.tap(find.text('Plumbing / Water / Washroom'));
        expect(taps, 1);
      });

      testWidgets('selected tile exposes radio semantics', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          CategoryTile(
            category: ProblemCategory.electrical,
            selected: true,
            onTap: () {},
          ),
          brightness: brightness,
        );
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('Electrical'),
        );
        expect(
          node.getSemanticsData().flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        handle.dispose();
      });

      testWidgets('CategoryChip builds in every size', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            children: <Widget>[
              for (final ProblemCategory c in ProblemCategory.values)
                for (final CategoryChipSize s in CategoryChipSize.values)
                  CategoryChip(category: c, size: s),
            ],
          ),
          brightness: brightness,
        );
        expect(find.byType(CategoryChip), findsNWidgets(32));
      });
    });

    group('ComplaintIdText ($brightness)', () {
      testWidgets('renders the id exactly as stored in all three sizes', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const Column(
            children: <Widget>[
              ComplaintIdText(id: 'CF-2026-00042'),
              ComplaintIdText(id: 'CF-2026-00042', size: ComplaintIdSize.md),
              ComplaintIdText(id: 'CF-2026-00042', size: ComplaintIdSize.lg),
            ],
          ),
          brightness: brightness,
        );
        expect(find.text('CF-2026-00042'), findsNWidgets(3));
        // Copy icons only on md and lg.
        expect(find.byIcon(Icons.content_copy), findsNWidgets(2));
      });

      testWidgets('tap copies the id and shows the toast', (
        WidgetTester tester,
      ) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              copied =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        int callbacks = 0;
        await pumpApp(
          tester,
          ComplaintIdText(
            id: 'CF-2026-00042',
            size: ComplaintIdSize.md,
            onCopied: () => callbacks++,
          ),
          brightness: brightness,
        );
        await tester.tap(find.byType(ComplaintIdText));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(copied, 'CF-2026-00042');
        expect(callbacks, 1);
        expect(find.text('Copied CF-2026-00042'), findsOneWidget);
      });

      testWidgets('sm is not tappable', (WidgetTester tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') copied = 'copied';
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpApp(
          tester,
          const ComplaintIdText(id: 'CF-2026-00042'),
          brightness: brightness,
        );
        await tester.tap(find.text('CF-2026-00042'));
        await tester.pump();
        expect(copied, isNull);
      });
    });
  }
}
