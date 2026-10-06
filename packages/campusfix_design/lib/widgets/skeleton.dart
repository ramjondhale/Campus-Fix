import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';

/// Hosts the skeleton shimmer (contract 8.24): every [SkeletonBlock] below it
/// shares one highlight of `card` at 70% sweeping left to right every 1400 ms
/// (linear). With reduced motion (`MediaQuery.disableAnimations`) the
/// skeleton is static.
///
/// Skeletons mirror the final layout; never show a blank screen while
/// loading (G-3). The whole skeleton is announced once as "Loading".
class Skeleton extends StatefulWidget {
  /// Creates a skeleton host around [child].
  const Skeleton({super.key, required this.child});

  /// The skeleton layout, built from [SkeletonBlock]s.
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = AppMotion.isReduced(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color highlight = context.campusColors.card.withValues(alpha: 0.7);
    final Widget child = ExcludeSemantics(child: widget.child);
    final Widget shimmer = (_reduced ?? false)
        ? child
        : AnimatedBuilder(
            animation: _controller,
            child: child,
            builder: (BuildContext context, Widget? child) {
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (Rect bounds) => LinearGradient(
                  colors: <Color>[
                    highlight.withValues(alpha: 0),
                    highlight,
                    highlight.withValues(alpha: 0),
                  ],
                  stops: const <double>[0.35, 0.5, 0.65],
                  transform: _SlideGradient(_controller.value),
                ).createShader(bounds),
                child: child,
              );
            },
          );
    return Semantics(
      label: 'Loading',
      container: true,
      liveRegion: true,
      child: shimmer,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Sweep from fully left of the box to fully right of it.
    return Matrix4.translationValues(
      bounds.width * (progress * 2 - 1) * 1.4,
      0,
      0,
    );
  }
}

/// One skeleton block: `cardSubtle`, radius `r2` (`r4` for thumbnails).
/// Place inside a [Skeleton].
class SkeletonBlock extends StatelessWidget {
  /// Creates a block. A null [width] fills the available width.
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.br2,
  }) : widthFactor = null;

  /// A block of [widthFactor] of the available width.
  const SkeletonBlock.fraction({
    super.key,
    required double this.widthFactor,
    required this.height,
    this.radius = AppRadius.br2,
  }) : width = null;

  /// Fixed width, or null to fill (or follow [widthFactor]).
  final double? width;

  /// Fraction of the available width, when constructed with `.fraction`.
  final double? widthFactor;

  /// Height.
  final double height;

  /// Corner radius.
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    final Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.cardSubtle, borderRadius: radius),
    );
    if (widthFactor == null) return box;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}
