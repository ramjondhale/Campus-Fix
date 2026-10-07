// The Manage bar of A-04 (screens-spec A-04, "Manage actions"): the actions the
// signed-in role is offered for this complaint, each one a button that opens
// its confirm dialog. An action whose precondition already fails is shown
// disabled with the reason beside it (AC-53); a `closed` complaint shows a
// read-only notice instead of any action (INV-4).

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import 'complaint_detail_controller.dart';
import 'detail_widgets.dart';

/// One action button with, when the action is disabled, the reason why.
class ManageActionButton extends StatelessWidget {
  const ManageActionButton({
    super.key,
    required this.option,
    required this.onPressed,
    this.busy = false,
    this.loading = false,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.md,
  });

  final ManageActionOption option;

  /// Called when the (enabled) button is pressed.
  final VoidCallback onPressed;

  /// Another action is in flight: every button waits (no double submit).
  final bool busy;

  /// This action is the one in flight (spinner on the button).
  final bool loading;

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? reason = option.disabledReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButton(
          label: option.label,
          variant: variant,
          size: size,
          loading: loading,
          onPressed: option.enabled && !busy ? onPressed : null,
        ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.s16 * 4),
              child: Text(
                reason,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The variant of the button of [action] among [options]: the first plain
/// action is the primary one of the bar, a reject is destructive, the rest
/// are secondary.
AppButtonVariant manageButtonVariant(
  ManageAction action,
  List<ManageActionOption> options,
) {
  if (action.isDestructive) return AppButtonVariant.destructiveOutlined;
  final ManageAction? first = options
      .where((ManageActionOption o) => !o.action.isDestructive)
      .map((ManageActionOption o) => o.action)
      .firstOrNull;
  return first == action
      ? AppButtonVariant.primary
      : AppButtonVariant.secondary;
}

/// The Manage section of the detail screen.
class ManageBar extends StatelessWidget {
  const ManageBar({
    super.key,
    required this.detail,
    required this.options,
    required this.state,
    required this.onAction,
  });

  final ComplaintDetail detail;

  /// The status actions on offer ([manageActionsFor]).
  final List<ManageActionOption> options;

  /// What is in flight ([detailActionProvider]).
  final DetailActionState state;

  final ValueChanged<ManageAction> onAction;

  @override
  Widget build(BuildContext context) {
    if (detail.isReadOnly) {
      return const InlineBanner(
        kind: FeedbackKind.info,
        title: 'This complaint is closed',
        message: 'A closed complaint is read-only: it has no actions.',
      );
    }
    if (options.isEmpty) {
      return InlineBanner(
        kind: FeedbackKind.info,
        message: _nothingToDo(detail),
      );
    }
    return DetailSection(
      title: 'Manage',
      child: Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s3,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: <Widget>[
          for (final ManageActionOption o in options)
            ManageActionButton(
              option: o,
              busy: state.busy,
              loading: state.isRunning(o.action),
              variant: manageButtonVariant(o.action, options),
              onPressed: () => onAction(o.action),
            ),
        ],
      ),
    );
  }

  /// What a role with no action on this complaint is told.
  static String _nothingToDo(ComplaintDetail d) {
    final bool unrouted =
        d.status == ComplaintStatus.reviewed &&
        d.complaint.assignedDepartment == null;
    return !d.isAdmin && unrouted
        ? 'This complaint has no department yet. An admin assigns it, so '
              'there is nothing for you to do here.'
        : 'There is nothing for you to do on this complaint right now.';
  }
}
