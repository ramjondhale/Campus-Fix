// The timeline panel of A-04 (screens-spec A-04, "Timeline").
//
// * **Admin:** every event with the actor's name / ID and role beside the
//   status and note. A reporter's own event shows the role only: the
//   reporter's name stays behind the identity reveal (AC-51), so nothing here
//   can leak it.
// * **Verifier:** the public form (role, time and note), exactly what the
//   design system's `ComplaintTimeline` draws from `PublicStatusEvent`s,
//   which have no field for an actor id (AC-52).

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import 'complaint_detail_controller.dart';
import 'detail_widgets.dart';

/// The timeline panel for [detail]: the admin form or the public form.
class DetailTimelinePanel extends StatelessWidget {
  const DetailTimelinePanel({
    super.key,
    required this.detail,
    required this.now,
  });

  final ComplaintDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AdminDetail? admin = detail.admin;
    final bool empty = admin == null
        ? detail.complaint.timeline.isEmpty
        : admin.view.timeline.isEmpty;
    return DetailSection(
      title: 'Timeline',
      child: empty
          ? Text(
              'No history yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : admin == null
          ? ComplaintTimeline(events: detail.complaint.timeline, now: now)
          : _AdminTimeline(detail: admin, now: now),
    );
  }
}

class _AdminTimeline extends StatelessWidget {
  const _AdminTimeline({required this.detail, required this.now});

  final AdminDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final List<StatusEvent> events = <StatusEvent>[...detail.view.timeline]
      ..sort((StatusEvent a, StatusEvent b) => a.at.compareTo(b.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < events.length; i++)
          TimelineItem(
            status: events[i].status,
            actorRole: events[i].actorRole,
            at: events[i].at,
            note: events[i].note,
            isLast: i == events.length - 1,
            isCurrent: i == events.length - 1,
            isRework:
                i > 0 &&
                events[i].status == ComplaintStatus.inProgress &&
                events[i - 1].status == ComplaintStatus.resolved,
            adminActorLine: _actorLine(events[i]),
            now: now,
          ),
      ],
    );
  }

  /// "Name · ID" of the actor, or `null` for the reporter (identity is
  /// reveal-gated) and for an actor the directory does not know.
  String? _actorLine(StatusEvent e) {
    if (e.actorRole == UserRole.reporter) return null;
    return detail.staffById(e.actorId)?.line ?? e.actorId;
  }
}
