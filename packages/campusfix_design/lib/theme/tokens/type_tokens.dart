import 'package:flutter/foundation.dart' show immutable;

/// Font families used by the design system (contract 3.1).
enum AppFontFamily {
  /// Headings, titles, labels, buttons, metrics. Weights 500, 600, 700.
  archivo('Archivo'),

  /// Body, helper text, captions, tables. Weights 400, 500, 600.
  publicSans('Public Sans'),

  /// Complaint IDs, code, mono data. Weights 400, 500, 600.
  jetBrainsMono('JetBrains Mono');

  const AppFontFamily(this.googleName);

  /// Family name on Google Fonts.
  final String googleName;
}

/// One row of the type scale (contract 3.2): size, line height, weight and
/// tracking in logical pixels.
@immutable
final class TypeSpec {
  /// Creates a type scale row.
  const TypeSpec({
    required this.family,
    required this.size,
    required this.lineHeight,
    required this.weight,
    required this.letterSpacing,
  });

  /// Font family.
  final AppFontFamily family;

  /// Font size.
  final double size;

  /// Line height in logical pixels.
  final double lineHeight;

  /// Numeric weight (400, 500, 600 or 700).
  final int weight;

  /// Tracking in logical pixels.
  final double letterSpacing;

  /// Line height as a multiple of [size], for `TextStyle.height`.
  double get heightRatio => lineHeight / size;
}

/// The type scale as data (contract 3.2, Appendix A `typography`). Keys of
/// [byToken] are the contract names (`display-lg`, `mono-sm`, ...).
abstract final class AppTypeScale {
  /// `display-lg`: Archivo 44/52, weight 700, tracking -0.5.
  static const TypeSpec displayLg = TypeSpec(
    family: AppFontFamily.archivo,
    size: 44.0,
    lineHeight: 52.0,
    weight: 700,
    letterSpacing: -0.5,
  );

  /// `display-md`: Archivo 36/44, weight 700, tracking -0.25.
  static const TypeSpec displayMd = TypeSpec(
    family: AppFontFamily.archivo,
    size: 36.0,
    lineHeight: 44.0,
    weight: 700,
    letterSpacing: -0.25,
  );

  /// `display-sm`: Archivo 30/38, weight 700, tracking 0.
  static const TypeSpec displaySm = TypeSpec(
    family: AppFontFamily.archivo,
    size: 30.0,
    lineHeight: 38.0,
    weight: 700,
    letterSpacing: 0.0,
  );

  /// `headline-lg`: Archivo 26/34, weight 700, tracking 0.
  static const TypeSpec headlineLg = TypeSpec(
    family: AppFontFamily.archivo,
    size: 26.0,
    lineHeight: 34.0,
    weight: 700,
    letterSpacing: 0.0,
  );

  /// `headline-md`: Archivo 22/30, weight 600, tracking 0.
  static const TypeSpec headlineMd = TypeSpec(
    family: AppFontFamily.archivo,
    size: 22.0,
    lineHeight: 30.0,
    weight: 600,
    letterSpacing: 0.0,
  );

  /// `headline-sm`: Archivo 20/28, weight 600, tracking 0.
  static const TypeSpec headlineSm = TypeSpec(
    family: AppFontFamily.archivo,
    size: 20.0,
    lineHeight: 28.0,
    weight: 600,
    letterSpacing: 0.0,
  );

  /// `title-lg`: Archivo 18/26, weight 600, tracking 0.
  static const TypeSpec titleLg = TypeSpec(
    family: AppFontFamily.archivo,
    size: 18.0,
    lineHeight: 26.0,
    weight: 600,
    letterSpacing: 0.0,
  );

  /// `title-md`: Archivo 16/24, weight 600, tracking 0.1.
  static const TypeSpec titleMd = TypeSpec(
    family: AppFontFamily.archivo,
    size: 16.0,
    lineHeight: 24.0,
    weight: 600,
    letterSpacing: 0.1,
  );

