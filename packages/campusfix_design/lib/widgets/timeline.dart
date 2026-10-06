import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'support/context_ext.dart';
import 'support/time_format.dart';
import 'user_avatar.dart';

/// True when [events] contain a rework: a reject (T7) that sent the complaint
/// from `resolved` back to `inProgress`.
bool timelineHasRework(List<PublicStatusEvent> events) {
  for (int i = 1; i < events.length; i++) {
    if (_isRework(events, i)) return true;
  }
  return false;
}

bool _isRework(List<PublicStatusEvent> events, int index) =>
    index > 0 &&
    events[index].status == ComplaintStatus.inProgress &&
    events[index - 1].status == ComplaintStatus.resolved;

/// One entry of a complaint timeline (contract 8.14).
///
/// A 16 px node on a 2 px connector, then the status label (`title-sm`), the
/// actor's [RolePill] (**role label only, never a name or id**), the time
/// (`body-sm`, tabular) and an optional note in a `cardSubtle` block. Past
/// nodes are filled with the status `accent`; the current node is a `card`
/// dot in a 4 px `primary` ring; a rework (T7) node uses the `error` colour
/// and also prints "Rework", so it is never colour alone.
///
/// [adminActorLine] and the "Admin only" tag are the admin-only form (A-04);
/// the public form never passes it.
class TimelineItem extends StatelessWidget {
  /// Creates a timeline entry.
  const TimelineItem({
    super.key,
    required this.status,
    required this.actorRole,
    required this.at,
    this.note,
    this.isLast = false,
    this.isCurrent = false,
    this.isRework = false,
    this.adminActorLine,
    this.now,
  });

  /// The status entered by this event.
  final ComplaintStatus status;

  /// The acting role (label only).
  final UserRole actorRole;

  /// When the event happened.
  final DateTime at;

  /// Optional note.
  final String? note;

  /// True for the last entry (no connector below).
  final bool isLast;

  /// True for the latest entry.
  final bool isCurrent;

  /// True when this entry is a T7 rework.
  final bool isRework;

  /// Admin form only (A-04): the actor line in `mono-sm`, with the "Admin
  /// only" tag.
  final String? adminActorLine;

  /// Reference time for relative times.
  final DateTime? now;

  static const double _nodeBox = 22;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final StatusStyle style = context.statusStyle(status);
    final DateTime reference = now ?? DateTime.now();
    final Color nodeColor = isRework ? scheme.error : style.markColor;
    final String timeText = formatRelativeTime(at, now: reference);

