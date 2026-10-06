import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Brightness, Color, ColorScheme;

/// Raw colour tokens from design-system.md sections 2.2 and 2.3 for one theme.
///
/// Every value is an sRGB hex taken verbatim from the contract. This file and
/// `semantic_tokens.dart` are the only places a `Color(0x...)` literal may
/// appear (contract 10.4); widgets read colours from `Theme.of(context)` and
/// the theme extensions.
@immutable
final class AppColorTokens {
  /// Creates a complete token set for [brightness].
  const AppColorTokens({
    required this.brightness,
    required this.canvas,
    required this.card,
    required this.cardSubtle,
    required this.raised,
    required this.pressedFill,
    required this.surfaceContainerLowest,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryHover,
    required this.primaryPressed,
    required this.inversePrimary,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.inverseError,
    required this.focusRing,
  });

  /// Theme these tokens belong to.
  final Brightness brightness;

  /// Page background; Scaffold background colour (`ColorScheme.surface`).
  final Color canvas;

  /// Cards, list rows, panels, table body, nav bars (`ColorScheme.surfaceContainerLow`).
  final Color card;

  /// Table header, skeleton base, search fill, note blocks, disabled fill (`surfaceContainer`).
  final Color cardSubtle;

  /// Menus, dialogs, bottom sheets (`surfaceContainerHigh`).
  final Color raised;

  /// Pressed rows, selected table row (`surfaceContainerHighest`).
  final Color pressedFill;

  /// `surfaceContainerLowest` token.
  final Color surfaceContainerLowest;

  /// `surfaceDim` token.
  final Color surfaceDim;

  /// `surfaceBright` token.
  final Color surfaceBright;

  /// `onSurface` token.
  final Color onSurface;

  /// `onSurfaceVariant` token.
  final Color onSurfaceVariant;

  /// `outline` token.
  final Color outline;

  /// `outlineVariant` token.
  final Color outlineVariant;

  /// `inverseSurface` token.
  final Color inverseSurface;

  /// `onInverseSurface` token.
  final Color onInverseSurface;

  /// `primary` token.
  final Color primary;

  /// `onPrimary` token.
  final Color onPrimary;

  /// `primaryContainer` token.
  final Color primaryContainer;

  /// `onPrimaryContainer` token.
  final Color onPrimaryContainer;

  /// Filled primary button hover background (custom).
  final Color primaryHover;

  /// Filled primary button pressed background (custom).
  final Color primaryPressed;

  /// `inversePrimary` token.
  final Color inversePrimary;

  /// `secondary` token.
  final Color secondary;

  /// `onSecondary` token.
  final Color onSecondary;

  /// `secondaryContainer` token.
  final Color secondaryContainer;

  /// `onSecondaryContainer` token.
  final Color onSecondaryContainer;

  /// `tertiary` token.
  final Color tertiary;

  /// `onTertiary` token.
  final Color onTertiary;

  /// `tertiaryContainer` token.
  final Color tertiaryContainer;

  /// `onTertiaryContainer` token.
  final Color onTertiaryContainer;

  /// `error` token.
  final Color error;

  /// `onError` token.
  final Color onError;

  /// `errorContainer` token.
  final Color errorContainer;

  /// `onErrorContainer` token.
  final Color onErrorContainer;

  /// Error icon on toast (custom).
  final Color inverseError;

  /// Focus ring colour (custom); equal to primary.
  final Color focusRing;

  /// Material 3 [ColorScheme] built role by role from these tokens
  /// (never `fromSeed`; contract 10.2). Surface roles follow 10.2:
  /// `canvas` -> `surface`, `card` -> `surfaceContainerLow`,
  /// `cardSubtle` -> `surfaceContainer`, `raised` -> `surfaceContainerHigh`,
  /// `pressedFill` -> `surfaceContainerHighest`.
  ColorScheme get colorScheme => ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: canvas,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: card,
    surfaceContainer: cardSubtle,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: pressedFill,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    surfaceTint: const Color(0x00000000),
  );

  /// Every token keyed by its contract name (Appendix A `colors.<theme>`).
  /// Used by the token drift test and by [CampusColors] lookups.
  Map<String, Color> toMap() => <String, Color>{
    'canvas': canvas,
    'card': card,
    'cardSubtle': cardSubtle,
    'raised': raised,
    'pressedFill': pressedFill,
    'surfaceContainerLowest': surfaceContainerLowest,
    'surfaceDim': surfaceDim,
    'surfaceBright': surfaceBright,
    'onSurface': onSurface,
    'onSurfaceVariant': onSurfaceVariant,
    'outline': outline,
    'outlineVariant': outlineVariant,
    'inverseSurface': inverseSurface,
    'onInverseSurface': onInverseSurface,
    'primary': primary,
    'onPrimary': onPrimary,
    'primaryContainer': primaryContainer,
    'onPrimaryContainer': onPrimaryContainer,
    'primaryHover': primaryHover,
    'primaryPressed': primaryPressed,
    'inversePrimary': inversePrimary,
    'secondary': secondary,
    'onSecondary': onSecondary,
    'secondaryContainer': secondaryContainer,
    'onSecondaryContainer': onSecondaryContainer,
    'tertiary': tertiary,
    'onTertiary': onTertiary,
    'tertiaryContainer': tertiaryContainer,
    'onTertiaryContainer': onTertiaryContainer,
    'error': error,
    'onError': onError,
    'errorContainer': errorContainer,
    'onErrorContainer': onErrorContainer,
    'inverseError': inverseError,
    'focusRing': focusRing,
  };
}

