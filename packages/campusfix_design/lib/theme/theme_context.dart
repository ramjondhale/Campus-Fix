import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import 'extensions/campus_colors.dart';
import 'extensions/category_palette.dart';
import 'extensions/priority_palette.dart';
import 'extensions/status_palette.dart';
import 'tokens/semantic_tokens.dart';
import 'tokens/spacing_tokens.dart';

/// Window-size dependent spacing (contract 4.2), read with `context.spacing`.
///
/// The raw 4 px scale is `AppSpace`; this class resolves the values that
/// change with the window class: gutter, grid columns and screen padding.
@immutable
final class ResponsiveSpacing {
  /// Creates the spacing for a window of [width] logical pixels.
  ResponsiveSpacing(this.width) : windowClass = AppWindowClass.fromWidth(width);

  /// Window width the values were resolved for.
  final double width;

  /// Window class for [width].
  final AppWindowClass windowClass;

  /// True in the mobile (compact) window class.
  bool get isCompact => windowClass == AppWindowClass.compact;

  /// True in the medium window class.
  bool get isMedium => windowClass == AppWindowClass.medium;

  /// True in the expanded (admin console) window class.
  bool get isExpanded => windowClass == AppWindowClass.expanded;

  /// Layout grid columns for the window class (4, 8 or 12).
  int get columns => windowClass.columns;

  /// Grid gutter: 16 compact, 24 medium and expanded.
  double get gutter => windowClass.gutter;

  /// Screen padding: 16 on mobile, 24 for admin content.
  double get screenPadding =>
      isCompact ? AppLayout.screenPaddingMobile : AppLayout.screenPaddingAdmin;

  /// Gap between cards in a list (12).
  double get cardGap => AppLayout.cardGap;

  /// Horizontal screen padding as an [EdgeInsets].
  EdgeInsets get screenInsets =>
      EdgeInsets.symmetric(horizontal: screenPadding);
}

/// Convenient access to the CampusFix theme extensions from a [BuildContext].
extension AppThemeContext on BuildContext {
  /// The [CampusColors] extension of the current theme.
  ///
  /// Throws a [StateError] when the theme was not built by `AppTheme`.
  CampusColors get campusColors =>
      Theme.of(this).extension<CampusColors>() ?? _missing('CampusColors');

  /// The [CategoryPalette] extension of the current theme.
  CategoryPalette get categoryPalette =>
      Theme.of(this).extension<CategoryPalette>() ??
      _missing('CategoryPalette');

  /// The [PriorityPalette] extension of the current theme.
  PriorityPalette get priorityPalette =>
      Theme.of(this).extension<PriorityPalette>() ??
      _missing('PriorityPalette');

  /// The [StatusPalette] extension of the current theme.
  StatusPalette get statusPalette =>
      Theme.of(this).extension<StatusPalette>() ?? _missing('StatusPalette');

  /// `{fg, bg, accent}` for a [ProblemCategory] in the current theme.
  CategoryStyle categoryStyle(ProblemCategory category) =>
      categoryPalette.styleFor(category);

  /// `{fg, bg, accent}` for a [Priority] in the current theme.
  PriorityStyle priorityStyle(Priority priority) =>
      priorityPalette.styleFor(priority);

  /// `{fg, bg, accent}` for a [ComplaintStatus] in the current theme.
  StatusStyle statusStyle(ComplaintStatus status) =>
      statusPalette.styleFor(status);

  /// `{fg, bg, accent}` for a [FeedbackKind] in the current theme.
  FeedbackStyle feedbackStyle(FeedbackKind kind) =>
      campusColors.feedbackStyle(kind);

  /// Window-size dependent spacing for the current [MediaQuery] width.
  ResponsiveSpacing get spacing =>
      ResponsiveSpacing(MediaQuery.sizeOf(this).width);

  /// Window class (compact, medium, expanded) for the current width.
  AppWindowClass get windowClass =>
      AppWindowClass.fromWidth(MediaQuery.sizeOf(this).width);
}

Never _missing(String name) => throw StateError(
  '$name is not installed on the current Theme. Build the theme with '
  'AppTheme.light() or AppTheme.dark().',
);
