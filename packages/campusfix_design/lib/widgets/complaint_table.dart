import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'app_segmented.dart';
import 'app_tag_size.dart';
import 'category_chip.dart';
import 'complaint_id_text.dart';
import 'empty_state.dart';
import 'priority_tag.dart';
import 'skeleton.dart';
import 'status_badge.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';
import 'support/time_format.dart';

/// The columns of a [ComplaintTable], in display order (contract 8.11).
///
/// There is deliberately **no reporter column**, and no reporter-based sort
/// (PV-5).
enum ComplaintTableColumn {
  /// Complaint ID (`mono-md`).
  id('ID', 14),

  /// Category chip and label.
  category('Category', 20),

  /// "Building · Floor · Room", wrapping to two lines.
  location('Location', 22),

  /// Effective priority tag.
  priority('Priority', 11),

  /// Status badge.
  status('Status', 14),

  /// Department label or "Unassigned".
  department('Department', 15),

  /// Waiting time since creation (unresolved only).
  waiting('Waiting', 9),

  /// Last update time.
  updated('Updated', 15);

  const ComplaintTableColumn(this.title, this.flex);

  /// Header label.
  final String title;

  /// Relative column width.
  final int flex;
}

/// The admin complaint table (contract 8.11, screen A-03).
///
/// Public fields only: every row is a [PublicComplaintView]. Header 40 high
/// (`cardSubtle`, `overline` labels, sort indicator in the active column),
/// rows 52 high (44 [dense]) with a bottom border, tabular figures, hover
/// overlay 4%, [selectedId] on `pressedFill`, focus ring on each row. The
/// footer shows the range and rows per page (25 / 50). While [loading] it
/// shows skeleton rows; with no complaints it shows [emptyState] (left
/// aligned).
class ComplaintTable extends StatelessWidget {
  /// Creates a table.
  const ComplaintTable({
    super.key,
    required this.complaints,
    this.onRowTap,
    this.selectedId,
    this.dense = false,
    this.loading = false,
    this.sortColumn,
    this.sortAscending = true,
    this.onSort,
    this.emptyState,
    this.onClearFilters,
    this.page = 0,
    this.rowsPerPage = 25,
    this.totalCount,
    this.onPageChanged,
    this.onRowsPerPageChanged,
    this.now,
  });

  /// The rows of the current page.
  final List<PublicComplaintView> complaints;

  /// Called when a row is tapped (opens the complaint detail).
  final ValueChanged<PublicComplaintView>? onRowTap;

  /// The selected row's complaint id.
  final String? selectedId;

  /// Dense rows (44 instead of 52).
  final bool dense;

  /// Shows skeleton rows.
  final bool loading;

  /// The column the table is sorted by.
  final ComplaintTableColumn? sortColumn;

  /// Sort direction of [sortColumn].
  final bool sortAscending;

  /// Called when a header is tapped.
  final ValueChanged<ComplaintTableColumn>? onSort;

  /// Shown instead of the rows when [complaints] is empty (defaults to a
  /// left-aligned "No matching complaints").
  final Widget? emptyState;

  /// Adds a "Clear filters" action to the default empty state.
  final VoidCallback? onClearFilters;

  /// Zero-based page index.
  final int page;

  /// Rows per page (25 or 50).
  final int rowsPerPage;

  /// Total number of complaints across pages; shows the footer when set.
  final int? totalCount;

  /// Called with the new zero-based page.
  final ValueChanged<int>? onPageChanged;

  /// Called with 25 or 50.
  final ValueChanged<int>? onRowsPerPageChanged;

  /// Reference time for the Waiting and Updated columns.
  final DateTime? now;

  static const double _minWidth = 1100;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final DateTime reference = now ?? DateTime.now();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.br4,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.br4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth < _minWidth
                    ? _minWidth
                    : constraints.maxWidth;
                final Widget table = SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _HeaderRow(
                        sortColumn: sortColumn,
                        sortAscending: sortAscending,
                        onSort: onSort,
                      ),
                      if (loading)
                        for (int i = 0; i < 5; i++) _SkeletonRow(dense: dense)
                      else if (complaints.isEmpty)
                        const SizedBox.shrink()
                      else
                        for (final PublicComplaintView c in complaints)
                          _DataRow(
                            complaint: c,
                            dense: dense,
                            selected: c.id == selectedId,
                            now: reference,
                            onTap: onRowTap == null ? null : () => onRowTap!(c),
                          ),
                    ],
                  ),
                );
                final Widget scroller = constraints.maxWidth < _minWidth
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: table,
                      )
                    : table;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    scroller,
                    if (!loading && complaints.isEmpty)
                      emptyState ??
                          EmptyState.filtered(
                            alignment: CrossAxisAlignment.start,
                            onAction: onClearFilters,
                          ),
                  ],
                );
              },
            ),
            if (totalCount != null)
              _Footer(
                page: page,
                rowsPerPage: rowsPerPage,
                shown: complaints.length,
                total: totalCount!,
                onPageChanged: onPageChanged,
                onRowsPerPageChanged: onRowsPerPageChanged,
              ),
          ],
        ),
      ),
    );
  }
}

const EdgeInsets _cellPadding = EdgeInsets.symmetric(horizontal: 10);

