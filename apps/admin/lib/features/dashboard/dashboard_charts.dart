import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import 'dashboard_layout.dart';
import 'dashboard_states.dart';
import 'intake_chart.dart';

/// A clickable bar of an A-02 chart: a [MetricBarRow] that opens the complaint
/// list pre-filtered to the bar's status, priority or category (and the
/// dashboard's range).
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.value,
    required this.onTap,
    required this.bar,
  });

  final String label;
  final int value;
  final VoidCallback onTap;
  final MetricBarRow bar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AppPressable(
      onTap: onTap,
      radius: AppRadius.br2,
      semanticLabel: '$label: $value. Open in the complaint list',
      builder: (BuildContext context, Set<WidgetState> states) => Container(
        color: applyStateLayer(Colors.transparent, scheme.onSurface, states),
        child: bar,
      ),
    );
  }
}

int _maxOf(Iterable<int> values) =>
    values.fold<int>(0, (int a, int b) => a > b ? a : b);

/// Status breakdown: all seven statuses in lifecycle order, summing to Total.
class StatusBreakdownChart extends ConsumerWidget {
  const StatusBreakdownChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatedRange range = ref.watch(dashboardRangeProvider);
    return DashboardPanel(
      title: 'Status breakdown',
      subtitle: 'Every status, in lifecycle order',
      child: AsyncPanelBody<DashboardMetrics>(
        value: ref.watch(dashboardMetricsProvider),
        onRetry: () => refreshComplaints(ref),
        builder: (DashboardMetrics m) {
          final int max = _maxOf(m.byStatus.values);
          return Column(
            children: <Widget>[
              for (final MapEntry<ComplaintStatus, int> e in m.byStatus.entries)
                _BarButton(
                  label: e.key.label,
                  value: e.value,
                  onTap: () => context.go(
                    complaintsPathWith(
                      statuses: <ComplaintStatus>[e.key],
                      created: range,
                    ),
                  ),
                  bar: MetricBarRow.status(
                    context: context,
                    status: e.key,
                    value: e.value,
                    maxValue: max,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Unresolved complaints by effective priority, Critical down to Low.
class PriorityBreakdownChart extends ConsumerWidget {
  const PriorityBreakdownChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatedRange range = ref.watch(dashboardRangeProvider);
    return DashboardPanel(
      title: 'Unresolved by priority',
      subtitle: 'Effective priority, Critical first',
      child: AsyncPanelBody<DashboardMetrics>(
        value: ref.watch(dashboardMetricsProvider),
        onRetry: () => refreshComplaints(ref),
        builder: (DashboardMetrics m) {
          final int max = _maxOf(m.unresolvedByPriority.values);
          return Column(
            children: <Widget>[
              for (final MapEntry<Priority, int> e
                  in m.unresolvedByPriority.entries)
                _BarButton(
                  label: e.key.label,
                  value: e.value,
                  onTap: () => context.go(
                    complaintsPathWith(
                      unresolved: true,
                      priorities: <Priority>[e.key],
                      created: range,
                    ),
                  ),
                  bar: MetricBarRow.priority(
                    context: context,
                    priority: e.key,
                    value: e.value,
                    maxValue: max,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Unresolved complaints by category, most first.
class CategoryBreakdownChart extends ConsumerWidget {
  const CategoryBreakdownChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatedRange range = ref.watch(dashboardRangeProvider);
    return DashboardPanel(
      title: 'Unresolved by category',
      subtitle: 'Most complaints first',
      child: AsyncPanelBody<DashboardMetrics>(
        value: ref.watch(dashboardMetricsProvider),
        onRetry: () => refreshComplaints(ref),
        builder: (DashboardMetrics m) {
          final int max = _maxOf(m.unresolvedByCategory.values);
          return Column(
            children: <Widget>[
              for (final MapEntry<ProblemCategory, int> e
                  in m.unresolvedByCategory.entries)
                _BarButton(
                  label: e.key.label,
                  value: e.value,
                  onTap: () => context.go(
                    complaintsPathWith(
                      unresolved: true,
                      categories: <ProblemCategory>[e.key],
                      created: range,
                    ),
                  ),
                  bar: MetricBarRow.category(
                    context: context,
                    category: e.key,
                    value: e.value,
                    maxValue: max,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Intake per day over the last 14 days (a trend; not narrowed by the range).
class IntakeChartPanel extends ConsumerWidget {
  const IntakeChartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardPanel(
      title: 'Intake per day',
      subtitle: 'New complaints, last 14 days',
      child: AsyncPanelBody<List<IntakeDay>>(
        value: ref.watch(dashboardIntakeProvider),
        onRetry: () => refreshComplaints(ref),
        builder: (List<IntakeDay> days) => IntakeChart(days: days),
      ),
    );
  }
}
