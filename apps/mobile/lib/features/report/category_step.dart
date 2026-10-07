import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'report_flow.dart';

/// M-03 Report: Category (step 1 of 5). Pick exactly one of the eight
/// categories; `safety` forces the safety flag on (locked in step 4).
class CategoryStep extends ConsumerWidget {
  const CategoryStep({super.key, this.edit = false});

  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportDraft draft = ref.watch(reportDraftProvider);
    final ReportDraftNotifier notifier = ref.read(reportDraftProvider.notifier);
    const List<ProblemCategory> categories = ProblemCategory.values;

    Widget tile(ProblemCategory c) => CategoryTile(
      category: c,
      selected: draft.category == c,
      onTap: () => notifier.setCategory(c),
    );

    return PopScope(
      // System back on the first step offers to discard what was entered
      // (screens-spec G-9); with nothing entered it simply leaves.
      canPop: edit || (!draft.hasInput && context.canPop()),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) discardReport(context, ref);
      },
      child: ReportStepScaffold(
        step: 1,
        stepLabel: 'Category',
        edit: edit,
        primaryLabel: edit ? 'Done' : 'Next',
        onPrimary: draft.categoryValid
            ? () => continueFrom(
                context,
                edit: edit,
                next: AppRoutes.reportLocation,
              )
            : null,
        children: <Widget>[
          const StepHeading(
            title: 'What kind of problem is it?',
            subtitle: 'Choose the closest match.',
          ),
          for (int i = 0; i < categories.length; i += 2) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpace.s3),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: tile(categories[i])),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: i + 1 < categories.length
                        ? tile(categories[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
