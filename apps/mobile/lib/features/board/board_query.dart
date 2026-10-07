import 'package:campusfix_core/campusfix_core.dart';

import '../shared/complaint_search.dart';

/// The Campus Board's sort orders (screens-spec M-11).
enum BoardSort {
  /// `Priority.weight` descending, then newest first (the default).
  priority('Priority'),
  newest('Newest'),
  oldest('Oldest'),
  recentlyUpdated('Recently updated');

  const BoardSort(this.label);

  final String label;

  int compare(PublicComplaintView a, PublicComplaintView b) => switch (this) {
    BoardSort.priority => _byPriority(a, b),
    BoardSort.newest => b.createdAt.compareTo(a.createdAt),
    BoardSort.oldest => a.createdAt.compareTo(b.createdAt),
    BoardSort.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
  };

  static int _byPriority(PublicComplaintView a, PublicComplaintView b) {
    final int byWeight = b.effectivePriority.weight.compareTo(
      a.effectivePriority.weight,
    );
    return byWeight != 0 ? byWeight : b.createdAt.compareTo(a.createdAt);
  }
}

/// The filter, search and sort state of the Campus Board. Works on public
/// views only; the search covers public fields (ID, description, location).
class BoardFilters {
  const BoardFilters({
    this.categories = const <ProblemCategory>{},
    this.priorities = const <Priority>{},
    this.statuses = const <ComplaintStatus>{},
    this.building,
    this.includeClosed = false,
    this.query = '',
    this.sort = BoardSort.priority,
  });

  final Set<ProblemCategory> categories;
  final Set<Priority> priorities;
  final Set<ComplaintStatus> statuses;

  /// A single building, or `null` for any.
  final String? building;

  /// Whether `closed` complaints are listed (off by default).
  final bool includeClosed;

  final String query;
  final BoardSort sort;

  /// Whether anything narrows the list beyond the default (the sort order is
  /// a preference, not a filter).
  bool get hasActive =>
      categories.isNotEmpty ||
      priorities.isNotEmpty ||
      statuses.isNotEmpty ||
      building != null ||
      includeClosed ||
      query.trim().isNotEmpty;

  BoardFilters copyWith({
    Set<ProblemCategory>? categories,
    Set<Priority>? priorities,
    Set<ComplaintStatus>? statuses,
    String? building,
    bool clearBuilding = false,
    bool? includeClosed,
    String? query,
    BoardSort? sort,
  }) => BoardFilters(
    categories: categories ?? this.categories,
    priorities: priorities ?? this.priorities,
    statuses: statuses ?? this.statuses,
    building: clearBuilding ? null : (building ?? this.building),
    includeClosed: includeClosed ?? this.includeClosed,
    query: query ?? this.query,
    sort: sort ?? this.sort,
  );

  /// Filters AND together; `closed` complaints are hidden unless
  /// [includeClosed] is on or `closed` is picked as a status.
  bool matches(PublicComplaintView c) {
    if (c.status == ComplaintStatus.closed &&
        !includeClosed &&
        !statuses.contains(ComplaintStatus.closed)) {
      return false;
    }
    if (categories.isNotEmpty && !categories.contains(c.category)) return false;
    if (priorities.isNotEmpty && !priorities.contains(c.effectivePriority)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(c.status)) return false;
    if (building != null && c.building != building) return false;
    return matchesComplaintQuery(c, query, includeLocation: true);
  }

  /// The complaints of [all] that match, in [sort] order.
  List<PublicComplaintView> apply(List<PublicComplaintView> all) =>
      <PublicComplaintView>[
        for (final PublicComplaintView c in all)
          if (matches(c)) c,
      ]..sort(sort.compare);
}
