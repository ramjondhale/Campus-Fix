import 'dart:ui' show Brightness;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show ThemeExtension;

import '../tokens/semantic_tokens.dart';
import 'semantic_lookup.dart';

/// Priority colour sets (contract 2.6): `{fg, bg, accent}` per `Priority`. `critical` is a solid block (`bg` equals `accent`, bars use `fg`).
///
/// Registered on `ThemeData.extensions` by `AppTheme`. Read it with
/// `context.priorityStyle(value)` or `Theme.of(context).extension<PriorityPalette>()`.
@immutable
final class PriorityPalette extends ThemeExtension<PriorityPalette> {
  /// Creates a palette from an enum-keyed [styles] map covering every
  /// `Priority` value.
  PriorityPalette({required Map<Priority, SemanticStyle> styles})
    : assert(
        coversAll(styles, Priority.values),
        'PriorityPalette must define a style for every Priority',
      ),
      _styles = Map<Priority, SemanticStyle>.unmodifiable(styles);

  /// Builds the palette for [brightness] from the contract tokens (Appendix A
  /// `semantic.priority`), keyed by `Priority.name`. Throws if a key is missing.
  factory PriorityPalette.fromTokens(Brightness brightness) => PriorityPalette(
    styles: stylesFromTokens<Priority>(
      group: 'priority',
      values: Priority.values,
      tokens: SemanticTokens.priority(brightness),
    ),
  );

  /// Light theme palette.
  static final PriorityPalette light = PriorityPalette.fromTokens(
    Brightness.light,
  );

  /// Dark theme palette.
  static final PriorityPalette dark = PriorityPalette.fromTokens(
    Brightness.dark,
  );

  final Map<Priority, SemanticStyle> _styles;

  /// Every style, keyed by enum value (unmodifiable).
  Map<Priority, SemanticStyle> get styles => _styles;

  /// {fg, bg, accent} for [value].
  PriorityStyle styleFor(Priority value) => _styles[value]!;

  /// Same as [styleFor].
  PriorityStyle operator [](Priority value) => styleFor(value);

  /// Copy where each entry of [styles] overrides the matching style.
  @override
  PriorityPalette copyWith({Map<Priority, SemanticStyle>? styles}) =>
      PriorityPalette(styles: mergeStyles(_styles, styles));

  @override
  PriorityPalette lerp(ThemeExtension<PriorityPalette>? other, double t) {
    if (other is! PriorityPalette) return this;
    return PriorityPalette(styles: lerpStyles(_styles, other._styles, t));
  }
}
