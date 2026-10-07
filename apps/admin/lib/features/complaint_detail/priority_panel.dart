// The Priority panel of A-04 (screens-spec A-04, "Priority panel", `[DM-3]`):
// **admin only**. It shows the effective priority, the computed priority, the
// override, the inputs behind the score (severity, people affected, safety
// flag), the aging bucket and the two priority edits. A verifier never gets
// this panel: it is built from an `AdminComplaintView` (AC-52).

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import 'complaint_detail_controller.dart';
import 'detail_widgets.dart';
import 'manage_bar.dart';

/// The aging bucket of [waited] (priority-engine-spec section 6), as words.
String agingBucketLabel(Duration waited) {
  if (waited < const Duration(hours: 24)) return 'Under 1 day';
  if (waited < const Duration(hours: 72)) return '1 to 3 days';
  if (waited < const Duration(days: 7)) return '3 to 7 days';
  if (waited < const Duration(days: 14)) return '1 to 2 weeks';
  return 'Over 2 weeks';
}

class PriorityPanel extends StatelessWidget {
  const PriorityPanel({
    super.key,
    required this.view,
    required this.now,
    required this.options,
    required this.state,
    required this.onAction,
  });

  final AdminComplaintView view;
  final DateTime now;

  /// The two priority edits on offer ([priorityActionsFor]).
  final List<ManageActionOption> options;
  final DetailActionState state;
  final ValueChanged<ManageAction> onAction;

  @override
  Widget build(BuildContext context) {
    final Priority? override = view.priorityOverride;
    final Duration waited = now.difference(view.createdAt);
    final bool frozen = view.status.order >= ComplaintStatus.resolved.order;

    return DetailSection(
      title: 'Priority',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DetailFact(
            label: 'Effective priority',
            child: Align(
              alignment: Alignment.centerLeft,
              child: PriorityTag(
                priority: view.effectivePriority,
                overridden: override != null,
              ),
            ),
          ),
          DetailFact(
            label: 'Computed priority',
            child: Align(
              alignment: Alignment.centerLeft,
              child: PriorityTag(priority: view.priority, size: AppTagSize.sm),
            ),
          ),
          DetailFact(
            label: 'Override',
            child: override == null
                ? Text('None', style: Theme.of(context).textTheme.bodyMedium)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: PriorityTag(priority: override, size: AppTagSize.sm),
                  ),
          ),
          DetailFact(label: 'Severity', value: view.severity.label),
          DetailFact(
            label: 'People affected',
            value: view.peopleAffected.label,
          ),
          DetailFact(
            label: 'Safety flag',
            value: view.safetyFlag ? 'Flagged' : 'Not flagged',
          ),
          DetailFact(
            label: 'Aging',
            value: frozen
                ? 'Frozen when the repair was resolved'
                : agingBucketLabel(waited.isNegative ? Duration.zero : waited),
          ),
          if (options.isNotEmpty)
            Wrap(
              spacing: AppSpace.s3,
              runSpacing: AppSpace.s3,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: <Widget>[
                for (final ManageActionOption o in options)
                  ManageActionButton(
                    option: o,
                    size: AppButtonSize.sm,
                    busy: state.busy,
                    loading: state.isRunning(o.action),
                    onPressed: () => onAction(o.action),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