Widget _cell(ComplaintTableColumn column, Widget child) => Expanded(
  flex: column.flex,
  child: Padding(
    padding: _cellPadding,
    child: Align(alignment: Alignment.centerLeft, child: child),
  ),
);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  final ComplaintTableColumn? sortColumn;
  final bool sortAscending;
  final ValueChanged<ComplaintTableColumn>? onSort;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Container(
      height: 40,
      color: colors.cardSubtle,
      child: Row(
        children: <Widget>[
          for (final ComplaintTableColumn column in ComplaintTableColumn.values)
            Expanded(
              flex: column.flex,
              child: _HeaderCell(
                column: column,
                active: column == sortColumn,
                ascending: sortAscending,
                onTap: onSort == null ? null : () => onSort!(column),
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.active,
    required this.ascending,
    required this.onTap,
    required this.color,
  });

  final ComplaintTableColumn column;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget label = Padding(
      padding: _cellPadding,
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              column.title.toUpperCase(),
              style: AppTypography.overline.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (active) ...<Widget>[
            const SizedBox(width: AppSpace.s1),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: color,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return label;
    return AppPressable(
      onTap: onTap,
      radius: BorderRadius.zero,
      isButton: true,
      semanticLabel:
          '${column.title}${active ? (ascending ? ', sorted ascending' : ', sorted descending') : ''}',
      builder: (BuildContext context, Set<WidgetState> states) => Container(
        height: 40,
        color: applyStateLayer(Colors.transparent, color, states),
        alignment: Alignment.centerLeft,
        child: label,
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.complaint,
    required this.dense,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  final PublicComplaintView complaint;
  final bool dense;
  final bool selected;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final TextTheme text = context.textTheme;
    final bool unresolved =
        complaint.status.order < ComplaintStatus.resolved.order;
    final TextStyle body = AppTypography.tabular(text.bodyMedium!);

    Widget row(Set<WidgetState> states) {
      return Container(
        constraints: BoxConstraints(minHeight: dense ? 44 : 52),
        decoration: BoxDecoration(
          color: applyStateLayer(
            selected ? colors.pressedFill : colors.card,
            scheme.onSurface,
            states,
            hover: 0.04,
          ),
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: <Widget>[
            _cell(
              ComplaintTableColumn.id,
              ComplaintIdText(
                id: complaint.id,
                size: ComplaintIdSize.md,
                copyable: false,
              ),
            ),
            _cell(
              ComplaintTableColumn.category,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CategoryChip(
                    category: complaint.category,
                    size: CategoryChipSize.s24,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Flexible(
                    child: Text(
                      complaint.category.label,
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _cell(
              ComplaintTableColumn.location,
              Text(
                '${complaint.building} · ${complaint.floor} · ${complaint.room}',
                style: text.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _cell(
              ComplaintTableColumn.priority,
              PriorityTag(
                priority: complaint.effectivePriority,
                size: AppTagSize.sm,
              ),
            ),
            _cell(
              ComplaintTableColumn.status,
              StatusBadge(status: complaint.status, size: AppTagSize.sm),
            ),
            _cell(
              ComplaintTableColumn.department,
              Text(
                complaint.assignedDepartment?.label ?? 'Unassigned',
                style: complaint.assignedDepartment == null
                    ? text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)
                    : text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _cell(
              ComplaintTableColumn.waiting,
              Text(
                unresolved
                    ? formatWaiting(now.difference(complaint.createdAt))
                    : '-',
                style: body,
              ),
            ),
            _cell(
              ComplaintTableColumn.updated,
              Text(
                formatRelativeTime(complaint.updatedAt, now: now),
                style: body,
              ),
            ),
          ],
        ),
      );
    }

    final String label =
        '${complaint.id}, ${complaint.category.label}, '
        '${complaint.effectivePriority.label} priority, '
        '${complaint.status.label}';
    if (onTap == null) {
      return Semantics(
        container: true,
        label: label,
        child: row(<WidgetState>{}),
      );
    }
    return AppPressable(
      onTap: onTap,
      radius: BorderRadius.zero,
      selected: selected,
      semanticLabel: label,
      builder: (BuildContext context, Set<WidgetState> states) => row(states),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.dense});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Skeleton(
      child: Container(
        height: dense ? 44 : 52,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: <Widget>[
            for (final ComplaintTableColumn column
                in ComplaintTableColumn.values)
              _cell(
                column,
                const SkeletonBlock.fraction(widthFactor: 0.7, height: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.rowsPerPage,
    required this.shown,
    required this.total,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  final int page;
  final int rowsPerPage;

  /// Rows on the current page (the last page can hold fewer than
  /// [rowsPerPage]).
  final int shown;
  final int total;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onRowsPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final int first = total == 0 ? 0 : page * rowsPerPage + 1;
    final int last = shown > 0
        ? (first + shown - 1).clamp(0, total)
        : ((page + 1) * rowsPerPage).clamp(0, total);
    final bool hasPrev = page > 0;
    final bool hasNext = last < total;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpace.s4,
        runSpacing: AppSpace.s2,
        children: <Widget>[
          Text(
            '$first-$last of $total',
            style: AppTypography.tabular(
              context.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: <Widget>[
              Text(
                'Rows per page',
                style: context.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              AppSegmented<int>(
                dense: true,
                semanticLabel: 'Rows per page',
                segments: const <AppSegment<int>>[
                  AppSegment<int>(value: 25, label: '25'),
                  AppSegment<int>(value: 50, label: '50'),
                ],
                selected: rowsPerPage,
                onChanged: onRowsPerPageChanged,
              ),
              AppButton(
                label: 'Previous',
                size: AppButtonSize.sm,
                variant: AppButtonVariant.tertiary,
                leadingIcon: Icons.chevron_left,
                onPressed: hasPrev && onPageChanged != null
                    ? () => onPageChanged!(page - 1)
                    : null,
              ),
              AppButton(
                label: 'Next',
                size: AppButtonSize.sm,
                variant: AppButtonVariant.tertiary,
                onPressed: hasNext && onPageChanged != null
                    ? () => onPageChanged!(page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
