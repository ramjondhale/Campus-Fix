// What the complaint list (A-03) shows: the filter, the sort and the page,
// held as one value that round-trips through the URL, and the pure functions
// and providers that turn the public views into the rows of one page.
//
// Typed on `PublicComplaintView` only (privacy-spec section 5.1): there is no
// column, sort or key for a reporter, an assignee or an actor (PV-5).
//
// **The URL is the state.** The screen reads `ComplaintListQuery.fromQuery`
// from the address and navigates to `ComplaintListQuery.path` on every change,
// so a filtered, sorted, paged list is shareable and bookmarkable and the
// browser's Back and Forward move through it. Besides the nine filter keys of
// `complaint_query.dart` it carries four view-state keys, written only when
// they differ from the default:
//
// | key    | value                                                        |
// |--------|--------------------------------------------------------------|
// | `sort` | a `ComplaintTableColumn.name` (`waiting`, `updated`, ...)    |
// | `dir`  | `asc` or `desc`                                              |
// | `page` | the page, counted from 1                                     |
// | `size` | rows per page, `25` or `50`                                  |

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart'
    show ComplaintTableColumn;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaint_filter.dart';
import 'complaints.dart';
import 'dashboard.dart' show dashboardClockProvider, isUnresolvedStatus;

/// Query key: the sort column (a [ComplaintTableColumn] name).
const String kQuerySort = 'sort';

/// Query key: the sort direction ([kQueryDirAscending] or
/// [kQueryDirDescending]).
const String kQuerySortDir = 'dir';

/// Query key: the page, counted from 1.
const String kQueryPage = 'page';

/// Query key: the rows per page.
const String kQueryPageSize = 'size';

/// The `dir` value of an ascending sort.
const String kQueryDirAscending = 'asc';

/// The `dir` value of a descending sort.
const String kQueryDirDescending = 'desc';

/// The rows-per-page choices of the table footer (screens-spec A-03).
const List<int> kRowsPerPageOptions = <int>[25, 50];

/// The default rows per page.
const int kDefaultRowsPerPage = 25;

/// The default sort column: priority.
const ComplaintTableColumn kDefaultSortColumn = ComplaintTableColumn.priority;

/// The default sort direction: heaviest priority first.
const bool kDefaultSortAscending = false;

/// A complete description of one view of the list: what is filtered, how it
/// is sorted and which page is shown.
///
/// The default is the order of AC-50: effective priority from the heaviest
/// down, then the longest waiting first.
@immutable
class ComplaintListQuery {
  /// Creates a query; every part has a default.
  const ComplaintListQuery({
    this.filter = const ComplaintFilter(),
    this.sortColumn = kDefaultSortColumn,
    this.sortAscending = kDefaultSortAscending,
    this.page = 0,
    this.rowsPerPage = kDefaultRowsPerPage,
  });

  /// Reads a view from the `queryParameters` of an A-03 URL. Tolerant: an
  /// unknown sort column, direction, page or size falls back to the default.
  factory ComplaintListQuery.fromQuery(Map<String, String> query) {
    final ComplaintTableColumn? column = _columnNamed(query[kQuerySort]);
    final String? dir = query[kQuerySortDir];
    final int? page = int.tryParse(query[kQueryPage] ?? '');
    final int? size = int.tryParse(query[kQueryPageSize] ?? '');
    return ComplaintListQuery(
      filter: ComplaintFilter.fromQuery(query),
      sortColumn: column ?? kDefaultSortColumn,
      sortAscending: switch (dir) {
        kQueryDirAscending => true,
        kQueryDirDescending => false,
        _ => column == null ? kDefaultSortAscending : true,
      },
      page: page == null || page < 1 ? 0 : page - 1,
      rowsPerPage: kRowsPerPageOptions.contains(size)
          ? size!
          : kDefaultRowsPerPage,
    );
  }

  /// What the list is filtered by.
  final ComplaintFilter filter;

  /// The column the list is sorted by.
  final ComplaintTableColumn sortColumn;

  /// Whether [sortColumn] is sorted ascending.
  final bool sortAscending;

  /// The zero-based page index (clamped to the last page when it is shown).
  final int page;

  /// Rows per page: 25 or 50.
  final int rowsPerPage;

  /// Whether the sort is the default one (priority, heaviest first).
  bool get isDefaultSort =>
      sortColumn == kDefaultSortColumn &&
      sortAscending == kDefaultSortAscending;

  /// The A-03 path of this view: the filter's query, then `sort`/`dir`, `page`
  /// and `size` when they are not the defaults. The bare `/complaints` for
  /// the default view.
  String get path {
    final List<String> extra = <String>[
      if (!isDefaultSort) ...<String>[
        '$kQuerySort=${sortColumn.name}',
        '$kQuerySortDir=${sortAscending ? kQueryDirAscending : kQueryDirDescending}',
      ],
      if (page > 0) '$kQueryPage=${page + 1}',
      if (rowsPerPage != kDefaultRowsPerPage) '$kQueryPageSize=$rowsPerPage',
    ];
    final String base = filter.path;
    if (extra.isEmpty) return base;
    return '$base${base.contains('?') ? '&' : '?'}${extra.join('&')}';
  }

