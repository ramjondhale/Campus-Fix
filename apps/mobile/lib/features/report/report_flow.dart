import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';

/// The query parameter that opens a step from Review ("Edit"): the step then
/// ends with **Done** and returns to Review instead of moving on.
const String kEditParam = 'edit';

/// [route] opened in edit mode (screens-spec M-07 "Edit", draft preserved).
String reportEditPath(String route) => '$route?$kEditParam=1';

/// Whether the current route was opened in edit mode.
bool isEditMode(GoRouterState state) =>
    state.uri.queryParameters[kEditParam] == '1';

/// The four form choices of "People affected", phrased as in screens-spec M-06.
String peopleAffectedChoice(PeopleAffected people) => switch (people) {
  PeopleAffected.individual => 'Just me',
  PeopleAffected.small => 'A few people',
  PeopleAffected.many => 'A class, lab or floor',
  PeopleAffected.campusWide => 'Whole campus',
};

/// Asks "Discard report?" when the draft has input, then clears it and goes
/// Home (screens-spec M-03 Close, M-07 Cancel, G-9). Returns whether the
/// report was discarded.
Future<bool> discardReport(BuildContext context, WidgetRef ref) async {
  if (ref.read(reportDraftProvider).hasInput) {
    final bool? discard = await AppDialog.confirm(
      context: context,
      title: 'Discard report?',
      message: 'What you entered so far will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard != true) return false;
  }
  ref.read(reportDraftProvider.notifier).reset();
  if (context.mounted) context.go(AppRoutes.home);
  return true;
}

/// The frame of one report step (M-03..M-07): the flow top bar with step
/// progress and a Close (X) that offers to discard, the scrollable [children],
/// and a bottom bar with Back and the primary action.
class ReportStepScaffold extends ConsumerWidget {
  const ReportStepScaffold({
    super.key,
    required this.step,
    required this.stepLabel,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.edit = false,
    this.showBack = true,
    this.primaryLoading = false,
    this.secondary,
  });

  /// 1-based step number (Review is 5).
  final int step;
  final String stepLabel;
  final List<Widget> children;

  /// The primary button's label; `null` [onPrimary] disables it.
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Opened from Review: Back is hidden (the primary button returns there).
  final bool edit;
  final bool showBack;
  final bool primaryLoading;

  /// An optional extra action above the bottom row (Review's Cancel).
  final Widget? secondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppTopBar.flow(
        stepLabel: stepLabel,
        step: step,
        onClose: primaryLoading ? null : () => discardReport(context, ref),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: children,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (secondary != null) ...<Widget>[
                      secondary!,
                      const SizedBox(height: AppSpace.s2),
                    ],
                    Row(
                      children: <Widget>[
                        if (showBack && !edit && step > 1) ...<Widget>[
                          AppButton(
                            label: 'Back',
                            size: AppButtonSize.lg,
                            variant: AppButtonVariant.secondary,
                            onPressed: primaryLoading
                                ? null
                                : () => context.pop(),
                          ),
                          const SizedBox(width: AppSpace.s3),
                        ],
                        Expanded(
                          child: AppButton(
                            label: primaryLabel,
                            size: AppButtonSize.lg,
                            expand: true,
                            loading: primaryLoading,
                            onPressed: onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaves a step: back to Review when it was opened in edit mode, otherwise on
/// to [next].
void continueFrom(BuildContext context, {required bool edit, String? next}) {
  if (edit) {
    context.pop();
  } else if (next != null) {
    context.push(next);
  }
}

/// A step title with an optional supporting line.
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: AppSpace.s1),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
