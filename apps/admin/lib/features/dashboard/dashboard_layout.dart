import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// Equal-width columns of [children] with [gap] between them, each row as tall
/// as its tallest member (the dashboard's card and panel grids, design
/// contract 8.26).
///
/// A last row that is short is padded with empty cells so every cell keeps the
/// same width, unless [spanLast] is set: then a lone last child spans the
/// whole row.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    super.key,
    required this.columns,
    required this.gap,
    required this.children,
    this.spanLast = false,
  });

  /// Cells per row (1 stacks the children).
  final int columns;

  /// Gap between cells, horizontally and vertically.
  final double gap;

  final List<Widget> children;

  /// Lets a lone last child take the whole row.
  final bool spanLast;

  @override
  Widget build(BuildContext context) {
    final int perRow = columns < 1 ? 1 : columns;
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < children.length; start += perRow) {
      final List<Widget> cells = children.sublist(
        start,
        start + perRow > children.length ? children.length : start + perRow,
      );
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      if (perRow == 1 || (cells.length == 1 && spanLast)) {
        rows.add(cells.single);
        continue;
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < perRow; i++) ...<Widget>[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: i < cells.length ? cells[i] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// A titled surface of the dashboard: a chart or a list (container `card`,
/// 1 px `outlineVariant`, radius `r4`).
///
/// The header carries the [title], an optional one-line [subtitle] and an
/// optional "View all" style action. The body is the [child]; with
/// [bleed] it runs edge to edge (list rows draw their own dividers).
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.bleed = false,
  });

  final String title;
  final String? subtitle;

  /// Label of the header action; shown only with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  /// Whether the body ignores the panel's horizontal padding.
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final CampusColors colors = context.campusColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.br4,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(title, style: theme.textTheme.titleMedium),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(width: AppSpace.s2),
                  AppButton(
                    label: actionLabel!,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.tertiary,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
          if (bleed)
            child
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}