  /// `title-sm`: Archivo 14/20, weight 600, tracking 0.1.
  static const TypeSpec titleSm = TypeSpec(
    family: AppFontFamily.archivo,
    size: 14.0,
    lineHeight: 20.0,
    weight: 600,
    letterSpacing: 0.1,
  );

  /// `body-lg`: Public Sans 16/24, weight 400, tracking 0.1.
  static const TypeSpec bodyLg = TypeSpec(
    family: AppFontFamily.publicSans,
    size: 16.0,
    lineHeight: 24.0,
    weight: 400,
    letterSpacing: 0.1,
  );

  /// `body-md`: Public Sans 14/20, weight 400, tracking 0.1.
  static const TypeSpec bodyMd = TypeSpec(
    family: AppFontFamily.publicSans,
    size: 14.0,
    lineHeight: 20.0,
    weight: 400,
    letterSpacing: 0.1,
  );

  /// `body-sm`: Public Sans 12/16, weight 400, tracking 0.2.
  static const TypeSpec bodySm = TypeSpec(
    family: AppFontFamily.publicSans,
    size: 12.0,
    lineHeight: 16.0,
    weight: 400,
    letterSpacing: 0.2,
  );

  /// `label-lg`: Archivo 14/20, weight 600, tracking 0.1.
  static const TypeSpec labelLg = TypeSpec(
    family: AppFontFamily.archivo,
    size: 14.0,
    lineHeight: 20.0,
    weight: 600,
    letterSpacing: 0.1,
  );

  /// `label-md`: Archivo 12/16, weight 600, tracking 0.3.
  static const TypeSpec labelMd = TypeSpec(
    family: AppFontFamily.archivo,
    size: 12.0,
    lineHeight: 16.0,
    weight: 600,
    letterSpacing: 0.3,
  );

  /// `label-sm`: Archivo 11/16, weight 600, tracking 0.5.
  static const TypeSpec labelSm = TypeSpec(
    family: AppFontFamily.archivo,
    size: 11.0,
    lineHeight: 16.0,
    weight: 600,
    letterSpacing: 0.5,
  );

  /// `overline`: Archivo 11/16, weight 700, tracking 1.0.
  static const TypeSpec overline = TypeSpec(
    family: AppFontFamily.archivo,
    size: 11.0,
    lineHeight: 16.0,
    weight: 700,
    letterSpacing: 1.0,
  );

  /// `mono-lg`: JetBrains Mono 24/32, weight 600, tracking -0.2.
  static const TypeSpec monoLg = TypeSpec(
    family: AppFontFamily.jetBrainsMono,
    size: 24.0,
    lineHeight: 32.0,
    weight: 600,
    letterSpacing: -0.2,
  );

  /// `mono-md`: JetBrains Mono 14/20, weight 500, tracking 0.
  static const TypeSpec monoMd = TypeSpec(
    family: AppFontFamily.jetBrainsMono,
    size: 14.0,
    lineHeight: 20.0,
    weight: 500,
    letterSpacing: 0.0,
  );

  /// `mono-sm`: JetBrains Mono 12/16, weight 500, tracking 0.
  static const TypeSpec monoSm = TypeSpec(
    family: AppFontFamily.jetBrainsMono,
    size: 12.0,
    lineHeight: 16.0,
    weight: 500,
    letterSpacing: 0.0,
  );

  /// `caption`: alias of [bodySm] for timestamps and counters.
  static const TypeSpec caption = bodySm;

  /// Every row keyed by contract name.
  static const Map<String, TypeSpec> byToken = <String, TypeSpec>{
    'display-lg': displayLg,
    'display-md': displayMd,
    'display-sm': displaySm,
    'headline-lg': headlineLg,
    'headline-md': headlineMd,
    'headline-sm': headlineSm,
    'title-lg': titleLg,
    'title-md': titleMd,
    'title-sm': titleSm,
    'body-lg': bodyLg,
    'body-md': bodyMd,
    'body-sm': bodySm,
    'caption': caption,
    'label-lg': labelLg,
    'label-md': labelMd,
    'label-sm': labelSm,
    'overline': overline,
    'mono-lg': monoLg,
    'mono-md': monoMd,
    'mono-sm': monoSm,
  };
}
