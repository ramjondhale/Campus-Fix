import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import '../../providers/providers.dart';
import 'filter_menu_chip.dart';

/// How long the search field waits after the last keystroke before the list
/// is filtered (and the address updated).
const Duration kSearchDebounce = Duration(milliseconds: 300);

/// The filter bar of the complaint list (A-03): the search field, one chip per
/// filter and "Reset filters", composed on the design system's [FilterBar].
///
/// It owns no filter state. [filter] comes from the address and every change
/// goes out through [onChanged] as a new [ComplaintFilter], so the list, the
/// chips and the URL cannot disagree. The only local state is the text being
/// typed, which is applied after [kSearchDebounce] or on Enter.
///
/// Filters: Status, Priority, Category and Department (multi-select, the last
/// with "Unassigned"), Building, the Created range, and the two toggles
/// "Unresolved only" and "Needs manual triage". There is no filter by
/// reporter (privacy-spec PV-5).
class ComplaintFilterBar extends StatefulWidget {
  const ComplaintFilterBar({
    super.key,
    required this.filter,
    required this.buildings,
    required this.onChanged,
    required this.onReset,
  });

  /// The filter currently applied.
  final ComplaintFilter filter;

  /// The buildings the Building filter offers.
  final List<String> buildings;

  /// Called with the new filter on every change.
  final ValueChanged<ComplaintFilter> onChanged;

  /// Called by "Reset filters".
  final VoidCallback onReset;

  @override
  State<ComplaintFilterBar> createState() => _ComplaintFilterBarState();
}