  /// The query of [path] as parameters.
  Map<String, String> toQuery() => Uri.parse(path).queryParameters;

  /// A copy with the given parts replaced.
  ComplaintListQuery copyWith({
    ComplaintFilter? filter,
    ComplaintTableColumn? sortColumn,
    bool? sortAscending,
    int? page,
    int? rowsPerPage,
  }) => ComplaintListQuery(
    filter: filter ?? this.filter,
    sortColumn: sortColumn ?? this.sortColumn,
    sortAscending: sortAscending ?? this.sortAscending,
    page: page ?? this.page,
    rowsPerPage: rowsPerPage ?? this.rowsPerPage,
  );

  /// This view with [filter] instead, back on the first page (a narrower or
  /// wider list invalidates the page number).
  ComplaintListQuery withFilter(ComplaintFilter filter) =>
      copyWith(filter: filter, page: 0);

  /// This view after a click on the header of [column]: the same column
  /// reverses its direction, another column starts ascending. Back on the
  /// first page.
  ComplaintListQuery sortedBy(ComplaintTableColumn column) =>
      column == sortColumn
      ? copyWith(sortAscending: !sortAscending, page: 0)
      : copyWith(sortColumn: column, sortAscending: true, page: 0);

  /// This view with no filter at all (Reset filters): the sort and the page
  /// size are view choices, not filters, and stay.
  ComplaintListQuery reset() =>
      copyWith(filter: const ComplaintFilter(), page: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplaintListQuery &&
          other.filter == filter &&
          other.sortColumn == sortColumn &&
          other.sortAscending == sortAscending &&
          other.page == page &&
          other.rowsPerPage == rowsPerPage;

  @override
  int get hashCode =>
      Object.hash(filter, sortColumn, sortAscending, page, rowsPerPage);

  @override
  String toString() => 'ComplaintListQuery($path)';
}

ComplaintTableColumn? _columnNamed(String? name) {
  for (final ComplaintTableColumn c in ComplaintTableColumn.values) {
    if (c.name == name) return c;
  }
  return null;
}

/// The default order (AC-50): effective priority from the heaviest down, then
/// the longest waiting first (the earliest `createdAt`); the ID breaks a tie
/// so the order is total and stable.
int compareComplaintsByDefault(PublicComplaintView a, PublicComplaintView b) {
  final int byWeight = b.effectivePriority.weight.compareTo(
    a.effectivePriority.weight,
  );
  if (byWeight != 0) return byWeight;
  final int byAge = a.createdAt.compareTo(b.createdAt);
  return byAge != 0 ? byAge : a.id.compareTo(b.id);
}

/// "Building, floor, room" for ordering: building and room by name, the floor
/// by height (Basement, Ground, 1, 2, ... 10, Terrace, then open-air).
int _compareLocation(PublicComplaintView a, PublicComplaintView b) {
  final int byBuilding = a.building.toLowerCase().compareTo(
    b.building.toLowerCase(),
  );
  if (byBuilding != 0) return byBuilding;
  final int byFloor = _floorRank(a.floor).compareTo(_floorRank(b.floor));
  if (byFloor != 0) return byFloor;
  return a.room.toLowerCase().compareTo(b.room.toLowerCase());
}

int _floorRank(String floor) {
  final String f = floor.trim().toLowerCase();
  final int? level = int.tryParse(f);
  if (level != null) return level;
  return switch (f) {
    'basement' => -1,
    'ground' => 0,
    'terrace' => 1000,
    _ => 2000,
  };
}

/// The department as the Department column shows it.
String _departmentLabel(PublicComplaintView c) =>
    c.assignedDepartment?.label ?? 'Unassigned';

/// The comparison of [column] alone, ascending, without the tie-break.
/// [ComplaintTableColumn.waiting] is handled by the caller (its empty cells
/// stay last in both directions).
int _compareColumn(
  ComplaintTableColumn column,
  PublicComplaintView a,
  PublicComplaintView b,
) {
  return switch (column) {
    ComplaintTableColumn.id => a.id.compareTo(b.id),
    ComplaintTableColumn.category => a.category.label.toLowerCase().compareTo(
      b.category.label.toLowerCase(),
    ),
    ComplaintTableColumn.location => _compareLocation(a, b),
    ComplaintTableColumn.priority => a.effectivePriority.weight.compareTo(
      b.effectivePriority.weight,
    ),
    ComplaintTableColumn.status => a.status.order.compareTo(b.status.order),
    ComplaintTableColumn.department => _departmentLabel(
      a,
    ).toLowerCase().compareTo(_departmentLabel(b).toLowerCase()),
    // Ascending waiting = shortest first = the latest `createdAt` first.
    ComplaintTableColumn.waiting => b.createdAt.compareTo(a.createdAt),
    ComplaintTableColumn.updated => a.updatedAt.compareTo(b.updatedAt),
  };
}

/// The comparator of a click on [column]'s header. Ties fall back to the
/// default order, so sorting by Priority descending *is* the default order of
/// AC-50. The Waiting column shows "-" for resolved, verified and closed
/// complaints; those stay below every complaint that has a waiting time, in
/// both directions.
int Function(PublicComplaintView, PublicComplaintView) complaintComparator(
  ComplaintTableColumn column, {
  required bool ascending,
}) {
  return (PublicComplaintView a, PublicComplaintView b) {
    int byColumn;
    if (column == ComplaintTableColumn.waiting) {
      final bool aWaits = isUnresolvedStatus(a.status);
      final bool bWaits = isUnresolvedStatus(b.status);
      if (aWaits != bWaits) return aWaits ? -1 : 1;
      byColumn = aWaits ? _compareColumn(column, a, b) : 0;
    } else {
      byColumn = _compareColumn(column, a, b);
    }
    if (byColumn != 0) return ascending ? byColumn : -byColumn;
    return compareComplaintsByDefault(a, b);
  };
}

/// [views] sorted by [column] ([ascending] or not); the input is untouched.
List<PublicComplaintView> sortComplaints(
  Iterable<PublicComplaintView> views,
  ComplaintTableColumn column, {
  required bool ascending,
}) => views.toList()..sort(complaintComparator(column, ascending: ascending));

/// The number of pages of [total] rows at [rowsPerPage] per page: at least
/// one, so an empty list still has its first page.
int pageCountOf(int total, int rowsPerPage) =>
    total <= 0 ? 1 : (total + rowsPerPage - 1) ~/ rowsPerPage;

/// One page of the list: the rows to draw plus the numbers the footer needs.
@immutable
class ComplaintListPage {
  const ComplaintListPage({
    required this.rows,
    required this.totalCount,
    required this.allCount,
    required this.page,
    required this.rowsPerPage,
    required this.now,
  });

