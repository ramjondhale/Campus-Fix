import 'package:flutter/material.dart';

/// Short accessors for the Material theme parts the widgets read.
///
/// Internal helper (not exported from the barrel): every widget resolves its
/// text styles and colours from the current theme, never from literals.
extension WidgetThemeContext on BuildContext {
  /// The current [TextTheme] (contract 3.2 slots).
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The current [ColorScheme] (contract 2.2, 2.3 roles).
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
