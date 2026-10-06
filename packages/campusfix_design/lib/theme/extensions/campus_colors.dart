import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show ThemeExtension;

import '../tokens/color_tokens.dart';
import '../tokens/semantic_tokens.dart';
import 'semantic_lookup.dart';

/// Colour tokens that `ColorScheme` has no role for (contract 10.2): the
/// named surfaces (`card`, `cardSubtle`, `raised`, `pressedFill`), the custom
/// brand states (`primaryHover`, `primaryPressed`, `inverseError`,
/// `focusRing`), the scrim, the photo overlay and the four feedback sets
/// (contract 2.4).
///
/// `card`, `cardSubtle`, `raised` and `pressedFill` are also available as
/// `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh` and
/// `surfaceContainerHighest` on the `ColorScheme`; they are repeated here
/// under their contract names so widgets read what the design system calls
/// them.
@immutable
final class CampusColors extends ThemeExtension<CampusColors> {
  /// Creates the extension from explicit values.
  CampusColors({
    required this.card,
    required this.cardSubtle,
    required this.raised,
    required this.pressedFill,
    required this.primaryHover,
    required this.primaryPressed,
    required this.inverseError,
    required this.focusRing,
    required this.scrim,
    required this.photoOverlayBackground,
    required this.photoOverlayForeground,
    required Map<FeedbackKind, SemanticStyle> feedback,
  }) : assert(
         coversAll(feedback, FeedbackKind.values),
         'CampusColors must define a style for every FeedbackKind',
       ),
       _feedback = Map<FeedbackKind, SemanticStyle>.unmodifiable(feedback);

  /// Builds the extension from the colour [tokens] of one theme.
  factory CampusColors.fromTokens(AppColorTokens tokens) => CampusColors(
    card: tokens.card,
    cardSubtle: tokens.cardSubtle,
    raised: tokens.raised,
    pressedFill: tokens.pressedFill,
    primaryHover: tokens.primaryHover,
    primaryPressed: tokens.primaryPressed,
    inverseError: tokens.inverseError,
    focusRing: tokens.focusRing,
    scrim: AppColors.scrim(tokens.brightness),
    photoOverlayBackground: AppColors.photoOverlayBackground,
    photoOverlayForeground: AppColors.photoOverlayForeground,
    feedback: stylesFromTokens<FeedbackKind>(
      group: 'feedback',
      values: FeedbackKind.values,
      tokens: SemanticTokens.feedback(tokens.brightness),
    ),
  );

  /// Light theme instance.
  static final CampusColors light = CampusColors.fromTokens(AppColors.light);

  /// Dark theme instance.
  static final CampusColors dark = CampusColors.fromTokens(AppColors.dark);

  /// Instance for [brightness].
  static CampusColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Cards, list rows, panels, table body and nav bars.
  final Color card;

  /// Table header, skeleton base, search fill, note blocks, disabled fill.
  final Color cardSubtle;

  /// Floating surfaces: menus, dialogs, bottom sheets.
  final Color raised;

  /// Pressed rows and the selected table row.
  final Color pressedFill;

  /// Filled primary button hover background.
  final Color primaryHover;

  /// Filled primary button pressed background.
  final Color primaryPressed;

  /// Error icon on a toast.
  final Color inverseError;

  /// Focus ring colour (2 px ring, 2 px offset); equals primary.
  final Color focusRing;

  /// Scrim behind dialogs and sheets: black at 40% (light) or 60% (dark).
  final Color scrim;

  /// Background of photo overlays (kind labels, remove buttons). Theme
  /// independent.
  final Color photoOverlayBackground;

  /// Foreground of photo overlays. Theme independent.
  final Color photoOverlayForeground;

  final Map<FeedbackKind, SemanticStyle> _feedback;

  /// The four feedback sets keyed by [FeedbackKind] (unmodifiable).
  Map<FeedbackKind, SemanticStyle> get feedback => _feedback;

  /// {fg, bg, accent} for a feedback [kind] (banners, toasts, validation).
  FeedbackStyle feedbackStyle(FeedbackKind kind) => _feedback[kind]!;

  @override
  CampusColors copyWith({
    Color? card,
    Color? cardSubtle,
    Color? raised,
    Color? pressedFill,
    Color? primaryHover,
    Color? primaryPressed,
    Color? inverseError,
    Color? focusRing,
    Color? scrim,
    Color? photoOverlayBackground,
    Color? photoOverlayForeground,
    Map<FeedbackKind, SemanticStyle>? feedback,
  }) => CampusColors(
    card: card ?? this.card,
    cardSubtle: cardSubtle ?? this.cardSubtle,
    raised: raised ?? this.raised,
    pressedFill: pressedFill ?? this.pressedFill,
    primaryHover: primaryHover ?? this.primaryHover,
    primaryPressed: primaryPressed ?? this.primaryPressed,
    inverseError: inverseError ?? this.inverseError,
    focusRing: focusRing ?? this.focusRing,
    scrim: scrim ?? this.scrim,
    photoOverlayBackground:
        photoOverlayBackground ?? this.photoOverlayBackground,
    photoOverlayForeground:
        photoOverlayForeground ?? this.photoOverlayForeground,
    feedback: mergeStyles(_feedback, feedback),
  );

  @override
  CampusColors lerp(ThemeExtension<CampusColors>? other, double t) {
    if (other is! CampusColors) return this;
    return CampusColors(
      card: Color.lerp(card, other.card, t)!,
      cardSubtle: Color.lerp(cardSubtle, other.cardSubtle, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      pressedFill: Color.lerp(pressedFill, other.pressedFill, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      inverseError: Color.lerp(inverseError, other.inverseError, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      photoOverlayBackground: Color.lerp(
        photoOverlayBackground,
        other.photoOverlayBackground,
        t,
      )!,
      photoOverlayForeground: Color.lerp(
        photoOverlayForeground,
        other.photoOverlayForeground,
        t,
      )!,
      feedback: lerpStyles(_feedback, other._feedback, t),
    );
  }
}
