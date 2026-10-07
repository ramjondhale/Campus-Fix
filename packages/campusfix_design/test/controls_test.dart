import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  for (final Brightness brightness in kBrightnesses) {
    group('AppButton ($brightness)', () {
      testWidgets('builds every variant in every size', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final AppButtonVariant v in AppButtonVariant.values)
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final AppButtonSize s in AppButtonSize.values)
                      AppButton(
                        label: v.name,
                        variant: v,
                        size: s,
                        leadingIcon: Icons.add,
                        onPressed: () {},
                      ),
                    AppButton(label: 'off', variant: v, onPressed: null),
                    AppButton(
                      label: 'busy',
                      variant: v,
                      loading: true,
                      onPressed: () {},
                    ),
                  ],
                ),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(AppButton), findsNWidgets(5 * 5));
      });

      testWidgets('heights follow the size spec', (WidgetTester tester) async {
        await pumpApp(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppButton(
                key: const Key('lg'),
                label: 'Large',
                size: AppButtonSize.lg,
                onPressed: () {},
              ),
              AppButton(
                key: const Key('md'),
                label: 'Medium',
                onPressed: () {},
              ),
              AppButton(
                key: const Key('sm'),
                label: 'Small',
                size: AppButtonSize.sm,
                onPressed: () {},
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(tester.getSize(find.byKey(const Key('lg'))).height, 48);
        expect(tester.getSize(find.byKey(const Key('md'))).height, 40);
        expect(tester.getSize(find.byKey(const Key('sm'))).height, 32);
      });

      testWidgets('tap calls onPressed; disabled does not', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          Column(
            children: <Widget>[
              AppButton(label: 'Go', onPressed: () => taps++),
              const AppButton(label: 'Nope', onPressed: null),
            ],
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Go'));
        await tester.tap(find.text('Nope'));
        expect(taps, 1);
      });

      testWidgets('loading keeps the width, shows a spinner, ignores taps', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppButton(
                key: const Key('idle'),
                label: 'Submit',
                onPressed: () => taps++,
              ),
              AppButton(
                key: const Key('busy'),
                label: 'Submit',
                loading: true,
                onPressed: () => taps++,
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(
          tester.getSize(find.byKey(const Key('busy'))).width,
          tester.getSize(find.byKey(const Key('idle'))).width,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byKey(const Key('busy')));
        expect(taps, 0);
      });

      testWidgets('keyboard focus draws the ring and Enter activates', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          AppButton(label: 'Go', onPressed: () => taps++),
          brightness: brightness,
        );
        // Move focus into the button with the keyboard.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final BuildContext context = tester.element(find.byType(AppButton));
        final Finder ring = find.byWidgetPredicate(
          (Widget w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).border is Border) &&
              ((w.decoration as BoxDecoration).border! as Border).top.color ==
                  context.campusColors.focusRing &&
              ((w.decoration as BoxDecoration).border! as Border).top.width ==
                  AppStateLayer.focusRingWidth,
        );
        expect(ring, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(taps, 1);
      });
    });

    group('AppTextField ($brightness)', () {
      testWidgets('label above, required asterisk, helper text', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 320,
            child: AppTextField(
              label: 'Description',
              required: true,
              helperText: AppTextField.visibilityHelper,
            ),
          ),
          brightness: brightness,
        );
        expect(
          find.textContaining('Description', findRichText: true),
          findsOneWidget,
        );
        // The asterisk carries the semantics label ", required".
        expect(
          find.textContaining('required', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Visible to people involved'), findsOneWidget);
        // The label sits above the control.
        expect(
          tester
              .getTopLeft(
                find.textContaining('Description', findRichText: true),
              )
              .dy,
          lessThan(tester.getTopLeft(find.byType(TextField)).dy),
        );
      });

      testWidgets(
        'error state shows an icon and the message, not colour alone',
        (WidgetTester tester) async {
          await pumpApp(
            tester,
            const SizedBox(
              width: 320,
              child: AppTextField(
                label: 'Complaint ID',
                errorText: 'Enter an ID like CF-2026-00042.',
              ),
            ),
            brightness: brightness,
          );
          expect(find.text('Enter an ID like CF-2026-00042.'), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
        },
      );

      testWidgets('disabled does not accept input; typing updates counter', (
        WidgetTester tester,
      ) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        await pumpApp(
          tester,
          Column(
            children: <Widget>[
              SizedBox(
                width: 320,
                child: AppTextField.multiline(
                  label: 'Note',
                  controller: controller,
                  maxLength: 80,
                ),
              ),
              const SizedBox(
                width: 320,
                child: AppTextField(
                  key: Key('off'),
                  label: 'Off',
                  enabled: false,
                ),
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(find.text('0/80'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'Hello');
        await tester.pump();
        expect(find.text('5/80'), findsOneWidget);
        final TextField disabled = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('off')),
            matching: find.byType(TextField),
          ),
        );
        expect(disabled.enabled, isFalse);
      });

      testWidgets('password field toggles visibility', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 320,
            child: AppTextField.password(label: 'Password'),
          ),
          brightness: brightness,
        );
        TextField field() => tester.widget<TextField>(find.byType(TextField));
        expect(field().obscureText, isTrue);
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        expect(field().obscureText, isFalse);
      });

      testWidgets('numeric field filters non-digits', (
        WidgetTester tester,
      ) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        await pumpApp(
          tester,
          SizedBox(
            width: 320,
            child: AppTextField.numeric(label: 'Count', controller: controller),
          ),
          brightness: brightness,
        );
        await tester.enterText(find.byType(TextField), '12ab3');
        expect(controller.text, '123');
      });
    });

    group('AppSelect ($brightness)', () {
      final List<AppSelectOption<String>> options = <AppSelectOption<String>>[
        for (final String b in <String>['A', 'B', 'C'])
          AppSelectOption<String>(value: b, label: 'Block $b'),
      ];

      testWidgets('compact: opens a bottom sheet and reports the choice', (
        WidgetTester tester,
      ) async {
        String? picked;
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => SizedBox(
              width: 320,
              child: AppSelect<String>(
                label: 'Building',
                options: options,
                value: picked,
                onChanged: (String v) => setState(() => picked = v),
              ),
            ),
          ),
          brightness: brightness,
          size: const Size(390, 844),
        );
        expect(find.text('Select'), findsOneWidget);
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(find.text('Block B'), findsOneWidget);
        await tester.tap(find.text('Block B'));
        await tester.pumpAndSettle();
        expect(picked, 'B');
        expect(find.text('Block B'), findsOneWidget);
      });

      testWidgets('more than 8 options adds a search field', (
        WidgetTester tester,
      ) async {
        final List<AppSelectOption<int>> many = <AppSelectOption<int>>[
          for (int i = 0; i < 12; i++)
            AppSelectOption<int>(value: i, label: 'Room $i'),
        ];
        await pumpApp(
          tester,
          SizedBox(
            width: 320,
            child: AppSelect<int>(
              label: 'Room',
              options: many,
              value: null,
              onChanged: (int v) {},
            ),
          ),
          brightness: brightness,
          size: const Size(390, 844),
        );
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSearchField), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Room 11');
        await tester.pumpAndSettle();
        final Finder inList = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        );
        expect(inList, findsOneWidget);
        expect(find.text('Room 2'), findsNothing);
      });

      testWidgets('disabled select does not open', (WidgetTester tester) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 320,
            child: AppSelect<String>(
              label: 'Building',
              options: options,
              value: 'A',
              onChanged: null,
            ),
          ),
          brightness: brightness,
          size: const Size(390, 844),
        );
        await tester.tap(find.text('Block A'));
        await tester.pumpAndSettle();
        expect(find.text('Block B'), findsNothing);
      });

      // The wide (medium / expanded) path renders an anchored `MenuAnchor`
      // instead of a bottom sheet. Its panel measures intrinsic sizes, which a
      // shrink-wrapping ListView cannot answer.
      const Map<String, Size> wideWindows = <String, Size>{
        'medium': Size(800, 1200),
        'expanded': Size(1280, 900),
      };
      for (final MapEntry<String, Size> window in wideWindows.entries) {
        testWidgets('${window.key}: opens an anchored menu and reports the '
            'choice', (WidgetTester tester) async {
          String? picked;
          await pumpApp(
            tester,
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) => SizedBox(
                width: 320,
                child: AppSelect<String>(
                  label: 'Building',
                  options: options,
                  value: picked,
                  onChanged: (String v) => setState(() => picked = v),
                ),
              ),
            ),
            brightness: brightness,
            size: window.value,
          );
          expect(find.text('Select'), findsOneWidget);
          await tester.tap(find.text('Select'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Every option is rendered by the menu.
          expect(find.text('Block A'), findsOneWidget);
          expect(find.text('Block B'), findsOneWidget);
          expect(find.text('Block C'), findsOneWidget);
          await tester.tap(find.text('Block B'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(picked, 'B');
          // The menu closed and the field now shows the choice.
          expect(find.text('Block A'), findsNothing);
          expect(find.text('Block B'), findsOneWidget);
        });
      }

      testWidgets('wide: a long list is capped, scrolls and can be searched', (
        WidgetTester tester,
      ) async {
        final List<AppSelectOption<int>> many = <AppSelectOption<int>>[
          for (int i = 0; i < 40; i++)
            AppSelectOption<int>(value: i, label: 'Room $i'),
        ];
        int? picked;
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => SizedBox(
              width: 320,
              child: AppSelect<int>(
                label: 'Room',
                options: many,
                value: picked,
                onChanged: (int v) => setState(() => picked = v),
              ),
            ),
          ),
          brightness: brightness,
          size: const Size(1280, 900),
        );
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AppSearchField), findsOneWidget);

        // Capped: 40 rows are 40 x 48 px tall, the menu is far shorter, and
        // it is no wider than the 320 px anchor.
        final Finder scroller = find
            .ancestor(
              of: find.text('Room 0'),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final Rect viewport = tester.getRect(scroller);
        expect(viewport.height, lessThanOrEqualTo(360));
        expect(viewport.width, lessThanOrEqualTo(320));
        // Scrolls: the last row starts below the viewport until dragged to.
        expect(
          tester.getTopLeft(find.text('Room 39')).dy,
          greaterThan(viewport.bottom),
        );
        await tester.drag(scroller, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final Rect last = tester.getRect(find.text('Room 39'));
        expect(last.top, greaterThanOrEqualTo(viewport.top));
        expect(last.bottom, lessThanOrEqualTo(viewport.bottom));

        // Searching narrows the list; the survivor is tappable.
        await tester.enterText(find.byType(TextField).last, 'Room 11');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Room 2'), findsNothing);
        // Scoped to the rows: the search field itself now reads "Room 11".
        await tester.tap(
          find.descendant(
            of: find.byType(AppPressable),
            matching: find.text('Room 11'),
          ),
        );
        await tester.pumpAndSettle();
        expect(picked, 11);
      });

      testWidgets('wide: dense select opens and shows a selected row', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 240,
            child: AppSelect<String>(
              dense: true,
              options: options,
              value: 'B',
              onChanged: (String v) {},
            ),
          ),
          brightness: brightness,
          size: const Size(1280, 900),
        );
        await tester.tap(find.text('Block B'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Block A'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    });

    group('toggles and tiles ($brightness)', () {
      testWidgets('AppSwitchRow toggles; locked row does not', (
        WidgetTester tester,
      ) async {
        bool value = false;
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => Column(
              children: <Widget>[
                AppSwitchRow(
                  title: 'Safety issue',
                  value: value,
                  onChanged: (bool v) => setState(() => value = v),
                ),
                const AppSwitchRow(
                  title: 'Locked',
                  helper: 'Set automatically.',
                  value: true,
                  onChanged: null,
                  locked: true,
                ),
              ],
            ),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Safety issue'));
        await tester.pump();
        expect(value, isTrue);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        await tester.tap(find.text('Locked'));
        await tester.pump();
        expect(value, isTrue);
      });

      testWidgets('AppSegmented selects and marks the selection with a check', (
        WidgetTester tester,
      ) async {
        String selected = 'all';
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                AppSegmented<String>(
                  segments: const <AppSegment<String>>[
                    AppSegment<String>(value: 'all', label: 'All'),
                    AppSegment<String>(value: 'active', label: 'Active'),
                    AppSegment<String>(value: 'closed', label: 'Closed'),
                  ],
                  selected: selected,
                  onChanged: (String v) => setState(() => selected = v),
                ),
          ),
          brightness: brightness,
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        await tester.tap(find.text('Closed'));
        await tester.pump();
        expect(selected, 'closed');
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(
          tester.getSize(find.byType(AppSegmented<String>)).height,
          AppLayout.controlHeightAdmin,
        );
      });

      testWidgets(
        'SelectTile: selected shows the indicator, disabled is inert',
        (WidgetTester tester) async {
          int taps = 0;
          await pumpApp(
            tester,
            Column(
              children: <Widget>[
                SelectTile(
                  title: 'Severe',
                  hint: 'People cannot use the room',
                  selected: true,
                  onTap: () => taps++,
                ),
                const SelectTile(
                  title: 'Minor',
                  selected: false,
                  onTap: null,
                  enabled: false,
                ),
              ],
            ),
            brightness: brightness,
          );
          await tester.tap(find.text('Severe'));
          await tester.tap(find.text('Minor'));
          expect(taps, 1);
          expect(find.text('People cannot use the room'), findsOneWidget);
        },
      );

      testWidgets('AppCheckboxRow and AppRadioRow respond to taps', (
        WidgetTester tester,
      ) async {
        bool checked = false;
        String group = 'a';
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => Column(
              children: <Widget>[
                AppCheckboxRow(
                  label: 'Confirm',
                  value: checked,
                  onChanged: (bool v) => setState(() => checked = v),
                ),
                RadioGroup<String>(
                  groupValue: group,
                  onChanged: (String? v) => setState(() => group = v ?? 'a'),
                  child: const Column(
                    children: <Widget>[
                      AppRadioRow<String>(value: 'a', label: 'Option A'),
                      AppRadioRow<String>(value: 'b', label: 'Option B'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        expect(checked, isTrue);
        await tester.tap(find.text('Option B'));
        await tester.pump();
        expect(group, 'b');
      });

      testWidgets('AppFilterChip: count pill, toggle check, disabled', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          Wrap(
            spacing: 8,
            children: <Widget>[
              AppFilterChip(
                label: 'Status',
                selected: true,
                count: 3,
                onTap: () => taps++,
              ),
              AppFilterChip(
                label: 'Include closed',
                kind: AppFilterChipKind.toggle,
                selected: true,
                onTap: () => taps++,
              ),
              const AppFilterChip(label: 'Dept', selected: false, onTap: null),
            ],
          ),
          brightness: brightness,
        );
        expect(find.text('3'), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
        expect(find.byIcon(Icons.check), findsOneWidget);
        await tester.tap(find.text('Status'));
        await tester.tap(find.text('Dept'));
        expect(taps, 1);
      });

      testWidgets('AppSearchField shows the clear button once there is text', (
        WidgetTester tester,
      ) async {
        String? last;
        await pumpApp(
          tester,
          SizedBox(
            width: 320,
            child: AppSearchField(onChanged: (String v) => last = v),
          ),
          brightness: brightness,
        );
        expect(find.text(AppSearchField.defaultHint), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
        await tester.enterText(find.byType(TextField), 'CF-2026');
        await tester.pump();
        expect(find.byIcon(Icons.close), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(last, '');
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });
  }

  group('text scaling', () {
    testWidgets('buttons and tiles survive 200% text without overflow', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: Column(
            children: <Widget>[
              AppButton(label: 'Mark as resolved', onPressed: () {}),
              CategoryTile(
                category: ProblemCategory.safety,
                selected: true,
                onTap: () {},
              ),
              const StatusBadge(status: ComplaintStatus.inProgress),
            ],
          ),
        ),
        textScale: 2,
        size: const Size(400, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
