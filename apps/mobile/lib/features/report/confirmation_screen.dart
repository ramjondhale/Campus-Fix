import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';

/// The statuses a complaint passes through after it is reported (screens-spec
/// M-08 "next steps").
const List<String> _nextSteps = <String>[
  'Reviewed',
  'Assigned',
  'In Progress',
  'Resolved',
  'Verified',
  'Closed',
];

/// M-08 Confirmation: the generated Complaint ID, the computed priority, a
/// summary of what was filed and what happens next. System back goes Home
/// (never back into the finished flow, screens-spec G-9).
class ReportConfirmationScreen extends ConsumerWidget {
  const ReportConfirmationScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SubmittedReport? last = ref.watch(reportSubmitProvider).last;
    final SubmittedReport? submitted = last?.complaintId == complaintId
        ? last
        : null;
    final AsyncValue<List<PublicComplaintView>> mine = ref.watch(
      myComplaintsProvider,
    );
    PublicComplaintView? stored;
    for (final PublicComplaintView c
        in mine.asData?.value ?? const <PublicComplaintView>[]) {
      if (c.id == complaintId) stored = c;
    }
    // The stored complaint's priority wins; the one returned by submit covers
    // a failed or pending re-fetch.
    final Priority? priority = stored?.effectivePriority ?? submitted?.priority;

    void goHome() => context.go(AppRoutes.home);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        appBar: const AppTopBar.page(title: 'Report submitted'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpace.s3),
              Text(
                'Thanks, your report is in',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                'Your Complaint ID',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Center(
                child: ComplaintIdText(
                  id: complaintId,
                  size: ComplaintIdSize.lg,
                  copyable: true,
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const StatusBadge(status: ComplaintStatus.reported),
                  if (priority != null) PriorityTag(priority: priority),
                ],
              ),
              const SizedBox(height: AppSpace.s6),
              if (stored != null)
                _Summary(complaint: stored)
              else if (mine.isLoading)
                const SkeletonBlock.fraction(widthFactor: 1, height: 96)
              else if (mine.hasError)
                EmptyState.error(
                  title: "Couldn't load the details",
                  message: 'Your report was submitted. Try loading the rest.',
                  onAction: () => refreshComplaints(ref),
                ),
              const SizedBox(height: AppSpace.s6),
              Semantics(
                header: true,
                child: Text(
                  'What happens next',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                'It moves through these steps. '
                "You'll be notified at each one.",
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              for (int i = 0; i < _nextSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Text(_nextSteps[i], style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.s6),
              AppButton(
                label: 'View complaint',
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () => context.go(AppRoutes.complaint(complaintId)),
              ),
              const SizedBox(height: AppSpace.s3),
              AppButton(
                label: 'Report another',
                size: AppButtonSize.lg,
                expand: true,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  ref.read(reportDraftProvider.notifier).reset();
                  context.go(AppRoutes.reportCategory);
                },
              ),
              const SizedBox(height: AppSpace.s3),
              AppButton(
                label: 'Home',
                size: AppButtonSize.lg,
                expand: true,
                variant: AppButtonVariant.tertiary,
                onPressed: goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category, location and submission time of the stored complaint.
class _Summary extends StatelessWidget {
  const _Summary({required this.complaint});

  final PublicComplaintView complaint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
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
    return DecoratedBox(
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
            row('Category', complaint.category.label),
            row('Location', ComplaintCard.locationOf(complaint)),
            row('Submitted', formatAbsoluteTime(complaint.createdAt)),
          ],
        ),
      ),
    );
  }
}
