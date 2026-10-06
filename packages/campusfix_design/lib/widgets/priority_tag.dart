import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import 'app_tag_size.dart';
import 'support/context_ext.dart';

/// The four-bar signal glyph of a priority (contract 8.8): the first
/// `Priority.weight` bars are full colour, the rest 28% opacity.
class PrioritySignalBars extends StatelessWidget {
  /// Creates the glyph for [priority], drawn in [color].
  const PrioritySignalBars({
    super.key,
    required this.priority,
    required this.color,
  });

  /// Priority whose weight sets the number of full bars.
  final Priority priority;

  /// Colour of the bars (the set accent, or `fg` for solid sets).
  final Color color;

  static const double _barWidth = 2.5;
  static const double _gap = 1.5;
  static const List<double> _heights = <double>[4, 6, 8, 10];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(
          _heights.length * _barWidth + (_heights.length - 1) * _gap,
          _heights.last,
        ),
        painter: _BarsPainter(filled: priority.weight, color: color),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.filled, required this.color});

  final int filled;
  final Color color;

  static const double _dimmed = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < PrioritySignalBars._heights.length; i++) {
      final double h = PrioritySignalBars._heights[i];
      final double x =
          i * (PrioritySignalBars._barWidth + PrioritySignalBars._gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, PrioritySignalBars._barWidth, h),
          const Radius.circular(0.5),
        ),
        Paint()..color = i < filled ? color : color.withValues(alpha: _dimmed),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.filled != filled || old.color != color;
}

/// A priority as a rectangle with signal bars (contract 8.8).
///
/// Always pass `PublicComplaintView.effectivePriority`. `critical` is a solid
/// block. With [overridden] the "Overridden" marker chip follows the tag
/// (admin complaint detail only; screens-spec A-03 never shows it).
/// Semantics: "Priority: Critical".
class PriorityTag extends StatelessWidget {
  /// Creates a tag for [priority].
  const PriorityTag({
    super.key,
    required this.priority,
    this.size = AppTagSize.md,
    this.overridden = false,
  });

  /// The effective priority.
  final Priority priority;

  /// [AppTagSize.md] (22 high) or [AppTagSize.sm] (18 high).
  final AppTagSize size;

  /// Adds the "Overridden" marker chip next to the tag (A-04 only).
  final bool overridden;

  @override
  Widget build(BuildContext context) {
    final PriorityStyle style = context.priorityStyle(priority);
    final bool sm = size == AppTagSize.sm;
    final TextStyle base = (sm
        ? context.textTheme.labelSmall
        : context.textTheme.labelMedium)!;
    final Widget tag = Semantics(
      label: 'Priority: ${priority.label}',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: sm ? 18 : 22),
        padding: EdgeInsets.only(left: sm ? 5 : 6, right: sm ? 6 : 8),
        decoration: BoxDecoration(color: style.bg, borderRadius: AppRadius.br2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrioritySignalBars(priority: priority, color: style.markColor),
            SizedBox(width: sm ? 4 : 6),
            Text(
              priority.label,
              style: base.copyWith(
                color: style.fg,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
    if (!overridden) return tag;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        tag,
        const SizedBox(width: 6),
        const OverriddenMarker(),
      ],
    );
  }
}

/// The "Overridden" chip shown next to a [PriorityTag] on the admin complaint
/// detail (contract 8.8): 22 high, 1 px outline, `undo` glyph 12.
class OverriddenMarker extends StatelessWidget {
  /// Creates the marker.
  const OverriddenMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fg = context.colorScheme.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: AppRadius.br2,
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.undo, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            'Overridden',
            style: context.textTheme.labelSmall!.copyWith(color: fg),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
