// Contrast test (contract 10.4): for each semantic set and theme, `fg` on
// `bg` is at least 4.5:1 and `accent` is at least 3:1 against both `card` and
// its own `bg`, using the WCAG relative luminance formula from section 2.9.
import 'dart:ui' show Brightness, Color;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final Brightness b in Brightness.values) {
    final AppColorTokens colors = AppColors.of(b);
    final bool dark = b == Brightness.dark;
    final Map<String, SemanticStyle> sets = <String, SemanticStyle>{
      for (final ProblemCategory c in ProblemCategory.values)
        'category.${c.name}':
            (dark ? CategoryPalette.dark : CategoryPalette.light).styleFor(c),
      for (final Priority p in Priority.values)
        'priority.${p.name}':
            (dark ? PriorityPalette.dark : PriorityPalette.light).styleFor(p),
      for (final ComplaintStatus s in ComplaintStatus.values)
        'status.${s.name}': (dark ? StatusPalette.dark : StatusPalette.light)
            .styleFor(s),
      for (final FeedbackKind k in FeedbackKind.values)
        'feedback.${k.name}': CampusColors.of(b).feedbackStyle(k),
    };

    test('${b.name}: all 19 semantic sets plus 4 feedback sets present', () {
      expect(sets.length, 8 + 4 + 7 + 4);
    });

    test('${b.name}: fg on bg is at least 4.5:1 for every set', () {
      for (final MapEntry<String, SemanticStyle> e in sets.entries) {
        expect(
          contrast(e.value.fg, e.value.bg),
          greaterThanOrEqualTo(4.5),
          reason: e.key,
        );
      }
    });

    test('${b.name}: accent is at least 3:1 on card and on its own bg', () {
      for (final MapEntry<String, SemanticStyle> e in sets.entries) {
        expect(
          contrast(e.value.accent, colors.card),
          greaterThanOrEqualTo(3.0),
          reason: '${e.key} accent vs card',
        );
        // Solid sets use their accent as the container itself.
        if (!e.value.isSolid) {
          expect(
            contrast(e.value.accent, e.value.bg),
            greaterThanOrEqualTo(3.0),
            reason: '${e.key} accent vs bg',
          );
        }
      }
    });

    test('${b.name}: text and brand pairs meet their requirement', () {
      // Primary body text 7:1; secondary text and on-colour pairs 4.5:1.
      for (final Color surface in <Color>[
        colors.canvas,
        colors.card,
        colors.cardSubtle,
        colors.raised,
      ]) {
        expect(contrast(colors.onSurface, surface), greaterThanOrEqualTo(7.0));
        expect(
          contrast(colors.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(colors.outline, surface), greaterThanOrEqualTo(3.0));
      }
      final List<(Color, Color)> pairs = <(Color, Color)>[
        (colors.onPrimary, colors.primary),
        (colors.onPrimary, colors.primaryHover),
        (colors.onPrimary, colors.primaryPressed),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onSecondary, colors.secondary),
        (colors.onSecondaryContainer, colors.secondaryContainer),
        (colors.onError, colors.error),
        (colors.onErrorContainer, colors.errorContainer),
        (colors.onInverseSurface, colors.inverseSurface),
      ];
      for (final (Color fg, Color bg) in pairs) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$fg on $bg',
        );
      }
    });
  }
}
