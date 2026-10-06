// Token drift test (contract 10.4): every constant in the package equals
// Appendix A of docs/design/design-system.md, copied to
// test/fixtures/tokens.json.
import 'dart:convert';
import 'dart:io';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

void main() {
  final Map<String, dynamic> tokens =
      jsonDecode(File('test/fixtures/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, dynamic> section(String key) =>
      tokens[key] as Map<String, dynamic>;

  group('colors', () {
    for (final Brightness b in Brightness.values) {
      test('${b.name} role and surface tokens match the contract', () {
        final Map<String, dynamic> expected =
            (section('colors'))[b.name] as Map<String, dynamic>;
        final Map<String, Color> actual = AppColors.of(b).toMap();
        expect(actual.keys.toSet(), expected.keys.toSet());
        for (final MapEntry<String, dynamic> e in expected.entries) {
          expect(actual[e.key], hex(e.value as String), reason: e.key);
        }
      });
    }

    test('key hex values spot check (primary, canvas, error)', () {
      expect(AppColors.light.primary, const Color(0xFF0F5A6A));
      expect(AppColors.dark.primary, const Color(0xFF7FCBDC));
      expect(AppColors.light.canvas, const Color(0xFFF2F5F7));
      expect(AppColors.dark.canvas, const Color(0xFF0D1418));
      expect(AppColors.light.error, const Color(0xFFB3261E));
      expect(AppColors.dark.error, const Color(0xFFFFB4AB));
    });

    test('scrim is black at 40% (light) and 60% (dark)', () {
      expect(tokens['scrim'], <String, dynamic>{
        'light': '#000000 @ 40%',
        'dark': '#000000 @ 60%',
      });
      expect(AppColors.scrimLight.a, closeTo(0.40, 1 / 255));
      expect(AppColors.scrimDark.a, closeTo(0.60, 1 / 255));
      expect(AppColors.scrimLight.toARGB32() & 0xFFFFFF, 0);
    });

    test('ColorScheme maps surface roles per contract 10.2', () {
      for (final AppColorTokens t in <AppColorTokens>[
        AppColors.light,
        AppColors.dark,
      ]) {
        final ColorScheme s = t.colorScheme;
        expect(s.brightness, t.brightness);
        expect(s.surface, t.canvas);
        expect(s.surfaceContainerLow, t.card);
        expect(s.surfaceContainer, t.cardSubtle);
        expect(s.surfaceContainerHigh, t.raised);
        expect(s.surfaceContainerHighest, t.pressedFill);
        expect(s.primary, t.primary);
        expect(s.onPrimary, t.onPrimary);
        expect(s.secondaryContainer, t.secondaryContainer);
        expect(s.error, t.error);
        expect(s.outline, t.outline);
        expect(s.outlineVariant, t.outlineVariant);
        expect(s.inverseSurface, t.inverseSurface);
        expect(s.inversePrimary, t.inversePrimary);
      }
    });
  });

  group('semantic sets', () {
    final Map<String, dynamic> semantic = section('semantic');

    void check(
      String group,
      Iterable<Enum> values,
      Map<String, String> labels,
      SemanticStyle Function(Brightness, Enum) resolve,
    ) {
      test('$group keys equal the Dart enum names and match the contract', () {
        final Map<String, dynamic> expected =
            semantic[group] as Map<String, dynamic>;
        expect(
          expected.keys.toSet(),
          values.map((Enum e) => e.name).toSet(),
          reason: 'contract keys must equal enum .name values',
        );
        for (final Enum value in values) {
          final Map<String, dynamic> entry =
              expected[value.name] as Map<String, dynamic>;
          expect(labels[value.name], entry['label'], reason: value.name);
          for (final Brightness b in Brightness.values) {
            final Map<String, dynamic> set =
                entry[b.name] as Map<String, dynamic>;
            final SemanticStyle style = resolve(b, value);
            expect(style.fg, hex(set['fg'] as String), reason: '$value fg');
            expect(style.bg, hex(set['bg'] as String), reason: '$value bg');
            expect(
              style.accent,
              hex(set['accent'] as String),
              reason: '$value accent',
            );
          }
        }
      });
    }

    check(
      'category',
      ProblemCategory.values,
      <String, String>{for (final c in ProblemCategory.values) c.name: c.label},
      (Brightness b, Enum e) => AppTheme.of(
        b,
      ).extension<CategoryPalette>()!.styleFor(e as ProblemCategory),
    );
    check(
      'priority',
      Priority.values,
      <String, String>{for (final p in Priority.values) p.name: p.label},
      (Brightness b, Enum e) =>
          AppTheme.of(b).extension<PriorityPalette>()!.styleFor(e as Priority),
    );
    check(
      'status',
      ComplaintStatus.values,
      <String, String>{for (final s in ComplaintStatus.values) s.name: s.label},
      (Brightness b, Enum e) => AppTheme.of(
        b,
      ).extension<StatusPalette>()!.styleFor(e as ComplaintStatus),
    );
    check(
      'feedback',
      FeedbackKind.values,
      <String, String>{for (final k in FeedbackKind.values) k.name: k.label},
      (Brightness b, Enum e) => AppTheme.of(
        b,
      ).extension<CampusColors>()!.feedbackStyle(e as FeedbackKind),
    );

    test('critical priority and closed status are the solid sets', () {
      for (final Brightness b in Brightness.values) {
        final PriorityPalette p = b == Brightness.dark
            ? PriorityPalette.dark
            : PriorityPalette.light;
        final StatusPalette s = b == Brightness.dark
            ? StatusPalette.dark
            : StatusPalette.light;
        expect(p.styleFor(Priority.critical).isSolid, isTrue);
        expect(s.styleFor(ComplaintStatus.closed).isSolid, isTrue);
        for (final Priority v in Priority.values.where(
          (Priority v) => v != Priority.critical,
        )) {
          expect(p.styleFor(v).isSolid, isFalse, reason: v.name);
        }
        for (final ComplaintStatus v in ComplaintStatus.values.where(
          (ComplaintStatus v) => v != ComplaintStatus.closed,
        )) {
          expect(s.styleFor(v).isSolid, isFalse, reason: v.name);
        }
      }
    });
  });

  group('typography', () {
    final Map<String, dynamic> type = section('typography');

    test('type scale constants match the contract', () {
      expect(AppTypeScale.byToken.keys.toSet(), type.keys.toSet());
      for (final MapEntry<String, dynamic> e in type.entries) {
        final Map<String, dynamic> row = e.value as Map<String, dynamic>;
        final TypeSpec spec = AppTypeScale.byToken[e.key]!;
        expect(spec.family.googleName, row['family'], reason: e.key);
        expect(spec.size, (row['size'] as num).toDouble(), reason: e.key);
        expect(
          spec.lineHeight,
          (row['lineHeight'] as num).toDouble(),
          reason: e.key,
        );
        expect(spec.weight, row['weight'], reason: e.key);
        expect(
          spec.letterSpacing,
          (row['letterSpacing'] as num).toDouble(),
          reason: e.key,
        );
      }
    });

    test('TextTheme slots carry size, height, weight and tracking', () {
      final TextTheme theme = AppTypography.textTheme();
      final Map<String, TextStyle?> slots = <String, TextStyle?>{
        'displayLarge': theme.displayLarge,
        'displayMedium': theme.displayMedium,
        'displaySmall': theme.displaySmall,
        'headlineLarge': theme.headlineLarge,
        'headlineMedium': theme.headlineMedium,
        'headlineSmall': theme.headlineSmall,
        'titleLarge': theme.titleLarge,
        'titleMedium': theme.titleMedium,
        'titleSmall': theme.titleSmall,
        'bodyLarge': theme.bodyLarge,
        'bodyMedium': theme.bodyMedium,
        'bodySmall': theme.bodySmall,
        'labelLarge': theme.labelLarge,
        'labelMedium': theme.labelMedium,
        'labelSmall': theme.labelSmall,
      };
      int checked = 0;
      for (final MapEntry<String, dynamic> e in type.entries) {
        final Map<String, dynamic> row = e.value as Map<String, dynamic>;
        final String slot = row['flutterSlot'] as String;
        final TextStyle? style = slots[slot];
        if (style == null) continue; // custom or alias rows
        checked++;
        expect(style.fontSize, (row['size'] as num).toDouble(), reason: slot);
        expect(
          style.height! * style.fontSize!,
          closeTo((row['lineHeight'] as num).toDouble(), 1e-9),
          reason: slot,
        );
        expect(
          style.fontWeight,
          FontWeight.values[((row['weight'] as int) ~/ 100) - 1],
          reason: slot,
        );
        expect(
          style.letterSpacing,
          (row['letterSpacing'] as num).toDouble(),
          reason: slot,
        );
        expect(
          style.fontFamily!.startsWith(
            (row['family'] as String).replaceAll(' ', ''),
          ),
          isTrue,
          reason: '$slot uses ${style.fontFamily}',
        );
      }
      expect(checked, 15);
    });

    test('custom styles: overline, mono and caption', () {
      expect(AppTypography.overline.fontSize, 11);
      expect(AppTypography.overline.fontWeight, FontWeight.w700);
      expect(AppTypography.overline.letterSpacing, 1.0);
      expect(AppTypography.monoLarge.fontSize, 24);
      expect(AppTypography.monoMedium.fontSize, 14);
      expect(AppTypography.monoSmall.fontSize, 12);
      expect(AppTypography.monoLarge.fontFamily, startsWith('JetBrainsMono'));
      expect(
        AppTypography.caption.fontSize,
        AppTypography.textTheme().bodySmall!.fontSize,
      );
    });

    test('tabular() adds tabular figures without dropping features', () {
      final TextStyle s = AppTypography.tabular(AppTypography.monoSmall);
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('spacing, radii, layout, icons', () {
    test('spacing scale', () {
      final Map<String, dynamic> expected = section('spacing');
      expect(AppSpace.byToken.keys.toSet(), expected.keys.toSet());
      for (final MapEntry<String, dynamic> e in expected.entries) {
        expect(AppSpace.byToken[e.key], (e.value as num).toDouble());
      }
    });

    test('radii', () {
      final Map<String, dynamic> expected = section('radii');
      expect(AppRadius.byToken.keys.toSet(), expected.keys.toSet());
      for (final MapEntry<String, dynamic> e in expected.entries) {
        expect(AppRadius.byToken[e.key], (e.value as num).toDouble());
      }
      expect(AppRadius.br4, const BorderRadius.all(Radius.circular(8)));
      expect(AppRadius.sheetTop.topLeft, const Radius.circular(16));
      expect(AppRadius.sheetTop.bottomLeft, Radius.zero);
    });

    test('icon sizes', () {
      expect(
        AppIconSize.all,
        (tokens['iconSizes'] as List<dynamic>)
            .map((dynamic v) => (v as num).toDouble())
            .toList(),
      );
    });

    test('layout constants', () {
      final Map<String, dynamic> l = section('layout');
      expect(AppLayout.minTouchTarget, l['minTouchTarget']);
      expect(AppLayout.minPointerTarget, l['minPointerTarget']);
      final Map<String, dynamic> ch =
          l['controlHeight'] as Map<String, dynamic>;
      expect(AppLayout.controlHeightMobile, ch['mobile']);
      expect(AppLayout.controlHeightAdmin, ch['admin']);
      expect(AppLayout.controlHeightDense, ch['dense']);
      final Map<String, dynamic> ab = l['appBarHeight'] as Map<String, dynamic>;
      expect(AppLayout.appBarHeightMobile, ab['mobile']);
      expect(AppLayout.appBarHeightAdmin, ab['admin']);
      expect(AppLayout.bottomNavHeight, l['bottomNavHeight']);
      final Map<String, dynamic> sn = l['sideNavWidth'] as Map<String, dynamic>;
      expect(AppLayout.sideNavWidthExpanded, sn['expanded']);
      expect(AppLayout.sideNavWidthRail, sn['rail']);
      final Map<String, dynamic> g = l['gutter'] as Map<String, dynamic>;
      expect(AppWindowClass.compact.gutter, g['compact']);
      expect(AppWindowClass.medium.gutter, g['medium']);
      expect(AppWindowClass.expanded.gutter, g['expanded']);
      expect(AppLayout.contentMaxWidth, l['contentMaxWidth']);
      final Map<String, dynamic> d =
          l['dialogMaxWidth'] as Map<String, dynamic>;
      expect(AppLayout.dialogMaxWidthMobile, d['mobile']);
      expect(AppLayout.dialogMaxWidthAdmin, d['admin']);
      expect(AppLayout.photoTile, l['photoTile']);
      expect(AppLayout.maxPhotos, l['maxPhotos']);
      final Map<String, dynamic> bp = l['breakpoints'] as Map<String, dynamic>;
      expect(AppLayout.mediumBreakpoint, bp['medium']);
      expect(AppLayout.expandedBreakpoint, bp['expanded']);
    });

    test('window class boundaries', () {
      expect(AppWindowClass.fromWidth(0), AppWindowClass.compact);
      expect(AppWindowClass.fromWidth(599.9), AppWindowClass.compact);
      expect(AppWindowClass.fromWidth(600), AppWindowClass.medium);
      expect(AppWindowClass.fromWidth(1023), AppWindowClass.medium);
      expect(AppWindowClass.fromWidth(1024), AppWindowClass.expanded);
      expect(AppLayout.mobileDialogWidth(360), 328);
      expect(AppLayout.mobileDialogWidth(800), 420);
    });
  });

  group('elevation', () {
    final RegExp color = RegExp(r'rgb\((\d+) (\d+) (\d+) / (\.?\d*\.?\d+)\)');

    for (final Brightness b in Brightness.values) {
      test('${b.name} shadows match the contract', () {
        final Map<String, dynamic> expected =
            section('elevation')[b.name] as Map<String, dynamic>;
        final Map<String, List<BoxShadow>> actual = <String, List<BoxShadow>>{
          'e1': AppElevation.e1(b),
          'e2': AppElevation.e2(b),
          'e3': AppElevation.e3(b),
          'e4': AppElevation.e4(b),
        };
        expect(AppElevation.e0(b), isEmpty);
        expect(actual.keys.toSet(), expected.keys.toSet());
        for (final MapEntry<String, dynamic> e in expected.entries) {
          final List<dynamic> layers = e.value as List<dynamic>;
          final List<BoxShadow> shadows = actual[e.key]!;
          expect(shadows.length, layers.length, reason: e.key);
          for (int i = 0; i < layers.length; i++) {
            final Map<String, dynamic> layer =
                layers[i] as Map<String, dynamic>;
            final RegExpMatch m = color.firstMatch(layer['color'] as String)!;
            final BoxShadow s = shadows[i];
            expect(s.offset, Offset(0, (layer['dy'] as num).toDouble()));
            expect(s.blurRadius, (layer['blur'] as num).toDouble());
            expect(s.spreadRadius, (layer['spread'] as num).toDouble());
            expect(s.color.r * 255, closeTo(double.parse(m[1]!), 0.5));
            expect(s.color.g * 255, closeTo(double.parse(m[2]!), 0.5));
            expect(s.color.b * 255, closeTo(double.parse(m[3]!), 0.5));
            expect(s.color.a, closeTo(double.parse(m[4]!), 1 / 255));
          }
        }
      });
    }
  });

  group('motion and state layers', () {
    test('durations', () {
      final Map<String, dynamic> d =
          section('motion')['durationsMs'] as Map<String, dynamic>;
      final Map<String, Duration> actual = <String, Duration>{
        'instant': AppMotion.instant,
        'fast': AppMotion.fast,
        'base': AppMotion.base,
        'moderate': AppMotion.moderate,
        'slow': AppMotion.slow,
        'deliberate': AppMotion.deliberate,
        'shimmer': AppMotion.shimmer,
      };
      expect(actual.keys.toSet(), d.keys.toSet());
      for (final MapEntry<String, dynamic> e in d.entries) {
        expect(actual[e.key]!.inMilliseconds, e.value, reason: e.key);
      }
    });

    test('easings are the contract cubic beziers', () {
      final Map<String, dynamic> d =
          section('motion')['easings'] as Map<String, dynamic>;
      final Map<String, Curve> actual = <String, Curve>{
        'standard': AppMotion.standard,
        'enter': AppMotion.enter,
        'exit': AppMotion.exit,
        'linear': AppMotion.linear,
      };
      expect(actual.keys.toSet(), d.keys.toSet());
      for (final MapEntry<String, dynamic> e in d.entries) {
        final List<double> v = (e.value as List<dynamic>)
            .map((dynamic n) => (n as num).toDouble())
            .toList();
        final Cubic c = actual[e.key]! as Cubic;
        expect(<double>[c.a, c.b, c.c, c.d], v, reason: e.key);
      }
    });

    test('state layers and focus ring', () {
      final Map<String, dynamic> s = section('stateLayers');
      expect(AppStateLayer.hover, s['hover']);
      expect(AppStateLayer.focus, s['focus']);
      expect(AppStateLayer.pressed, s['pressed']);
      expect(AppStateLayer.dragged, s['dragged']);
      expect(AppStateLayer.disabledContent, s['disabledContent']);
      expect(AppStateLayer.disabledContainer, s['disabledContainer']);
      final Map<String, dynamic> f = section('focusRing');
      expect(AppStateLayer.focusRingWidth, f['width']);
      expect(AppStateLayer.focusRingOffset, f['offset']);
    });
  });
}
