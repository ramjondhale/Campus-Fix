import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_design/theme/extensions/semantic_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme builds', () {
    for (final (String name, ThemeData Function() build, Brightness b)
        in <(String, ThemeData Function(), Brightness)>[
          ('light', AppTheme.light, Brightness.light),
          ('dark', AppTheme.dark, Brightness.dark),
        ]) {
      test('$name theme is Material 3 with the contract tokens', () {
        final ThemeData theme = build();
        final AppColorTokens c = AppColors.of(b);
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, b);
        expect(theme.colorScheme.brightness, b);
        expect(theme.colorScheme.primary, c.primary);
        expect(theme.colorScheme.surface, c.canvas);
        expect(theme.scaffoldBackgroundColor, c.canvas);
        expect(theme.visualDensity, VisualDensity.standard);
      });

      test('$name theme carries all four extensions', () {
        final ThemeData theme = build();
        expect(theme.extension<CampusColors>(), isNotNull);
        expect(theme.extension<CategoryPalette>(), isNotNull);
        expect(theme.extension<PriorityPalette>(), isNotNull);
        expect(theme.extension<StatusPalette>(), isNotNull);
      });

      test('$name text theme: onSurface colour and typography scale', () {
        final TextTheme t = build().textTheme;
        final AppColorTokens c = AppColors.of(b);
        for (final TextStyle? s in <TextStyle?>[
          t.displayLarge,
          t.headlineMedium,
          t.titleLarge,
          t.bodyLarge,
          t.labelSmall,
        ]) {
          expect(s!.color, c.onSurface);
        }
        expect(t.bodyLarge!.fontSize, 16);
        expect(t.bodyMedium!.fontSize, 14);
        expect(t.labelLarge!.fontWeight, FontWeight.w600);
      });

      test('$name component themes follow contract 10.3', () {
        final ThemeData theme = build();
        final AppColorTokens c = AppColors.of(b);

        // cardTheme: elevation 0, outlineVariant side, radius r4.
        final CardThemeData card = theme.cardTheme;
        expect(card.elevation, 0);
        expect(card.color, c.card);
        final RoundedRectangleBorder cardShape =
            card.shape! as RoundedRectangleBorder;
        expect(cardShape.side.color, c.outlineVariant);
        expect(cardShape.side.width, 1);
        expect(cardShape.borderRadius, AppRadius.br4);

        // appBarTheme: elevation 0, scrolledUnder 0, tint transparent.
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.appBarTheme.surfaceTintColor, const Color(0x00000000));
        expect(theme.appBarTheme.backgroundColor, c.canvas);
        expect(theme.appBarTheme.toolbarHeight, 56);

        // Navigation.
        expect(theme.navigationBarTheme.height, 64);
        expect(theme.navigationBarTheme.backgroundColor, c.card);
        expect(theme.navigationBarTheme.indicatorColor, c.primaryContainer);
        expect(theme.navigationRailTheme.minWidth, 72);

        // Dialog and sheet float on `raised` with the contract scrim.
        expect(theme.dialogTheme.backgroundColor, c.raised);
        expect(theme.dialogTheme.barrierColor, AppColors.scrim(b));
        expect(theme.bottomSheetTheme.backgroundColor, c.raised);
        expect(theme.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());

        // Toast.
        expect(theme.snackBarTheme.backgroundColor, c.inverseSurface);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);

        // Dividers and progress.
        expect(theme.dividerTheme.color, c.outlineVariant);
        expect(theme.dividerTheme.thickness, 1);
        expect(theme.progressIndicatorTheme.color, c.primary);
        expect(theme.progressIndicatorTheme.strokeWidth, 2);

        // Inputs: label above the control, so no floating label.
        expect(
          theme.inputDecorationTheme.floatingLabelBehavior,
          FloatingLabelBehavior.never,
        );
        expect(theme.inputDecorationTheme.fillColor, c.card);
      });

      test('$name filled button: primary, hover and pressed backgrounds', () {
        final AppColorTokens c = AppColors.of(b);
        final ButtonStyle style = build().filledButtonTheme.style!;
        Color? bg(Set<WidgetState> s) => style.backgroundColor!.resolve(s);
        expect(bg(<WidgetState>{}), c.primary);
        expect(bg(<WidgetState>{WidgetState.hovered}), c.primaryHover);
        expect(bg(<WidgetState>{WidgetState.pressed}), c.primaryPressed);
        expect(style.foregroundColor!.resolve(<WidgetState>{}), c.onPrimary);
        // Disabled: container onSurface 12%, content onSurface 38%.
        expect(
          bg(<WidgetState>{WidgetState.disabled})!.a,
          closeTo(AppStateLayer.disabledContainer, 1 / 255),
        );
        expect(
          style.foregroundColor!.resolve(<WidgetState>{
            WidgetState.disabled,
          })!.a,
          closeTo(AppStateLayer.disabledContent, 1 / 255),
        );
      });

      test('$name text field border: outline, hover, focus and error', () {
        final AppColorTokens c = AppColors.of(b);
        final InputBorder border = build().inputDecorationTheme.border!;
        BorderSide side(Set<WidgetState> s) =>
            (border as WidgetStateInputBorder).resolve(s).borderSide;
        expect(side(<WidgetState>{}).color, c.outline);
        expect(side(<WidgetState>{}).width, 1);
        expect(side(<WidgetState>{WidgetState.hovered}).color, c.onSurface);
        expect(side(<WidgetState>{WidgetState.focused}).color, c.primary);
        expect(side(<WidgetState>{WidgetState.focused}).width, 2);
        expect(side(<WidgetState>{WidgetState.error}).color, c.error);
        expect(side(<WidgetState>{WidgetState.error}).width, 2);
      });
    }

    test('light and dark differ', () {
      expect(
        AppTheme.light().colorScheme.primary,
        isNot(AppTheme.dark().colorScheme.primary),
      );
      expect(AppTheme.of(Brightness.dark).brightness, Brightness.dark);
      expect(AppTheme.of(Brightness.light).brightness, Brightness.light);
    });
  });

  group('semantic styles resolve for every enum value in both themes', () {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      final String name = theme.brightness.name;
      test('$name: ProblemCategory (8)', () {
        final CategoryPalette p = theme.extension<CategoryPalette>()!;
        expect(ProblemCategory.values, hasLength(8));
        for (final ProblemCategory v in ProblemCategory.values) {
          final CategoryStyle s = p.styleFor(v);
          expect(s, isNotNull, reason: v.name);
          expect(p[v], s);
          expect(AppCategoryIcons.of(v), isA<IconData>());
        }
      });
      test('$name: Priority (4)', () {
        final PriorityPalette p = theme.extension<PriorityPalette>()!;
        expect(Priority.values, hasLength(4));
        for (final Priority v in Priority.values) {
          expect(p.styleFor(v), isNotNull, reason: v.name);
        }
      });
      test('$name: ComplaintStatus (7)', () {
        final StatusPalette p = theme.extension<StatusPalette>()!;
        expect(ComplaintStatus.values, hasLength(7));
        for (final ComplaintStatus v in ComplaintStatus.values) {
          expect(p.styleFor(v), isNotNull, reason: v.name);
        }
      });
      test('$name: FeedbackKind (4)', () {
        final CampusColors c = theme.extension<CampusColors>()!;
        for (final FeedbackKind v in FeedbackKind.values) {
          expect(c.feedbackStyle(v), isNotNull, reason: v.name);
        }
      });
    }

    test('light and dark styles differ for the same key', () {
      expect(
        CategoryPalette.light.styleFor(ProblemCategory.electrical),
        isNot(CategoryPalette.dark.styleFor(ProblemCategory.electrical)),
      );
    });

    test('a palette missing a key is rejected', () {
      expect(
        () => CategoryPalette(
          styles: <ProblemCategory, SemanticStyle>{
            ProblemCategory.electrical: CategoryPalette.light.styleFor(
              ProblemCategory.electrical,
            ),
          },
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => stylesFromTokens<ProblemCategory>(
          group: 'category',
          values: ProblemCategory.values,
          tokens: const <String, SemanticStyle>{},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ThemeExtension copyWith and lerp', () {
    const SemanticStyle red = SemanticStyle(
      fg: Color(0xFFFF0000),
      bg: Color(0xFFFF0000),
      accent: Color(0xFFFF0000),
    );

    test('copyWith overrides only the given keys', () {
      final CategoryPalette p = CategoryPalette.light.copyWith(
        styles: <ProblemCategory, SemanticStyle>{ProblemCategory.it: red},
      );
      expect(p.styleFor(ProblemCategory.it), red);
      expect(
        p.styleFor(ProblemCategory.safety),
        CategoryPalette.light.styleFor(ProblemCategory.safety),
      );
      expect(
        CategoryPalette.light.copyWith(),
        isNot(same(CategoryPalette.light)),
      );
    });

    test('lerp endpoints equal the inputs', () {
      for (final (String n, StatusPalette a, StatusPalette b)
          in <(String, StatusPalette, StatusPalette)>[
            ('status', StatusPalette.light, StatusPalette.dark),
          ]) {
        final StatusPalette start = a.lerp(b, 0);
        final StatusPalette end = a.lerp(b, 1);
        for (final ComplaintStatus s in ComplaintStatus.values) {
          expect(start.styleFor(s), a.styleFor(s), reason: '$n ${s.name}');
          expect(end.styleFor(s), b.styleFor(s), reason: '$n ${s.name}');
        }
      }
      final PriorityPalette mid = PriorityPalette.light.lerp(
        PriorityPalette.dark,
        0.5,
      );
      expect(
        mid.styleFor(Priority.high).bg,
        Color.lerp(
          PriorityPalette.light.styleFor(Priority.high).bg,
          PriorityPalette.dark.styleFor(Priority.high).bg,
          0.5,
        ),
      );
      expect(CategoryPalette.light.lerp(null, 0.5), CategoryPalette.light);
    });

    test('CampusColors copyWith and lerp', () {
      final CampusColors l = CampusColors.light;
      final CampusColors d = CampusColors.dark;
      expect(
        l.copyWith(card: const Color(0xFF123456)).card,
        const Color(0xFF123456),
      );
      expect(l.copyWith().cardSubtle, l.cardSubtle);
      expect(l.lerp(d, 0).raised, l.raised);
      expect(l.lerp(d, 1).raised, d.raised);
      expect(
        l.lerp(d, 1).feedbackStyle(FeedbackKind.info),
        d.feedbackStyle(FeedbackKind.info),
      );
      expect(CampusColors.of(Brightness.dark), same(d));
    });

    test('SemanticStyle equality, markColor and isSolid', () {
      expect(
        red,
        const SemanticStyle(
          fg: Color(0xFFFF0000),
          bg: Color(0xFFFF0000),
          accent: Color(0xFFFF0000),
        ),
      );
      expect(red.copyWith(fg: const Color(0xFF000000)), isNot(red));
      expect(red.isSolid, isTrue);
      expect(red.markColor, red.fg);
      final SemanticStyle tonal = StatusPalette.light.styleFor(
        ComplaintStatus.resolved,
      );
      expect(tonal.isSolid, isFalse);
      expect(tonal.markColor, tonal.accent);
    });

    test('ThemeData.lerp between light and dark does not throw', () {
      final ThemeData mid = ThemeData.lerp(
        AppTheme.light(),
        AppTheme.dark(),
        0.5,
      );
      expect(mid.extension<StatusPalette>(), isNotNull);
      expect(mid.extension<CampusColors>(), isNotNull);
    });
  });

  group('BuildContext helpers', () {
    Future<void> pumpProbe(
      WidgetTester tester, {
      required ThemeData theme,
      Size size = const Size(400, 800),
      bool disableAnimations = false,
      required void Function(BuildContext context) probe,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: Builder(
            builder: (BuildContext context) {
              probe(context);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('style helpers read the active theme', (tester) async {
      await pumpProbe(
        tester,
        theme: AppTheme.dark(),
        probe: (BuildContext context) {
          expect(
            context.categoryStyle(ProblemCategory.safety),
            CategoryPalette.dark.styleFor(ProblemCategory.safety),
          );
          expect(
            context.priorityStyle(Priority.critical),
            PriorityPalette.dark.styleFor(Priority.critical),
          );
          expect(
            context.statusStyle(ComplaintStatus.inProgress),
            StatusPalette.dark.styleFor(ComplaintStatus.inProgress),
          );
          expect(
            context.feedbackStyle(FeedbackKind.error),
            CampusColors.dark.feedbackStyle(FeedbackKind.error),
          );
          expect(context.campusColors.card, AppColors.dark.card);
        },
      );
    });

    testWidgets('spacing resolves window class from the width', (tester) async {
      await pumpProbe(
        tester,
        theme: AppTheme.light(),
        size: const Size(360, 800),
        probe: (BuildContext context) {
          expect(context.windowClass, AppWindowClass.compact);
          expect(context.spacing.isCompact, isTrue);
          expect(context.spacing.columns, 4);
          expect(context.spacing.gutter, 16);
          expect(context.spacing.screenPadding, 16);
          expect(context.spacing.cardGap, 12);
        },
      );
      await pumpProbe(
        tester,
        theme: AppTheme.light(),
        size: const Size(1280, 800),
        probe: (BuildContext context) {
          expect(context.windowClass, AppWindowClass.expanded);
          expect(context.spacing.isExpanded, isTrue);
          expect(context.spacing.columns, 12);
          expect(context.spacing.gutter, 24);
          expect(context.spacing.screenPadding, 24);
        },
      );
    });

    testWidgets('reduced motion zeroes durations except opacity fades', (
      tester,
    ) async {
      await pumpProbe(
        tester,
        theme: AppTheme.light(),
        disableAnimations: true,
        probe: (BuildContext context) {
          expect(AppMotion.isReduced(context), isTrue);
          expect(AppMotion.resolve(context, AppMotion.moderate), Duration.zero);
          expect(
            AppMotion.resolve(context, AppMotion.base, opacityFade: true),
            AppMotion.fast,
          );
        },
      );
      await pumpProbe(
        tester,
        theme: AppTheme.light(),
        probe: (BuildContext context) {
          expect(AppMotion.isReduced(context), isFalse);
          expect(
            AppMotion.resolve(context, AppMotion.moderate),
            AppMotion.moderate,
          );
        },
      );
    });

    testWidgets('missing extension gives a clear error', (tester) async {
      await pumpProbe(
        tester,
        theme: ThemeData(),
        probe: (BuildContext context) {
          expect(() => context.campusColors, throwsA(isA<StateError>()));
        },
      );
    });
  });

  group('smoke: themed components build and lay out', () {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      testWidgets('${theme.brightness.name} theme renders core widgets', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Report a problem')),
              body: ListView(
                children: <Widget>[
                  FilledButton(onPressed: () {}, child: const Text('Submit')),
                  FilledButton(onPressed: null, child: const Text('Disabled')),
                  OutlinedButton(onPressed: () {}, child: const Text('Back')),
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'Describe the problem',
                      helperText: 'Visible to people involved',
                    ),
                  ),
                  const Card(child: Text('Card')),
                  const FilterChip(
                    label: Text('Include closed'),
                    selected: true,
                    onSelected: null,
                  ),
                  Switch(value: true, onChanged: (_) {}),
                  Switch(value: false, onChanged: (_) {}),
                  const Divider(),
                  const LinearProgressIndicator(value: .5),
                  SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(value: 0, label: Text('All')),
                      ButtonSegment<int>(value: 1, label: Text('Active')),
                    ],
                    selected: const <int>{0},
                  ),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.view_kanban_outlined),
                    label: 'Board',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Submit'), findsOneWidget);
      });
    }
  });
}