/// Colour token sets and theme-independent colour constants.
abstract final class AppColors {
  /// Light theme tokens (contract 2.2, 2.3).
  static const AppColorTokens light = AppColorTokens(
    brightness: Brightness.light,
    canvas: Color(0xFFF2F5F7),
    card: Color(0xFFFFFFFF),
    cardSubtle: Color(0xFFEAEFF2),
    raised: Color(0xFFFFFFFF),
    pressedFill: Color(0xFFDDE4E9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFFD3DBE0),
    surfaceBright: Color(0xFFFFFFFF),
    onSurface: Color(0xFF121C23),
    onSurfaceVariant: Color(0xFF44525D),
    outline: Color(0xFF6A7984),
    outlineVariant: Color(0xFFC4CDD4),
    inverseSurface: Color(0xFF26323A),
    onInverseSurface: Color(0xFFEAF0F3),
    primary: Color(0xFF0F5A6A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCFEAF1),
    onPrimaryContainer: Color(0xFF00313B),
    primaryHover: Color(0xFF0B4957),
    primaryPressed: Color(0xFF083A46),
    inversePrimary: Color(0xFF7FCBDC),
    secondary: Color(0xFF475B67),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE6EC),
    onSecondaryContainer: Color(0xFF122630),
    tertiary: Color(0xFF54559A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE4E3FB),
    onTertiaryContainer: Color(0xFF1B1C5A),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE9E6),
    onErrorContainer: Color(0xFF810109),
    inverseError: Color(0xFFFFB4AB),
    focusRing: Color(0xFF0F5A6A),
  );

  /// Dark theme tokens (contract 2.2, 2.3).
  static const AppColorTokens dark = AppColorTokens(
    brightness: Brightness.dark,
    canvas: Color(0xFF0D1418),
    card: Color(0xFF131C21),
    cardSubtle: Color(0xFF1A252B),
    raised: Color(0xFF1F2B32),
    pressedFill: Color(0xFF2A3943),
    surfaceContainerLowest: Color(0xFF090F12),
    surfaceDim: Color(0xFF0D1418),
    surfaceBright: Color(0xFF2E3E47),
    onSurface: Color(0xFFE3EAEE),
    onSurfaceVariant: Color(0xFFAEBDC6),
    outline: Color(0xFF80929D),
    outlineVariant: Color(0xFF33444E),
    inverseSurface: Color(0xFFE3EAEE),
    onInverseSurface: Color(0xFF1A252B),
    primary: Color(0xFF7FCBDC),
    onPrimary: Color(0xFF00323C),
    primaryContainer: Color(0xFF0F4B59),
    onPrimaryContainer: Color(0xFFC9EBF3),
    primaryHover: Color(0xFF9AD8E6),
    primaryPressed: Color(0xFFB4E3EE),
    inversePrimary: Color(0xFF0F5A6A),
    secondary: Color(0xFFB2C6D1),
    onSecondary: Color(0xFF1B2F39),
    secondaryContainer: Color(0xFF2F4350),
    onSecondaryContainer: Color(0xFFD3E3EC),
    tertiary: Color(0xFFBFC0F5),
    onTertiary: Color(0xFF26276B),
    tertiaryContainer: Color(0xFF3C3D82),
    onTertiaryContainer: Color(0xFFE2E1FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF511815),
    onErrorContainer: Color(0xFFFEC9C1),
    inverseError: Color(0xFFB3261E),
    focusRing: Color(0xFF7FCBDC),
  );

  /// Tokens for [brightness].
  static AppColorTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Scrim behind dialogs and sheets: black at 40% in light theme (5.2).
  static const Color scrimLight = Color(0x66000000);

  /// Scrim behind dialogs and sheets: black at 60% in dark theme (5.2).
  static const Color scrimDark = Color(0x99000000);

  /// Scrim for [brightness].
  static Color scrim(Brightness brightness) =>
      brightness == Brightness.dark ? scrimDark : scrimLight;

  /// Photo overlay background (kind labels, remove buttons): `#0F1920` at 82%.
  /// Theme independent (2.9).
  static const Color photoOverlayBackground = Color(0xD10F1920);

  /// Photo overlay foreground: `#FFFFFF`. Theme independent (2.9).
  static const Color photoOverlayForeground = Color(0xFFFFFFFF);
}