    final Widget content = Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(status.label, style: context.textTheme.titleSmall),
                    RolePill(role: actorRole),
                    if (isRework)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.undo, size: 14, color: scheme.error),
                          const SizedBox(width: 2),
                          Text(
                            'Rework',
                            style: context.textTheme.labelSmall!.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                timeText,
                style: AppTypography.tabular(
                  context.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (adminActorLine != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: Wrap(
                spacing: AppSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    adminActorLine!,
                    style: AppTypography.monoSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const AdminOnlyTag(),
                ],
              ),
            ),
          if (note != null && note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                decoration: BoxDecoration(
                  color: colors.cardSubtle,
                  borderRadius: AppRadius.br3,
                ),
                child: Text(note!, style: context.textTheme.bodyMedium),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label:
          '${status.label}, ${actorRole.label}, $timeText'
          '${isRework ? ', rework' : ''}'
          '${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: _nodeBox,
              child: Column(
                children: <Widget>[
                  SizedBox.square(
                    dimension: _nodeBox,
                    child: CustomPaint(
                      painter: _NodePainter(
                        color: nodeColor,
                        card: colors.card,
                        current: isCurrent,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: scheme.outlineVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  const _NodePainter({
    required this.color,
    required this.card,
    required this.current,
  });

  final Color color;
  final Color card;
  final bool current;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    if (current) {
      // `card` fill in a 4 px ring of the node colour; node is 16 px.
      canvas.drawCircle(c, 8, Paint()..color = card);
      canvas.drawCircle(
        c,
        6,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      return;
    }
    // Past: accent fill (16 px) with a 3 px `card` ring and a 1.5 px accent
    // halo around it.
    canvas.drawCircle(c, 11, Paint()..color = card);
    canvas.drawCircle(
      c,
      10.25,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NodePainter old) =>
      old.color != color || old.card != card || old.current != current;
}

/// The "Admin only" tag (contract 8.14, 8.25): `primaryContainer` with an
/// `overline` label.
class AdminOnlyTag extends StatelessWidget {
  /// Creates the tag.
  const AdminOnlyTag({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.br2,
      ),
      child: Text(
        'ADMIN ONLY',
        style: AppTypography.overline.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// A whole public timeline (contract 8.14): oldest first, built from
/// [PublicStatusEvent]s, which carry roles but no actor identity. Marks the
/// latest entry as current and any T7 reject as rework.
class ComplaintTimeline extends StatelessWidget {
  /// Creates a timeline for [events].
  const ComplaintTimeline({super.key, required this.events, this.now});

  /// The events, in any order (they are shown oldest first).
  final List<PublicStatusEvent> events;

  /// Reference time for relative times.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final List<PublicStatusEvent> ordered = <PublicStatusEvent>[
      ...events,
    ]..sort((PublicStatusEvent a, PublicStatusEvent b) => a.at.compareTo(b.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < ordered.length; i++)
          TimelineItem(
            status: ordered[i].status,
            actorRole: ordered[i].actorRole,
            at: ordered[i].at,
            note: ordered[i].note,
            isLast: i == ordered.length - 1,
            isCurrent: i == ordered.length - 1,
            isRework: _isRework(ordered, i),
            now: now,
          ),
      ],
    );
  }
}

/// Layout of a [StatusStepper].
enum StatusStepperVariant {
  /// Mobile (M-10): header and seven 6 px segments.
  compact,

  /// Admin and tablets: seven 14 px dots with captions; scrolls inside its
  /// container below 560 px.
  full,
}

/// The seven-status progress stepper (contract 8.14).
///
/// `compact`: the current status label (`title-sm`), "Step 4 of 7", and seven
/// 6 px segments (done `primary`, current `primary` with a 2 px `card` gap
/// and a 1.5 px `primary` ring, upcoming `outlineVariant`). `full`: seven
/// dots with 2 px connectors and `label-sm` captions. A Rework marker row
/// appears when [hasRework] (a T7 reject happened); rework is a marker, not
/// an eighth status.
class StatusStepper extends StatelessWidget {
  /// Creates a stepper at [status].
  const StatusStepper({
    super.key,
    required this.status,
    this.variant = StatusStepperVariant.compact,
    this.hasRework = false,
  });

  /// The current status.
  final ComplaintStatus status;

  /// Layout variant.
  final StatusStepperVariant variant;

  /// Shows the Rework marker row.
  final bool hasRework;

  static const double _fullMinWidth = 560;

  @override
  Widget build(BuildContext context) {
    final int total = ComplaintStatus.values.length;
    final int step = status.order + 1;
    final String label =
        'Status: ${status.label}, step $step of $total'
        '${hasRework ? ', reworked' : ''}';
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: switch (variant) {
        StatusStepperVariant.compact => _compact(context, step, total),
        StatusStepperVariant.full => _full(context),
      },
    );
  }

  Widget _marker(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.undo, size: 14, color: scheme.error),
          const SizedBox(width: AppSpace.s1),
          Text(
            'Rework',
            style: context.textTheme.labelSmall!.copyWith(color: scheme.error),
          ),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context, int step, int total) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(status.label, style: context.textTheme.titleSmall),
            ),
            Text(
              'Step $step of $total',
              style: context.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < total; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: _Segment(
                    done: i < status.order,
                    current: i == status.order,
                    primary: scheme.primary,
                    upcoming: scheme.outlineVariant,
                    gap: colors.card,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasRework)
          Align(alignment: Alignment.centerLeft, child: _marker(context)),
      ],
    );
  }

  Widget _full(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final List<ComplaintStatus> all = ComplaintStatus.values;
    final Widget stepper = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < all.length; i++)
              Expanded(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : (i <= status.order
                                      ? scheme.primary
                                      : scheme.outlineVariant),
                          ),
                        ),
                        _Dot(
                          done: i < status.order,
                          current: i == status.order,
                          primary: scheme.primary,
                          upcoming: scheme.outlineVariant,
                          card: colors.card,
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == all.length - 1
                                ? Colors.transparent
                                : (i < status.order
                                      ? scheme.primary
                                      : scheme.outlineVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      all[i].label,
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelSmall!.copyWith(
                        color: i == status.order
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: i == status.order
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (hasRework) _marker(context),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= _fullMinWidth) return stepper;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: _fullMinWidth, child: stepper),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.done,
    required this.current,
    required this.primary,
    required this.upcoming,
    required this.gap,
  });

  final bool done;
  final bool current;
  final Color primary;
  final Color upcoming;
  final Color gap;

  @override
  Widget build(BuildContext context) {
    final Widget bar = Container(
      height: 6,
      decoration: BoxDecoration(
        color: done || current ? primary : upcoming,
        borderRadius: AppRadius.br1,
      ),
    );
    if (!current) return bar;
    // Current: a 2 px `card` gap then a 1.5 px `primary` ring.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -3.5,
          right: -3.5,
          top: -3.5,
          bottom: -3.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: gap,
              borderRadius: const BorderRadius.all(Radius.circular(3.5)),
              border: Border.all(color: primary, width: 1.5),
            ),
          ),
        ),
        bar,
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.done,
    required this.current,
    required this.primary,
    required this.upcoming,
    required this.card,
  });

  final bool done;
  final bool current;
  final Color primary;
  final Color upcoming;
  final Color card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? primary : card,
        border: done
            ? null
            : Border.all(
                color: current ? primary : upcoming,
                width: current ? 4 : 2,
              ),
      ),
    );
  }
}
