import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import '../../providers/providers.dart';

/// The 14-day intake chart of A-02: one vertical bar per calendar day, oldest
/// on the left, each with its count printed on top and its day of the month
/// below (design contract 2.8: every mark has a direct text label and a
/// value; the encoding is never colour alone).
///
/// The design system has no ready widget for a time series, so this is a small
/// token-driven one: bars in the brand `primary` role (intake is not a status,
/// priority or category, so no semantic set applies and none is mixed in) on a
/// `cardSubtle` baseline, sizes from `AppSpace`, corners from `AppRadius`, text
/// from the theme.
class IntakeChart extends StatelessWidget {
  const IntakeChart({super.key, required this.days});

  /// The days to draw, oldest first.
  final List<IntakeDay> days;

  /// Height of the tallest bar.
  static const double _barMax = AppSpace.s16;

  /// Height of the plot: the tallest bar plus room for its count.
  static const double _plotHeight = AppSpace.s16 + AppSpace.s6;

  /// Gap between neighbouring bars (half of this on each side of a bar).
  static const double _barGap = AppSpace.s1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final CampusColors colors = context.campusColors;
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final int max = days.fold<int>(
      0,
      (int a, IntakeDay d) => d.count > a ? d.count : a,
    );
    final int total = days.fold<int>(0, (int a, IntakeDay d) => a + d.count);
    final TextStyle count = AppTypography.tabular(
      theme.textTheme.labelSmall!.copyWith(color: scheme.onSurface),
    );
    final TextStyle day = AppTypography.tabular(
      theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
    );

    Widget column(IntakeDay d) {
      final double fraction = max == 0 ? 0 : d.count / max;
      return Expanded(
        child: Semantics(
          label:
              '${l10n.formatShortMonthDay(d.day)}: ${d.count} new '
              '${d.count == 1 ? 'complaint' : 'complaints'}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _barGap / 2),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: _plotHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text('${d.count}', style: count),
                      const SizedBox(height: AppSpace.s1),
                      if (d.count > 0)
                        SizedBox(
                          height: _barMax * fraction,
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: AppRadius.br2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // The baseline every bar stands on.
                Container(
                  height: AppSpace.s1,
                  decoration: BoxDecoration(
                    color: colors.cardSubtle,
                    borderRadius: AppRadius.br2,
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text('${d.day.day}', style: day),
              ],
            ),
          ),
        ),
      );
    }

    final String span = days.isEmpty
        ? ''
        : '${l10n.formatShortMonthDay(days.first.day)} to '
              '${l10n.formatShortMonthDay(days.last.day)}';
    return Semantics(
      container: true,
      label: 'Intake per day, $span: $total new complaints',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[for (final IntakeDay d in days) column(d)],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            span,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
