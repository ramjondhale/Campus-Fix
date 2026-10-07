import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import 'dashboard_layout.dart';

/// One metric card of A-02: what it shows, how it counts and where a click
/// takes the admin (a complaint list preset, A-03).
class MetricCardSpec {
  const MetricCardSpec({
    required this.id,
    required this.label,
    required this.definition,
    required this.value,
    required this.target,
    this.attention = false,
  });

  /// A stable key for the card (tests, semantics).
  final String id;
  final String label;

  /// The one-line definition under the value.
  final String definition;

  /// The count, from the range's [DashboardMetrics].
  final int Function(DashboardMetrics m) value;

  /// The A-03 path of the preset, carrying the dashboard's range.
  final String Function(CreatedRange range) target;

  /// The Critical / High flag.
  final bool attention;
}

/// The eight cards in display order (design contract 8.15, screens-spec
/// A-02). Each preset opens A-03 on exactly the set the card counted
/// (AC-47), so it carries the same range and the same filter.
final List<MetricCardSpec> kMetricCardSpecs = <MetricCardSpec>[
  MetricCardSpec(
    id: 'total',
    label: 'Total',
    definition: 'All complaints in range',
    value: (m) => m.total,
    target: (r) => complaintsPathWith(created: r),
  ),
  MetricCardSpec(
    id: 'pending',
    label: 'Pending',
    definition: 'Reported or reviewed',
    value: (m) => m.pending,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
      ],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'criticalHigh',
    label: 'Critical / High',
    definition: 'Unresolved, Critical or High priority',
    attention: true,
    value: (m) => m.criticalHigh,
    target: (r) => complaintsPathWith(
      unresolved: true,
      priorities: const <Priority>[Priority.critical, Priority.high],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'assigned',
    label: 'Assigned',
    definition: 'Waiting for the department',
    value: (m) => m.assigned,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[ComplaintStatus.assigned],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'inProgress',
    label: 'In progress',
    definition: 'Repair under way',
    value: (m) => m.inProgress,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[ComplaintStatus.inProgress],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'resolved',
    label: 'Resolved',
    definition: 'Resolved or verified',
    value: (m) => m.resolved,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[
        ComplaintStatus.resolved,
        ComplaintStatus.verified,
      ],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'closed',
    label: 'Closed',
    definition: 'Signed off by an admin',
    value: (m) => m.closed,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[ComplaintStatus.closed],
      created: r,
    ),
  ),
  MetricCardSpec(
    id: 'awaitingVerification',
    label: 'Awaiting verification',
    definition: 'Resolved, not yet verified',
    value: (m) => m.awaitingVerification,
    target: (r) => complaintsPathWith(
      statuses: const <ComplaintStatus>[ComplaintStatus.resolved],
      created: r,
    ),
  ),
];

/// The grid of metric cards at the top of the dashboard.
///
/// Each card has its own loading skeleton and its own error with Retry
/// (screens-spec A-02 states), and a click opens the complaint list with the
/// card's preset.
class MetricCardGrid extends ConsumerWidget {
  const MetricCardGrid({super.key});

  /// Cards per row for a window class: the contract's auto-fit grid, set per
  /// class so eight cards always fill whole rows (4 x 2 on the console).
  static int columnsFor(AppWindowClass windowClass) => switch (windowClass) {
    AppWindowClass.expanded => 4,
    AppWindowClass.medium => 3,
    AppWindowClass.compact => 2,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardMetrics> metrics = ref.watch(
      dashboardMetricsProvider,
    );
    final CreatedRange range = ref.watch(dashboardRangeProvider);

    Widget card(MetricCardSpec spec) {
      return metrics.when(
        loading: () => MetricCard(
          key: _key(spec),
          label: spec.label,
          value: '',
          loading: true,
        ),
        error: (_, _) => MetricCard(
          key: _key(spec),
          label: spec.label,
          value: '',
          hasError: true,
          onRetry: () => refreshComplaints(ref),
        ),
        data: (DashboardMetrics m) => MetricCard(
          key: _key(spec),
          label: spec.label,
          value: '${spec.value(m)}',
          definition: spec.definition,
          attention: spec.attention,
          onTap: () => context.go(spec.target(range)),
        ),
      );
    }

    return DashboardGrid(
      columns: columnsFor(context.windowClass),
      gap: AppLayout.cardGap,
      children: <Widget>[
        for (final MetricCardSpec s in kMetricCardSpecs) card(s),
      ],
    );
  }

  static Key _key(MetricCardSpec spec) => ValueKey<String>('metric-${spec.id}');
}
