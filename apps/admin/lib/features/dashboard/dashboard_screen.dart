import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../shell/admin_page.dart';
import 'dashboard_charts.dart';
import 'dashboard_layout.dart';
import 'dashboard_lists.dart';
import 'metric_card_grid.dart';

/// A-02 Admin Dashboard (admins and verifiers, identical content).
///
/// Management monitoring: a date-range control, a grid of metric cards, four
/// breakdown charts and three short triage lists. Every number is an aggregate
/// of `PublicComplaintView`s (`allComplaintsProvider`, live), so the screen
/// carries no reporter, assignee or actor data. A click on a card or chart bar
/// opens the complaint list (A-03) pre-filtered to what it counted; a list row
/// opens the complaint (A-04).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool noComplaints =
        ref.watch(allComplaintsProvider).value?.isEmpty ?? false;
    final bool twoColumns = context.windowClass == AppWindowClass.expanded;
    final int panelColumns = twoColumns ? 2 : 1;

    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _RangeControl(),
          const SizedBox(height: AppSpace.s4),
          const MetricCardGrid(),
          const SizedBox(height: AppSpace.s6),
          if (noComplaints)
            const EmptyState.nothing(
              title: 'No complaints yet',
              message: 'Complaints show up here as soon as they are reported.',
              alignment: CrossAxisAlignment.start,
            )
          else ...<Widget>[
            DashboardGrid(
              columns: panelColumns,
              gap: AppSpace.s4,
              children: const <Widget>[
                StatusBreakdownChart(),
                PriorityBreakdownChart(),
                CategoryBreakdownChart(),
                IntakeChartPanel(),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            DashboardGrid(
              columns: panelColumns,
              gap: AppSpace.s4,
              spanLast: true,
              children: const <Widget>[
                NeedsAttentionList(),
                OldestUnresolvedList(),
                AwaitingTriageList(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The date-range control: "Created in" 7 d / 30 d / 90 d / All (default All).
/// The choice lives in `dashboardRangeProvider`, so the cards, charts and
/// lists all recompute and the card and bar presets carry it to A-03.
class _RangeControl extends ConsumerWidget {
  const _RangeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatedRange range = ref.watch(dashboardRangeProvider);
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          'Created in',
          style: theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSegmented<CreatedRange>(
          semanticLabel: 'Date range',
          selected: range,
          onChanged: ref.read(dashboardRangeProvider.notifier).select,
          segments: <AppSegment<CreatedRange>>[
            for (final CreatedRange r in CreatedRange.values)
              AppSegment<CreatedRange>(value: r, label: r.label),
          ],
        ),
      ],
    );
  }
}
