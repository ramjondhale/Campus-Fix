import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

/// Icon sizes (contract 6.1). Icons inherit the text colour of their context.
abstract final class AppIconSize {
  /// Inline with text and inside badges.
  static const double s16 = 16;

  /// Buttons, fields, dense admin rows.
  static const double s20 = 20;

  /// Default.
  static const double s24 = 24;

  /// Empty-state glyph.
  static const double s32 = 32;

  /// Reserved for large empty states.
  static const double s40 = 40;

  /// Reserved for large empty states.
  static const double s48 = 48;

  /// Every size (Appendix A `iconSizes`).
  static const List<double> all = <double>[s16, s20, s24, s32, s40, s48];
}

/// Category glyphs (contract 6.2): one outlined Material icon per
/// `ProblemCategory`.
abstract final class AppCategoryIcons {
  static const Map<ProblemCategory, IconData> _icons =
      <ProblemCategory, IconData>{
        ProblemCategory.electrical: Icons.bolt_outlined,
        ProblemCategory.plumbing: Icons.water_drop_outlined,
        ProblemCategory.civil: Icons.apartment_outlined,
        ProblemCategory.furniture: Icons.chair_alt_outlined,
        ProblemCategory.cleanliness: Icons.cleaning_services_outlined,
        ProblemCategory.it: Icons.computer_outlined,
        ProblemCategory.safety: Icons.health_and_safety_outlined,
        ProblemCategory.other: Icons.more_horiz,
      };

  /// Glyph for [category].
  static IconData of(ProblemCategory category) => _icons[category]!;
}
