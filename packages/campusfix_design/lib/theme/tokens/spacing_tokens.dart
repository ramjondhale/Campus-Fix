import 'dart:math' as math;

/// Spacing scale (contract 4.1), 4 px base. `space-N` is `sN`.
abstract final class AppSpace {
  /// `space-0`: reset.
  static const double s0 = 0;

  /// `space-1`: icon-to-text in badges, tight stacks.
  static const double s1 = 4;

  /// `space-2`: gap inside controls, chip gap.
  static const double s2 = 8;

  /// `space-3`: dense card padding, gap between cards.
  static const double s3 = 12;

  /// `space-4`: mobile screen gutter, card padding, field gap.
  static const double s4 = 16;

  /// `space-5`: dialog inner gap.
  static const double s5 = 20;

  /// `space-6`: section gap, dialog padding, admin gutter.
  static const double s6 = 24;

  /// `space-8`: admin page gutter, large section gap.
  static const double s8 = 32;

  /// `space-10`: page section break.
  static const double s10 = 40;

  /// `space-12`: hero spacing, touch target.
  static const double s12 = 48;

  /// `space-16`: empty-state vertical spacing.
  static const double s16 = 64;

  /// Every step keyed by its contract name (Appendix A `spacing`).
  static const Map<String, double> byToken = <String, double>{
    'space-0': s0,
    'space-1': s1,
    'space-2': s2,
    'space-3': s3,
    'space-4': s4,
    'space-5': s5,
    'space-6': s6,
    'space-8': s8,
    'space-10': s10,
    'space-12': s12,
    'space-16': s16,
  };
}

/// Window size classes (contract 4.2).
enum AppWindowClass {
  /// 0 to 599: mobile apps. 4 columns, gutter 16, bottom nav.
  compact(columns: 4, gutter: 16),

  /// 600 to 1023: tablet, narrow admin. 8 columns, gutter 24, nav rail 72.
  medium(columns: 8, gutter: 24),

  /// 1024 and up: admin console. 12 columns, gutter 24, side nav 240.
  expanded(columns: 12, gutter: 24);

  const AppWindowClass({required this.columns, required this.gutter});

  /// Layout grid columns.
  final int columns;

  /// Gutter and screen padding in logical pixels.
  final double gutter;

  /// Window class for a [width] in logical pixels.
  static AppWindowClass fromWidth(double width) {
    if (width >= AppLayout.expandedBreakpoint) return expanded;
    if (width >= AppLayout.mediumBreakpoint) return medium;
    return compact;
  }
}

/// Layout constants (contract 4.2, Appendix A `layout`).
abstract final class AppLayout {
  /// Lower bound of the medium window class.
  static const double mediumBreakpoint = 600;

  /// Lower bound of the expanded window class.
  static const double expandedBreakpoint = 1024;

  /// Minimum touch target on mobile (visible control may be smaller).
  static const double minTouchTarget = 48;

  /// Minimum pointer target in the admin console.
  static const double minPointerTarget = 32;

  /// Control height: mobile.
  static const double controlHeightMobile = 48;

  /// Control height: admin.
  static const double controlHeightAdmin = 40;

  /// Control height: dense admin.
  static const double controlHeightDense = 32;

  /// Mobile app bar height.
  static const double appBarHeightMobile = 56;

  /// Admin top bar height.
  static const double appBarHeightAdmin = 64;

  /// Bottom nav height, plus the bottom safe area.
  static const double bottomNavHeight = 64;

  /// Admin side nav width when expanded.
  static const double sideNavWidthExpanded = 240;

  /// Admin nav rail width (medium windows).
  static const double sideNavWidthRail = 72;

  /// Maximum content width in the admin console.
  static const double contentMaxWidth = 1280;

  /// Dialog maximum width, admin.
  static const double dialogMaxWidthAdmin = 560;

  /// Dialog maximum width, mobile, before the `width - 32` cap.
  static const double dialogMaxWidthMobile = 420;

  /// Photo tile minimum edge.
  static const double photoTile = 100;

  /// Maximum photos per upload (before and after).
  static const int maxPhotos = 5;

  /// Gap between cards in a list.
  static const double cardGap = 12;

  /// Screen padding: mobile.
  static const double screenPaddingMobile = 16;

  /// Screen padding: admin content.
  static const double screenPaddingAdmin = 24;

  /// Mobile dialog width for a screen [width]: `min(420, width - 32)`.
  static double mobileDialogWidth(double width) =>
      math.min(dialogMaxWidthMobile, width - 32);
}
