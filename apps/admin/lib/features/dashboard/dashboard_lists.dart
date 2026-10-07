import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'dashboard_layout.dart';
import 'dashboard_states.dart';

/// One triage list of A-02: a titled panel of at most five complaint rows
/// (public views only) with a "View all" action that opens the complaint list
/// pre-filtered to the whole list. A row opens the complaint (A-04).
class _TriageListPanel extends ConsumerWidget {
  const _TriageListPanel({
    required this.title,
    required this.description,
    required this.emptyMessage,
    required this.list,
    required this.target,
  });

  final String title;

  /// What the list holds and how it is ordered, under the title.
  final String description;

  /// Shown when the list is empty.
  final String emptyMessage;

  final AsyncValue<DashboardList> list;

  /// The A-03 path of the whole list for a range.
  final String Function(CreatedRange range) target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatedRange range = ref.watch(dashboardRangeProvider);
    final DateTime now = ref.watch(dashboardClockProvider)();
    final DashboardList? data = list.value;
    final String? count = data == null
        ? null
        : (data.total > data.rows.length
              ? 'Showing ${data.rows.length} of ${data.total}'
              : '${data.total} ${data.total == 1 ? 'complaint' : 'complaints'}');
    return DashboardPanel(
      title: title,
      subtitle: count == null ? description : '$description. $count',
      actionLabel: 'View all',
      onAction: data == null ? null : () => context.go(target(range)),
      bleed: true,
      child: AsyncPanelBody<DashboardList>(
        value: list,
        loading: const ListSkeleton(),
        onRetry: () => refreshComplaints(ref),
        builder: (DashboardList l) {
          if (l.rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              child: Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final PublicComplaintView c in l.rows)
                ComplaintCard(
                  key: ValueKey<String>('row-${c.id}'),
                  complaint: c,
                  variant: ComplaintCardVariant.row,
                  now: now,
                  onTap: () => context.go(AppRoutes.complaint(c.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Needs attention: unresolved Critical / High complaints, heaviest first and
/// then longest waiting.
class NeedsAttentionList extends ConsumerWidget {
  const NeedsAttentionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TriageListPanel(
    title: 'Needs attention',
    description: 'Unresolved Critical and High, longest waiting first',
    emptyMessage: 'Nothing needs attention right now.',
    list: ref.watch(dashboardNeedsAttentionProvider),
    target: (CreatedRange r) => complaintsPathWith(
      unresolved: true,
      priorities: const <Priority>[Priority.critical, Priority.high],
      created: r,
    ),
  );
}

/// Oldest unresolved: every unresolved complaint, longest waiting first.
class OldestUnresolvedList extends ConsumerWidget {
  const OldestUnresolvedList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TriageListPanel(
    title: 'Oldest unresolved',
    description: 'Longest waiting, any priority',
    emptyMessage: 'No unresolved complaints.',
    list: ref.watch(dashboardOldestUnresolvedProvider),
    target: (CreatedRange r) =>
        complaintsPathWith(unresolved: true, created: r),
  );
}

/// Awaiting manual triage: reviewed complaints no department is assigned to
/// (Safety and Other are never routed automatically).
class AwaitingTriageList extends ConsumerWidget {
  const AwaitingTriageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TriageListPanel(
    title: 'Awaiting manual triage',
    description: 'Reviewed, with no department assigned yet',
    emptyMessage: 'No complaints are waiting for triage.',
    list: ref.watch(dashboardAwaitingTriageProvider),
    target: (CreatedRange r) => complaintsPathWith(triage: true, created: r),
  );
}
