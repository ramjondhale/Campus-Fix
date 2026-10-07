import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../../shell/admin_page.dart';
import 'complaint_filter_bar.dart';

/// A-03 Complaint List + Filters (admins and verifiers, identical content).
///
/// The master list of every complaint: a filter bar above the design system's
/// [ComplaintTable], sortable by any column, 25 or 50 rows per page. It is
/// built from `PublicComplaintView`s only (`complaintListProvider`, live), so
/// it has no reporter, assignee or actor data and the table has no identity
/// column (AC-48).
///
/// **The address is the state.** [queryParameters] (the query of the URL) hold
/// the filter, the sort and the page; every change navigates to the new
/// address, so the list is shareable and bookmarkable, Back and Forward move
/// through it, and a dashboard preset (`?unresolved=1&priority=critical,high`)
/// lands on exactly the set it counted (AC-47). A row opens the complaint
/// (A-04) on top of the list, so Back returns to the same filters and page.
class ComplaintListScreen extends ConsumerStatefulWidget {
  const ComplaintListScreen({
    super.key,
    this.queryParameters = const <String, String>{},
  });

  /// The query parameters of the address (filter values and view state only;
  /// the route never carries anything else, privacy PV-5).
  final Map<String, String> queryParameters;

  @override
  ConsumerState<ComplaintListScreen> createState() =>
      _ComplaintListScreenState();
}

class _ComplaintListScreenState extends ConsumerState<ComplaintListScreen> {
  /// The complaint last opened from this list: its row stays highlighted when
  /// the user comes back.
  String? _selectedId;

  ComplaintListQuery get _query =>
      ComplaintListQuery.fromQuery(widget.queryParameters);

  /// Shows [next] by navigating to its address (a no-op when it is already
  /// the address shown).
  void _show(ComplaintListQuery next) {
    if (next.path == _query.path) return;
    context.go(next.path);
  }

  void _open(PublicComplaintView complaint) {
    setState(() => _selectedId = complaint.id);
    context.push(AppRoutes.complaint(complaint.id));
  }

  @override
  Widget build(BuildContext context) {
    final ComplaintListQuery query = _query;
    final AsyncValue<ComplaintListPage> list = ref.watch(
      complaintListProvider(query),
    );
    final List<String> buildings = ref.watch(complaintBuildingsProvider);
    void reset() => _show(query.reset());

    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ComplaintFilterBar(
            filter: query.filter,
            buildings: buildings,
            onChanged: (ComplaintFilter f) => _show(query.withFilter(f)),
            onReset: reset,
          ),
          const SizedBox(height: AppSpace.s4),
          list.when(
            loading: () => ComplaintTable(
              complaints: const <PublicComplaintView>[],
              loading: true,
              sortColumn: query.sortColumn,
              sortAscending: query.sortAscending,
            ),
            error: (Object _, StackTrace _) => EmptyState.error(
              alignment: CrossAxisAlignment.start,
              onAction: () => refreshComplaints(ref),
            ),
            data: (ComplaintListPage page) => ComplaintTable(
              complaints: page.rows,
              selectedId: _selectedId,
              sortColumn: query.sortColumn,
              sortAscending: query.sortAscending,
              onSort: (ComplaintTableColumn c) => _show(query.sortedBy(c)),
              onRowTap: _open,
              page: page.page,
              rowsPerPage: page.rowsPerPage,
              totalCount: page.totalCount,
              onPageChanged: (int p) => _show(query.copyWith(page: p)),
              onRowsPerPageChanged: (int n) =>
                  _show(query.copyWith(rowsPerPage: n, page: 0)),
              now: page.now,
              emptyState: page.isEmpty
                  ? const EmptyState.nothing(
                      title: 'No complaints yet',
                      message:
                          'Complaints show up here as soon as they are reported.',
                      alignment: CrossAxisAlignment.start,
                    )
                  : EmptyState.filtered(
                      title: 'No complaints match',
                      actionLabel: 'Reset filters',
                      onAction: reset,
                      alignment: CrossAxisAlignment.start,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
