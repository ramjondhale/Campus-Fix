import 'dart:ui' show Brightness, Color, Offset;

import 'package:flutter/painting.dart' show BoxShadow;

/// Elevation levels (contract 5.2).
///
/// `e0` is the default for cards, rows, panels and app bars: a 1 px
/// `outlineVariant` border and no shadow. Shadows exist only for things that
/// float. Shadow offset is `(0, dy)` with spread 0. In dark theme shadows are
/// black at higher opacity (floating surfaces are also lighter: `raised`).
abstract final class AppElevation {
  static const Color _lightInk = Color(0xFF0F1E28); // rgb(15 30 40)
  static const Color _black = Color(0xFF000000);

  static BoxShadow _s(Color base, double alpha, double dy, double blur) =>
      BoxShadow(
        color: base.withValues(alpha: alpha),
        offset: Offset(0, dy),
        blurRadius: blur,
      );

  /// Cards, list rows, panels, app bars: no shadow.
  static List<BoxShadow> e0(Brightness brightness) => const <BoxShadow>[];

  /// Hovered card, sticky header, scrolled app bar.
  static List<BoxShadow> e1(Brightness brightness) =>
      brightness == Brightness.dark
      ? <BoxShadow>[_s(_black, .40, 1, 2)]
      : <BoxShadow>[_s(_lightInk, .08, 1, 2)];

  /// Menu, dropdown, FAB.
  static List<BoxShadow> e2(Brightness brightness) =>
      brightness == Brightness.dark
      ? <BoxShadow>[_s(_black, .45, 2, 6), _s(_black, .30, 1, 2)]
      : <BoxShadow>[_s(_lightInk, .12, 2, 6), _s(_lightInk, .08, 1, 2)];

  /// Dialog, bottom sheet, toast.
  static List<BoxShadow> e3(Brightness brightness) =>
      brightness == Brightness.dark
      ? <BoxShadow>[_s(_black, .55, 8, 24), _s(_black, .35, 2, 6)]
      : <BoxShadow>[_s(_lightInk, .16, 8, 24), _s(_lightInk, .10, 2, 6)];

  /// Dragged item, popover.
  static List<BoxShadow> e4(Brightness brightness) =>
      brightness == Brightness.dark
      ? <BoxShadow>[_s(_black, .65, 12, 32), _s(_black, .40, 4, 10)]
      : <BoxShadow>[_s(_lightInk, .22, 12, 32), _s(_lightInk, .12, 4, 10)];

  /// Shadow colour for Material widgets that take a single `shadowColor`
  /// plus a numeric `elevation` (menus, dialogs, snack bars).
  static Color materialShadowColor(Brightness brightness) =>
      brightness == Brightness.dark ? _black : _lightInk;
}
