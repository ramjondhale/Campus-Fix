import 'dart:ui' show Brightness;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show ThemeExtension;

import '../tokens/semantic_tokens.dart';
import 'semantic_lookup.dart';

/// Category colour sets (contract 2.5): `{fg, bg, accent}` per `ProblemCategory`. Category colour appears only as an icon chip or a chart fill, never as a coloured text badge.
///
/// Registered on `ThemeData.extensions` by `AppTheme`. Read it with
/// `context.categoryStyle(value)` or `Theme.of(context).extension<CategoryPalette>()`.
@immutable
final class CategoryPalette extends ThemeExtension<CategoryPalette> {
  /// Creates a palette from an enum-keyed [styles] map covering every
  /// `ProblemCategory` value.
  CategoryPalette({required Map<ProblemCategory, SemanticStyle> styles})
    : assert(
        coversAll(styles, ProblemCategory.values),
        'CategoryPalette must define a style for every ProblemCategory',
      ),
      _styles = Map<ProblemCategory, SemanticStyle>.unmodifiable(styles);

  /// Builds the palette for [brightness] from the contract tokens (Appendix A
  /// `semantic.category`), keyed by `ProblemCategory.name`. Throws if a key is missing.
  factory CategoryPalette.fromTokens(Brightness brightness) => CategoryPalette(
    styles: stylesFromTokens<ProblemCategory>(
      group: 'category',
      values: ProblemCategory.values,
      tokens: SemanticTokens.category(brightness),
    ),
  );

  /// Light theme palette.
  static final CategoryPalette light = CategoryPalette.fromTokens(
    Brightness.light,
  );

  /// Dark theme palette.
  static final CategoryPalette dark = CategoryPalette.fromTokens(
    Brightness.dark,
  );

  final Map<ProblemCategory, SemanticStyle> _styles;

  /// Every style, keyed by enum value (unmodifiable).
  Map<ProblemCategory, SemanticStyle> get styles => _styles;

  /// {fg, bg, accent} for [value].
  CategoryStyle styleFor(ProblemCategory value) => _styles[value]!;

  /// Same as [styleFor].
  CategoryStyle operator [](ProblemCategory value) => styleFor(value);

  /// Copy where each entry of [styles] overrides the matching style.
  @override
  CategoryPalette copyWith({Map<ProblemCategory, SemanticStyle>? styles}) =>
      CategoryPalette(styles: mergeStyles(_styles, styles));

  @override
  CategoryPalette lerp(ThemeExtension<CategoryPalette>? other, double t) {
    if (other is! CategoryPalette) return this;
    return CategoryPalette(styles: lerpStyles(_styles, other._styles, t));
  }
}