class _ComplaintFilterBarState extends State<ComplaintFilterBar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.search ?? '',
  );
  Timer? _debounce;

  @override
  void didUpdateWidget(ComplaintFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The address changed (Reset, Back, a link): show its search text, unless
    // the user is in the middle of typing.
    final String? search = widget.filter.search;
    if (search != oldWidget.filter.search &&
        !(_debounce?.isActive ?? false) &&
        _search.text.trim() != (search ?? '')) {
      _search.value = TextEditingValue(
        text: search ?? '',
        selection: TextSelection.collapsed(offset: (search ?? '').length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(kSearchDebounce, () => _applySearch(text));
  }

  void _submitted(String text) {
    _debounce?.cancel();
    _applySearch(text);
  }

  /// Reset filters: drops the text being typed along with the applied filters,
  /// so a keystroke still waiting for the debounce cannot bring it back.
  void _reset() {
    _debounce?.cancel();
    _search.clear();
    widget.onReset();
  }

  void _applySearch(String text) {
    if (!mounted) return;
    final String trimmed = text.trim();
    if (trimmed == (widget.filter.search ?? '')) return;
    widget.onChanged(
      widget.filter.copyWith(search: trimmed, clearSearch: trimmed.isEmpty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ComplaintFilter filter = widget.filter;
    return FilterBar(
      layout: FilterBarLayout.wrap,
      hasActiveFilters: filter.hasAnyFilter,
      onClear: _reset,
      search: AppSearchField(
        controller: _search,
        onChanged: _typed,
        onSubmitted: _submitted,
      ),
      chips: <Widget>[
        MultiSelectFilterChip<ComplaintStatus>(
          label: 'Status',
          options: <FilterOption<ComplaintStatus>>[
            for (final ComplaintStatus s in ComplaintStatus.values)
              FilterOption<ComplaintStatus>(value: s, label: s.label),
          ],
          selected: filter.statuses,
          onChanged: (Set<ComplaintStatus> v) =>
              widget.onChanged(filter.copyWith(statuses: v)),
        ),
        MultiSelectFilterChip<Priority>(
          label: 'Priority',
          options: <FilterOption<Priority>>[
            for (final Priority p in Priority.values)
              FilterOption<Priority>(value: p, label: p.label),
          ],
          selected: filter.priorities,
          onChanged: (Set<Priority> v) =>
              widget.onChanged(filter.copyWith(priorities: v)),
        ),
        MultiSelectFilterChip<ProblemCategory>(
          label: 'Category',
          options: <FilterOption<ProblemCategory>>[
            for (final ProblemCategory c in ProblemCategory.values)
              FilterOption<ProblemCategory>(value: c, label: c.label),
          ],
          selected: filter.categories,
          onChanged: (Set<ProblemCategory> v) =>
              widget.onChanged(filter.copyWith(categories: v)),
        ),
        _DepartmentChip(filter: filter, onChanged: widget.onChanged),
        SingleSelectFilterChip<String>(
          label: 'Building',
          anyLabel: 'Any building',
          options: <FilterOption<String>>[
            for (final String b in widget.buildings)
              FilterOption<String>(value: b, label: b),
          ],
          selected: _selectedBuilding(),
          onChanged: (String? b) => widget.onChanged(
            b == null
                ? filter.copyWith(clearBuilding: true)
                : filter.copyWith(building: b),
          ),
        ),
        _CreatedRangeControl(
          selected: filter.created,
          onChanged: (CreatedRange r) =>
              widget.onChanged(filter.copyWith(created: r)),
        ),
        AppFilterChip(
          label: 'Unresolved only',
          kind: AppFilterChipKind.toggle,
          selected: filter.unresolvedOnly,
          onTap: () => widget.onChanged(
            filter.copyWith(unresolvedOnly: !filter.unresolvedOnly),
          ),
        ),
        AppFilterChip(
          label: 'Needs manual triage',
          kind: AppFilterChipKind.toggle,
          selected: filter.needsTriage,
          onTap: () => widget.onChanged(
            filter.copyWith(needsTriage: !filter.needsTriage),
          ),
        ),
      ],
    );
  }

  /// The filtered building as one of the offered names (so a URL that spells
  /// it in another case still shows its entry as chosen).
  String? _selectedBuilding() {
    final String? wanted = widget.filter.building;
    if (wanted == null) return null;
    for (final String b in widget.buildings) {
      if (b.toLowerCase() == wanted.toLowerCase()) return b;
    }
    return wanted;
  }
}

/// The Department chip: the departments plus "Unassigned", which stands for
/// the complaints with no department.
class _DepartmentChip extends StatelessWidget {
  const _DepartmentChip({required this.filter, required this.onChanged});

  final ComplaintFilter filter;
  final ValueChanged<ComplaintFilter> onChanged;

  /// The "Unassigned" entry; it is not a [Department], so the menu works on
  /// `Department?` with `null` standing for it.
  static const Department? _unassigned = null;

  @override
  Widget build(BuildContext context) {
    return MultiSelectFilterChip<Department?>(
      label: 'Department',
      options: <FilterOption<Department?>>[
        for (final Department d in Department.values)
          FilterOption<Department?>(value: d, label: d.label),
        const FilterOption<Department?>(
          value: _unassigned,
          label: 'Unassigned',
        ),
      ],
      selected: <Department?>{
        ...filter.departments,
        if (filter.includeUnassigned) _unassigned,
      },
      onChanged: (Set<Department?> v) => onChanged(
        filter.copyWith(
          departments: <Department>{for (final Department? d in v) ?d},
          includeUnassigned: v.contains(_unassigned),
        ),
      ),
    );
  }
}

/// "Created in" 7 d / 30 d / 90 d / All, the same control as the dashboard's.
class _CreatedRangeControl extends StatelessWidget {
  const _CreatedRangeControl({required this.selected, required this.onChanged});

  final CreatedRange selected;
  final ValueChanged<CreatedRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Created in',
          style: theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        AppSegmented<CreatedRange>(
          dense: true,
          semanticLabel: 'Created in',
          selected: selected,
          onChanged: onChanged,
          segments: <AppSegment<CreatedRange>>[
            for (final CreatedRange r in CreatedRange.values)
              AppSegment<CreatedRange>(value: r, label: r.label),
          ],
        ),
      ],
    );
  }
}
