import 'dart:math' as math;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import 'app_tag_size.dart';
import 'support/context_ext.dart';

/// The status ring (contract 8.7): a track at 28% of the status accent and a
/// progress arc from 12 o'clock clockwise by `ComplaintStatus.order / 6`.
/// `reported` shows the empty track only; `closed` is a filled disc with a
/// check.
class StatusRing extends StatelessWidget {
  /// Creates a ring for [status]; [size] is 14 (badge) or 12 (small badge).
  const StatusRing({super.key, required this.status, this.size = 14});

  /// The status to draw.
  final ComplaintStatus status;

  /// Outer size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final StatusStyle style = context.statusStyle(status);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StatusRingPainter(
            fraction: status.order / ComplaintStatus.closed.order,
            closed: status == ComplaintStatus.closed,
            mark: style.markColor,
            checkColor: style.bg,
          ),
        ),
      ),
    );
  }
}

class _StatusRingPainter extends CustomPainter {
  const _StatusRingPainter({
    required this.fraction,
    required this.closed,
    required this.mark,
    required this.checkColor,
  });

  final double fraction;
  final bool closed;
  final Color mark;
  final Color checkColor;

  // The geometry is specified on a 14 px badge ring (contract 8.7) and scaled.
  static const double _design = 14;
  static const double _trackRadius = 5;
  static const double _stroke = 2;
  static const double _discRadius = 6.5;
  static const double _trackAlpha = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / _design;
    final Offset center = Offset(size.width / 2, size.height / 2);
    if (closed) {
      canvas.drawCircle(center, _discRadius * s, Paint()..color = mark);
      final Path check = Path()
        ..moveTo(4.3 * s, 7.3 * s)
        ..lineTo(6.2 * s, 9.1 * s)
        ..lineTo(9.8 * s, 5.2 * s);
      canvas.drawPath(
        check,
        Paint()
          ..color = checkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }
    canvas.drawCircle(
      center,
      _trackRadius * s,
      Paint()
        ..color = mark.withValues(alpha: _trackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke * s,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _trackRadius * s),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = mark
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke * s
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(_StatusRingPainter old) =>
      old.fraction != fraction ||
      old.closed != closed ||
      old.mark != mark ||
      old.checkColor != checkColor;
}

/// A status as a pill with a progress ring (contract 8.7).
///
/// Takes only the [ComplaintStatus]; the label, colours and ring are built
/// here so screens never pass colours or label strings. The label is never
/// abbreviated. Semantics: "Status: In Progress".
class StatusBadge extends StatelessWidget {
  /// Creates a badge for [status].
  const StatusBadge({
    super.key,
    required this.status,
    this.size = AppTagSize.md,
  });

  /// The status to show.
  final ComplaintStatus status;

  /// [AppTagSize.md] (24 high) or [AppTagSize.sm] (20 high).
  final AppTagSize size;

  @override
  Widget build(BuildContext context) {
    final StatusStyle style = context.statusStyle(status);
    final bool sm = size == AppTagSize.sm;
    final TextStyle label = (sm
        ? context.textTheme.labelSmall
        : context.textTheme.labelMedium)!;
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: sm ? 20 : 24),
        padding: EdgeInsets.only(left: sm ? 6 : 7, right: sm ? 8 : 10),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: AppRadius.brFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusRing(status: status, size: sm ? 12 : 14),
            SizedBox(width: sm ? 5 : 6),
            Text(
              status.label,
              style: label.copyWith(color: style.fg),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
