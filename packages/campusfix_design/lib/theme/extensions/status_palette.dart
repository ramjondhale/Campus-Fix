import 'dart:ui' show Brightness;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show ThemeExtension;

import '../tokens/semantic_tokens.dart';
import 'semantic_lookup.dart';

/// Status colour sets (contract 2.7): `{fg, bg, accent}` per `ComplaintStatus`. `closed` is a solid stamp (`bg` equals `accent`; ring and check use `fg`).
///
/// Registered on `ThemeData.extensions` by `AppTheme`. Read it with
/// `context.statusStyle(value)` or `Theme.of(context).extension<StatusPalette>()`.
@immutable
final class StatusPalette extends ThemeExtension<StatusPalette> {
  /// Creates a palette from an enum-keyed [styles] map covering every
  /// `ComplaintStatus` value.
  StatusPalette({required Map<ComplaintStatus, SemanticStyle> styles})
    : assert(
        coversAll(styles, ComplaintStatus.values),
        'StatusPalette must define a style for every ComplaintStatus',
      ),
      _styles = Map<ComplaintStatus, SemanticStyle>.unmodifiable(styles);

  /// Builds the palette for [brightness] from the contract tokens (Appendix A
  /// `semantic.status`), keyed by `ComplaintStatus.name`. Throws if a key is missing.
  factory StatusPalette.fromTokens(Brightness brightness) => StatusPalette(
    styles: stylesFromTokens<ComplaintStatus>(
      group: 'status',
      values: ComplaintStatus.values,
      tokens: SemanticTokens.status(brightness),
    ),
  );

  /// Light theme palette.
  static final StatusPalette light = StatusPalette.fromTokens(Brightness.light);

  /// Dark theme palette.
  static final StatusPalette dark = StatusPalette.fromTokens(Brightness.dark);

  final Map<ComplaintStatus, SemanticStyle> _styles;

  /// Every style, keyed by enum value (unmodifiable).
  Map<ComplaintStatus, SemanticStyle> get styles => _styles;

  /// {fg, bg, accent} for [value].
  StatusStyle styleFor(ComplaintStatus value) => _styles[value]!;

  /// Same as [styleFor].
  StatusStyle operator [](ComplaintStatus value) => styleFor(value);

  /// Copy where each entry of [styles] overrides the matching style.
  @override
  StatusPalette copyWith({Map<ComplaintStatus, SemanticStyle>? styles}) =>
      StatusPalette(styles: mergeStyles(_styles, styles));

  @override
  StatusPalette lerp(ThemeExtension<StatusPalette>? other, double t) {
    if (other is! StatusPalette) return this;
    return StatusPalette(styles: lerpStyles(_styles, other._styles, t));
  }
}
