import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../complaint_details/complaint_details_view.dart';
import '../report/report_problem_fab.dart';
import '../shared/list_states.dart';
import 'board_filter_sheets.dart';
import 'board_query.dart';

/// How many complaints the board lists at first and adds each time the end of
/// the list is reached (screens-spec M-11: infinite scroll, page size 20).
const int boardPageSize = 20;

/// M-11 Campus Problem Board: an anonymous, campus-wide view of complaints so
/// people can spot existing issues and avoid duplicates (R6). A bottom-nav tab
/// for every mobile role. Consumes `boardComplaintsProvider` (public views)
/// only; each card shows the board's public field set and nothing that
/// identifies who reported it.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  final TextEditingController _search = TextEditingController();
  BoardFilters _filters = const BoardFilters();
  int _visible = boardPageSize;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(BoardFilters next) => setState(() {
    _filters = next;
    _visible = boardPageSize;
  });

  void _clear() {
    _search.clear();
    _update(BoardFilters(sort: _filters.sort));
  }

  void _showMore(int total) {
    // Called while building the end-of-list loader; grow on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _visible >= total) return;
      setState(() => _visible += boardPageSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PublicComplaintView>> board = ref.watch(
      boardComplaintsProvider,
    );
    return Scaffold(
      appBar: const AppTopBar.page(title: 'Campus Board'),
      floatingActionButton: const ReportProblemFab(),
      body: board.when(
        loading: () => const ComplaintListSkeleton(),
        error: (_, _) => RefreshFill(
          onRefresh: () => refreshComplaints(ref),
          child: EmptyState.error(
            title: "Couldn't load the campus board",
            onAction: () => refreshComplaints(ref),
          ),
        ),
        data: _buildData,
      ),
    );
  }

  Widget _buildData(List<PublicComplaintView> all) {
    final List<PublicComplaintView> shown = _filters.apply(all);
    final bool noneOpen =
        !_filters.hasActive &&
        all.every(
          (PublicComplaintView c) => c.status == ComplaintStatus.closed,
        );
    final int count = shown.length < _visible ? shown.length : _visible;
    final bool hasMore = shown.length > _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            0,
          ),
          child: AppSearchField(
            controller: _search,
            onChanged: (String q) => _update(_filters.copyWith(query: q)),
          ),
        ),
        FilterBar(
          layout: FilterBarLayout.scroll,
          hasActiveFilters: _filters.hasActive,
          onClear: _clear,
          chips: _chips(all),
        ),
        const _IdentityHiddenNote(),
        Expanded(
          child: noneOpen
              ? RefreshFill(
                  onRefresh: () => refreshComplaints(ref),
                  child: const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No open complaints on campus',
                    message: 'New problems will show up here.',
                  ),
                )
              : shown.isEmpty
              ? RefreshFill(
                  onRefresh: () => refreshComplaints(ref),
                  child: EmptyState.filtered(
                    actionLabel: 'Clear filters',
                    onAction: _clear,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              shown.length == 1
                                  ? '1 complaint'
                                  : '${shown.length} complaints',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          // The filter row scrolls sideways; keep a way to
                          // reset in view.
                          if (_filters.hasActive)
                            AppButton(
                              label: 'Clear filters',
                              size: AppButtonSize.sm,
                              variant: AppButtonVariant.tertiary,
                              onPressed: _clear,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => refreshComplaints(ref),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.s4,
                            AppSpace.s2,
                            AppSpace.s4,
                            // Clears the floating "Report a Problem" button.
                            96,
                          ),
                          itemCount: count + (hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpace.s3),
                          itemBuilder: (BuildContext context, int i) {
                            if (i >= count) {
                              _showMore(shown.length);
                              return const Padding(
                                padding: EdgeInsets.all(AppSpace.s4),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final PublicComplaintView c = shown[i];
                            return ComplaintCard(
                              complaint: c,
                              onTap: () =>
                                  context.push(AppRoutes.boardItem(c.id)),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _chips(List<PublicComplaintView> all) {
    final List<String> buildings = <String>{
      for (final PublicComplaintView c in all) c.building,
    }.toList()..sort();
    return <Widget>[
      AppFilterChip(
        label: 'Category',
        selected: _filters.categories.isNotEmpty,
        count: _filters.categories.length,
        onTap: () => showMultiSelectSheet<ProblemCategory>(
          context,
          title: 'Category',
          options: <FilterOption<ProblemCategory>>[
            for (final ProblemCategory v in ProblemCategory.values)
              FilterOption<ProblemCategory>(v, v.label),
          ],
          selected: _filters.categories,
          onChanged: (Set<ProblemCategory> v) =>
              _update(_filters.copyWith(categories: v)),
        ),
      ),
      AppFilterChip(
        label: 'Priority',
        selected: _filters.priorities.isNotEmpty,
        count: _filters.priorities.length,
        onTap: () => showMultiSelectSheet<Priority>(
          context,
          title: 'Priority',
          options: <FilterOption<Priority>>[
            for (final Priority v in Priority.values)
              FilterOption<Priority>(v, v.label),
          ],
          selected: _filters.priorities,
          onChanged: (Set<Priority> v) =>
              _update(_filters.copyWith(priorities: v)),
        ),
      ),
      AppFilterChip(
        label: 'Status',
        selected: _filters.statuses.isNotEmpty,
        count: _filters.statuses.length,
        onTap: () => showMultiSelectSheet<ComplaintStatus>(
          context,
          title: 'Status',
          options: <FilterOption<ComplaintStatus>>[
            for (final ComplaintStatus v in ComplaintStatus.values)
              FilterOption<ComplaintStatus>(v, v.label),
          ],
          selected: _filters.statuses,
          onChanged: (Set<ComplaintStatus> v) =>
              _update(_filters.copyWith(statuses: v)),
        ),
      ),
      AppFilterChip(
        label: _filters.building ?? 'Building',
        selected: _filters.building != null,
        onTap: () async {
          const String any = '';
          final String? picked = await showSingleSelectSheet<String>(
            context,
            title: 'Building',
            options: <FilterOption<String>>[
              const FilterOption<String>(any, 'Any building'),
              for (final String b in buildings) FilterOption<String>(b, b),
            ],
            selected: _filters.building ?? any,
          );
          if (picked == null) return;
          _update(
            picked == any
                ? _filters.copyWith(clearBuilding: true)
                : _filters.copyWith(building: picked),
          );
        },
      ),
      AppFilterChip(
        label: 'Include closed',
        kind: AppFilterChipKind.toggle,
        selected: _filters.includeClosed,
        onTap: () =>
            _update(_filters.copyWith(includeClosed: !_filters.includeClosed)),
      ),
      AppFilterChip(
        label: 'Sort: ${_filters.sort.label}',
        selected: false,
        onTap: () async {
          final BoardSort? picked = await showSingleSelectSheet<BoardSort>(
            context,
            title: 'Sort by',
            options: <FilterOption<BoardSort>>[
              for (final BoardSort v in BoardSort.values)
                FilterOption<BoardSort>(v, v.label),
            ],
            selected: _filters.sort,
          );
          if (picked != null) _update(_filters.copyWith(sort: picked));
        },
      ),
    ];
  }
}

/// A short reminder that the board is anonymous (R6).
class _IdentityHiddenNote extends StatelessWidget {
  const _IdentityHiddenNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.visibility_off_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Text(
              'Identity is hidden: the board never shows who reported a '
              'problem. Check here before reporting to avoid duplicates.',
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// M-11b Board Item Detail: one board complaint limited to the board's
/// public field set, with no tracking history. [complaintId] comes from the
/// route (`/board/:id`).
class BoardItemDetailScreen extends ConsumerWidget {
  const BoardItemDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ComplaintDetailsPage(
      title: 'Board item',
      value: ref.watch(complaintViewProvider(complaintId)),
      mode: ComplaintDetailsMode.board,
      onRetry: () => refreshComplaints(ref),
    );
  }
}