  /// The rows of this page (public views), at most [rowsPerPage].
  final List<PublicComplaintView> rows;

  /// How many complaints pass the filter, across all pages.
  final int totalCount;

  /// How many complaints exist at all. `allCount == 0` is the empty list;
  /// `totalCount == 0` with `allCount > 0` is the filtered-empty one.
  final int allCount;

  /// The zero-based page shown, clamped into the valid range.
  final int page;

  /// Rows per page.
  final int rowsPerPage;

  /// The reference time the filter's range and the table's Waiting and
  /// Updated columns were measured at.
  final DateTime now;

  /// How many pages the filtered list has (at least one).
  int get pageCount => pageCountOf(totalCount, rowsPerPage);

  /// Whether no complaint exists at all (as opposed to none matching).
  bool get isEmpty => allCount == 0;

  /// Whether the filter matches nothing although complaints exist.
  bool get isFilteredEmpty => allCount > 0 && totalCount == 0;
}

/// The page [query] asks for out of [views], as of [now]: filter (AC-49),
/// sort (AC-50 by default), then paginate. A page past the end shows the last
/// page.
ComplaintListPage buildComplaintListPage(
  Iterable<PublicComplaintView> views,
  ComplaintListQuery query,
  DateTime now,
) {
  final List<PublicComplaintView> all = views.toList();
  final List<PublicComplaintView> sorted = sortComplaints(
    applyComplaintFilter(all, query.filter, now),
    query.sortColumn,
    ascending: query.sortAscending,
  );
  final int perPage = query.rowsPerPage;
  final int lastPage = pageCountOf(sorted.length, perPage) - 1;
  final int page = query.page.clamp(0, lastPage);
  final int start = page * perPage;
  final int end = (start + perPage).clamp(0, sorted.length);
  return ComplaintListPage(
    rows: List<PublicComplaintView>.unmodifiable(sorted.sublist(start, end)),
    totalCount: sorted.length,
    allCount: all.length,
    page: page,
    rowsPerPage: perPage,
    now: now,
  );
}

/// The page of the list [query] asks for, from `allComplaintsProvider` (public
/// views, live) and the console clock. Auto-disposed: it holds nothing worth
/// keeping once the view changes or the screen closes.
final complaintListProvider = Provider.autoDispose
    .family<AsyncValue<ComplaintListPage>, ComplaintListQuery>((ref, query) {
      final DateTime now = ref.watch(dashboardClockProvider)();
      return ref
          .watch(allComplaintsProvider)
          .whenData((all) => buildComplaintListPage(all, query, now));
    });

/// The buildings the Building filter offers: the campus buildings in their
/// display order, then any other building a complaint was reported in
/// (reporters may type their own, screens-spec M-04), sorted by name.
final complaintBuildingsProvider = Provider.autoDispose<List<String>>((ref) {
  final List<String> campus = CampusDirectory.standard.buildingNames;
  final Set<String> known = campus.toSet();
  final Set<String> others = <String>{
    for (final PublicComplaintView c
        in ref.watch(allComplaintsProvider).value ??
            const <PublicComplaintView>[])
      if (c.building.trim().isNotEmpty && !known.contains(c.building))
        c.building,
  };
  return List<String>.unmodifiable(<String>[
    ...campus,
    ...others.toList()..sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    ),
  ]);
});
