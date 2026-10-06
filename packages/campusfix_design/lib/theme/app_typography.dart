import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens/type_tokens.dart';

/// Typography (contract 3): Archivo for headings, titles and labels, Public
/// Sans for body text and JetBrains Mono for IDs and data, built with
/// `google_fonts`.
///
/// [textTheme] assigns the 15 Material slots; `overline` and the three mono
/// styles are extra static styles (contract 10.2). Tables, counters and
/// timestamps should apply [tabular] to their style.
abstract final class AppTypography {
  /// Builds the [TextStyle] for a [TypeSpec] row, optionally with [color].
  static TextStyle styleFor(TypeSpec spec, {Color? color}) {
    final double height = spec.heightRatio;
    final FontWeight weight = _weight(spec.weight);
    switch (spec.family) {
      case AppFontFamily.archivo:
        return GoogleFonts.archivo(
          fontSize: spec.size,
          height: height,
          fontWeight: weight,
          letterSpacing: spec.letterSpacing,
          color: color,
        );
      case AppFontFamily.publicSans:
        return GoogleFonts.publicSans(
          fontSize: spec.size,
          height: height,
          fontWeight: weight,
          letterSpacing: spec.letterSpacing,
          color: color,
        );
      case AppFontFamily.jetBrainsMono:
        return GoogleFonts.jetBrainsMono(
          fontSize: spec.size,
          height: height,
          fontWeight: weight,
          letterSpacing: spec.letterSpacing,
          color: color,
        );
    }
  }

  static FontWeight _weight(int weight) => switch (weight) {
    400 => FontWeight.w400,
    500 => FontWeight.w500,
    600 => FontWeight.w600,
    700 => FontWeight.w700,
    _ => throw ArgumentError.value(weight, 'weight', 'unsupported weight'),
  };

  /// The Material [TextTheme] (contract 3.2, "Flutter slot" column).
  ///
  /// When [color] is given (the theme's `onSurface`), every slot carries it so
  /// text reads correctly in light and dark themes.
  static TextTheme textTheme({Color? color}) => TextTheme(
    displayLarge: styleFor(AppTypeScale.displayLg, color: color),
    displayMedium: styleFor(AppTypeScale.displayMd, color: color),
    displaySmall: styleFor(AppTypeScale.displaySm, color: color),
    headlineLarge: styleFor(AppTypeScale.headlineLg, color: color),
    headlineMedium: styleFor(AppTypeScale.headlineMd, color: color),
    headlineSmall: styleFor(AppTypeScale.headlineSm, color: color),
    titleLarge: styleFor(AppTypeScale.titleLg, color: color),
    titleMedium: styleFor(AppTypeScale.titleMd, color: color),
    titleSmall: styleFor(AppTypeScale.titleSm, color: color),
    bodyLarge: styleFor(AppTypeScale.bodyLg, color: color),
    bodyMedium: styleFor(AppTypeScale.bodyMd, color: color),
    bodySmall: styleFor(AppTypeScale.bodySm, color: color),
    labelLarge: styleFor(AppTypeScale.labelLg, color: color),
    labelMedium: styleFor(AppTypeScale.labelMd, color: color),
    labelSmall: styleFor(AppTypeScale.labelSm, color: color),
  );

  /// `caption`: alias of `body-sm` (timestamps, counters).
  static TextStyle get caption => styleFor(AppTypeScale.caption);

  /// `overline`: table headers and group eyebrows. The contract marks these
  /// uppercase; a `TextStyle` cannot transform text, so callers apply
  /// `toUpperCase()` to the string.
  static TextStyle get overline => styleFor(AppTypeScale.overline);

  /// `mono-lg`: M-08 confirmation Complaint ID.
  static TextStyle get monoLarge => styleFor(AppTypeScale.monoLg);

  /// `mono-md`: ID in detail headers, table cells.
  static TextStyle get monoMedium => styleFor(AppTypeScale.monoMd);

  /// `mono-sm`: ID on cards and dense rows.
  static TextStyle get monoSmall => styleFor(AppTypeScale.monoSm);

  /// [style] with tabular figures, for tables, counters and timestamps.
  static TextStyle tabular(TextStyle style) => style.copyWith(
    fontFeatures: <FontFeature>[
      ...?style.fontFeatures,
      const FontFeature.tabularFigures(),
    ],
  );

  /// Starts loading every style the design system uses so the first frame
  /// does not flash a fallback (contract 3.1). Await it at app start, after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> preload() {
    for (final TypeSpec spec in AppTypeScale.byToken.values) {
      styleFor(spec);
    }
    // 3.1 also lists Archivo 500, Public Sans 500/600 and JetBrains Mono 400
    // as weights to load, for components that tune a weight locally.
    GoogleFonts.archivo(fontWeight: FontWeight.w500);
    GoogleFonts.publicSans(fontWeight: FontWeight.w500);
    GoogleFonts.publicSans(fontWeight: FontWeight.w600);
    GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w400);
    return GoogleFonts.pendingFonts();
  }
}
