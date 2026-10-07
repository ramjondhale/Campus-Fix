import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'home_widgets.dart';

/// Maintenance Home (M-02): counts of the worker's queue (To start, In
/// progress, Rework needed), "Open my work" and a shortcut to the board.
/// Counts are aggregates over public views; no assignee names.
class MaintenanceHome extends ConsumerWidget {
  const MaintenanceHome({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkQueue> queue = ref.watch(workQueueProvider);
    final String department = user.department?.label ?? 'your department';
    void openWork() => context.go(AppRoutes.work);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeSectionHeader(title: 'My work · $department'),
        const SizedBox(height: AppSpace.s3),
        AsyncSection<WorkQueue>(
          value: queue,
          onRetry: () => refreshComplaints(ref),
          errorTitle: "Couldn't load your work",
          loading: const CardColumn(
            children: <Widget>[
              MetricCard(label: 'To start', value: '', loading: true),
              MetricCard(label: 'In progress', value: '', loading: true),
              MetricCard(label: 'Rework needed', value: '', loading: true),
            ],
          ),
          builder: (WorkQueue q) => q.isEmpty
              ? EmptyState(
                  icon: Icons.task_alt,
                  title: 'Nothing to do right now',
                  message: 'No work assigned to $department.',
                )
              : CardColumn(
                  children: <Widget>[
                    MetricCard(
                      label: 'To start',
                      value: '${q.toStartCount}',
                      definition: 'Assigned and waiting for you',
                      onTap: openWork,
                    ),
                    MetricCard(
                      label: 'In progress',
                      value: '${q.inProgressCount}',
                      definition: 'Work you have started',
                      onTap: openWork,
                    ),
                    MetricCard(
                      label: 'Rework needed',
                      value: '${q.reworkCount}',
                      definition: 'Sent back by a verifier',
                      attention: q.reworkCount > 0,
                      onTap: openWork,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.s6),
        AppButton(
          label: 'Open my work',
          size: AppButtonSize.lg,
          expand: true,
          leadingIcon: Icons.build_outlined,
          onPressed: openWork,
        ),
        const SizedBox(height: AppSpace.s3),
        AppButton(
          label: 'Campus board',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          expand: true,
          leadingIcon: Icons.view_kanban_outlined,
          onPressed: () => context.go(AppRoutes.board),
        ),
      ],
    );
  }
}
