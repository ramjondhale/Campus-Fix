import 'package:flutter/widgets.dart';

/// Durations and easing curves (contract 7.1).
abstract final class AppMotion {
  /// 0 ms: reduced motion.
  static const Duration instant = Duration.zero;

  /// 100 ms: state layers (hover, press), opacity fades.
  static const Duration fast = Duration(milliseconds: 100);

  /// 150 ms: chip select, toggle, tile select, dialog exit.
  static const Duration base = Duration(milliseconds: 150);

  /// 250 ms: dialog, sheet and toast enter, expand.
  static const Duration moderate = Duration(milliseconds: 250);

  /// 350 ms: page transitions, large element moves.
  static const Duration slow = Duration(milliseconds: 350);

  /// 500 ms: progress ring fill, onboarding only.
  static const Duration deliberate = Duration(milliseconds: 500);

  /// 1400 ms: skeleton shimmer loop (use with [linear]).
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// Most transitions.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Elements entering the screen.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Elements leaving the screen.
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Shimmer, spinners.
  static const Curve linear = Cubic(0.0, 0.0, 1.0, 1.0);

  /// Whether the OS or app asks for reduced motion
  /// (`MediaQuery.disableAnimations`).
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration] adjusted for reduced motion (contract 7.1): every duration
  /// becomes [instant], except opacity fades ([opacityFade] true), which stay
  /// at [fast].
  static Duration resolve(
    BuildContext context,
    Duration duration, {
    bool opacityFade = false,
  }) {
    if (!isReduced(context)) return duration;
    return opacityFade ? fast : instant;
  }
}

/// State layer opacities (contract 7.2, Appendix A `stateLayers`) and the
/// focus ring geometry.
abstract final class AppStateLayer {
  /// Hover overlay of the content colour.
  static const double hover = 0.08;

  /// Keyboard focus overlay.
  static const double focus = 0.10;

  /// Pressed overlay.
  static const double pressed = 0.12;

  /// Dragged overlay (with elevation `e4`).
  static const double dragged = 0.16;

  /// Disabled content: `onSurface` at 38%.
  static const double disabledContent = 0.38;

  /// Disabled container: `onSurface` at 12%.
  static const double disabledContainer = 0.12;

  /// Focus ring width in logical pixels.
  static const double focusRingWidth = 2;

  /// Focus ring offset in logical pixels.
  static const double focusRingOffset = 2;
}
