import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'report_flow.dart';

/// M-07 Report: Review (step 5 of 5). A read-only summary of the draft with an
/// Edit link per section, the privacy notice, possible duplicates and Submit.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final SubmittedReport? report = await ref
        .read(reportSubmitProvider.notifier)
        .submit();
    if (report == null || !context.mounted) return;
    // Replaces the flow: back from the confirmation goes Home (G-9).
    context.go(AppRoutes.reportDone(report.complaintId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportDraft draft = ref.watch(reportDraftProvider);
    final ReportSubmitState submit = ref.watch(reportSubmitProvider);
    final List<PublicComplaintView> duplicates = ref.watch(
      possibleDuplicatesProvider,
    );
    final ProblemCategory? category = draft.category;
    final bool busy = submit.submitting;
    void edit(String route) => context.push(reportEditPath(route));

    return ReportStepScaffold(
      step: 5,
      stepLabel: 'Review',
      primaryLabel: 'Submit',
      primaryLoading: busy,
      onPrimary: draft.isComplete && !busy ? () => _submit(context, ref) : null,
      secondary: AppButton(
        label: 'Cancel report',
        variant: AppButtonVariant.tertiary,
        expand: true,
        onPressed: busy ? null : () => discardReport(context, ref),
      ),
      children: <Widget>[
        const StepHeading(
          title: 'Review your report',
          subtitle: 'Check everything before you submit.',
        ),
        if (submit.status == ReportSubmitStatus.failed &&
            submit.error != null) ...<Widget>[
          InlineBanner(
            kind: FeedbackKind.error,
            title: "Couldn't submit",
            message: submit.error!,
            actionLabel: draft.isComplete ? 'Retry' : null,
            onAction: draft.isComplete && !busy
                ? () => _submit(context, ref)
                : null,
          ),
          const SizedBox(height: AppSpace.s4),
        ],
        _Section(
          title: 'Category',
          missing: !draft.categoryValid,
          onEdit: () => edit(AppRoutes.reportCategory),
          child: category == null
              ? null
              : Row(
                  children: <Widget>[
                    CategoryChip(category: category),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(child: _Value(category.label)),
                  ],
                ),
        ),
        _Section(
          title: 'Location',
          missing: !draft.locationValid,
          onEdit: () => edit(AppRoutes.reportLocation),
          child: draft.locationValid
              ? _Value(
                  '${draft.trimmedBuilding} · ${draft.floor} · '
                  '${draft.trimmedRoom}',
                )
              : null,
        ),
        _Section(
          title: 'Photos (${draft.photos.length})',
          missing: !draft.photosValid,
          onEdit: () => edit(AppRoutes.reportPhotos),
          child: draft.photos.isEmpty
              ? null
              : Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: <Widget>[
                    for (final Attachment a in draft.photos)
                      SizedBox.square(
                        dimension: 64,
                        child: ClipRRect(
                          borderRadius: AppRadius.br3,
                          child: ComplaintPhoto(
                            category: category ?? ProblemCategory.other,
                            attachment: a,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        _Section(
          title: 'Details',
          missing: !draft.descriptionValid,
          onEdit: () => edit(AppRoutes.reportDetails),
          child: draft.descriptionValid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Value(draft.trimmedDescription),
                    const SizedBox(height: AppSpace.s3),
                    _Labelled('Severity', draft.severity.label),
                    _Labelled(
                      'People affected',
                      peopleAffectedChoice(draft.peopleAffected),
                    ),
                    _Labelled(
                      'Safety hazard',
                      draft.safetyFlag ? 'Yes (marked urgent)' : 'No',
                    ),
                  ],
                )
              : null,
        ),
        const InlineBanner(
          kind: FeedbackKind.info,
          message:
              'Your name and contact details are never shown on the board '
              'or to maintenance staff.',
        ),
        if (duplicates.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.s6),
          Semantics(
            header: true,
            child: Text(
              'Possible duplicates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            'Someone may have reported this already. You can still submit.',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          for (final PublicComplaintView c in duplicates) ...<Widget>[
            ComplaintCard(
              complaint: c,
              onTap: () => context.push(AppRoutes.boardItem(c.id)),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
        ],
      ],
    );
  }
}

/// A summary block with a title, an Edit link and its content, or a "Missing"
/// note when the step is not valid yet.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.missing,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final bool missing;
  final VoidCallback onEdit;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.campusColors.card,
          borderRadius: AppRadius.br5,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                  ),
                  AppButton(
                    label: 'Edit',
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.tertiary,
                    semanticLabel: 'Edit $title',
                    onPressed: onEdit,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              if (missing || child == null)
                Text(
                  'Missing. Tap Edit to complete this step.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                child!,
            ],
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
