// The filters of the complaint list (A-03, screens-spec section 4): the model,
// its round trip through the URL query, and the pure predicate that applies it.
//
// Everything here is typed on `PublicComplaintView` and plain values. There is
// no filter on a reporter, an assignee or an actor (privacy-spec PV-5), and no
// key that could carry one: the query holds filter values only.
//
// **URL contract.** The keys are the ones in `complaint_query.dart`, which the
// dashboard (A-02) builds its presets with; `ComplaintFilter.fromQuery` reads
// them back and `toQuery` writes them in the canonical order of
// `complaintsPathWith`, so a dashboard preset round-trips unchanged and lands
// on exactly the set the dashboard counted (AC-47).
//
// **Semantics (AC-49).** Within one facet the values OR (status is Reported
// or Reviewed); the facets AND together.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable, setEquals;

import 'complaint_query.dart';
import 'dashboard.dart' show isUnresolvedStatus, needsManualTriage;

/// What the list is filtered by. The default filter ([isEmpty]) holds every
/// complaint.
@immutable
class ComplaintFilter {
  /// Creates a filter. A missing facet means "no filter on that field". The
  /// sets are not copied: pass an unmodifiable set, or use [copyWith] and
  /// [ComplaintFilter.fromQuery], which always do.
  const ComplaintFilter({
    this.statuses = const <ComplaintStatus>{},
    this.priorities = const <Priority>{},
    this.categories = const <ProblemCategory>{},
    this.departments = const <Department>{},
    this.includeUnassigned = false,
    this.building,
    this.search,
    this.unresolvedOnly = false,
    this.needsTriage = false,
    this.created = CreatedRange.all,
  });

  /// Reads a filter from the `queryParameters` of an A-03 URL.
  ///
  /// Tolerant by design (a URL is user-editable): unknown names, duplicates
  /// and blank values are ignored, an unknown `created` means [CreatedRange.all]
  /// and a toggle is on only for the exact value `1`.
  factory ComplaintFilter.fromQuery(Map<String, String> query) {
    return ComplaintFilter(
      statuses: _enumSet<ComplaintStatus>(
        query[kQueryStatus],
        ComplaintStatus.values,
      ),
      priorities: _enumSet<Priority>(query[kQueryPriority], Priority.values),
      categories: _enumSet<ProblemCategory>(
        query[kQueryCategory],
        ProblemCategory.values,
      ),
      departments: _enumSet<Department>(
        query[kQueryDepartment],
        Department.values,
      ),
      includeUnassigned: _csv(
        query[kQueryDepartment],
      ).contains(kUnassignedDepartment),
      building: _text(query[kQueryBuilding]),
      search: _text(query[kQuerySearch]),
      unresolvedOnly: query[kQueryUnresolved] == kQueryFlagOn,
      needsTriage: query[kQueryTriage] == kQueryFlagOn,
      created:
          CreatedRange.fromQueryValue(query[kQueryCreated]) ?? CreatedRange.all,
    );
  }

  /// Statuses to show; empty means any.
  final Set<ComplaintStatus> statuses;

  /// Effective priorities to show; empty means any.
  final Set<Priority> priorities;

  /// Categories to show; empty means any.
  final Set<ProblemCategory> categories;

  /// Departments to show. With [includeUnassigned], complaints that have no
  /// department match too; with both empty the facet is off.
  final Set<Department> departments;

  /// Whether complaints with no department match the Department facet.
  final bool includeUnassigned;

  /// The building (exact name, any case); `null` means any.
  final String? building;

  /// The search text; `null` means no search. Trimmed and never blank.
  final String? search;

  /// "Unresolved only": status in reported, reviewed, assigned, in progress.
  final bool unresolvedOnly;

  /// "Needs manual triage": reviewed, with no department assigned.
  final bool needsTriage;

  /// The window on `createdAt`.
  final CreatedRange created;

  /// Whether the Department facet is on.
  bool get hasDepartmentFilter => departments.isNotEmpty || includeUnassigned;

  /// Whether any facet narrows the list. This is what lights "Reset filters".
  bool get hasAnyFilter =>
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      categories.isNotEmpty ||
      hasDepartmentFilter ||
      building != null ||
      search != null ||
      unresolvedOnly ||
      needsTriage ||
      created != CreatedRange.all;

  /// Whether this is the default filter (nothing narrows the list).
  bool get isEmpty => !hasAnyFilter;

  /// Whether [complaint], seen at [now], passes every facet (AC-49).
  bool matches(PublicComplaintView complaint, DateTime now) {
    if (statuses.isNotEmpty && !statuses.contains(complaint.status)) {
      return false;
    }
    if (priorities.isNotEmpty &&
        !priorities.contains(complaint.effectivePriority)) {
      return false;
    }
    if (categories.isNotEmpty && !categories.contains(complaint.category)) {
      return false;
    }
    if (hasDepartmentFilter) {
      final Department? department = complaint.assignedDepartment;
      final bool inDepartment = department == null
          ? includeUnassigned
          : departments.contains(department);
      if (!inDepartment) return false;
    }
    final String? wantedBuilding = building;
    if (wantedBuilding != null &&
        complaint.building.trim().toLowerCase() !=
            wantedBuilding.toLowerCase()) {
      return false;
    }
    if (unresolvedOnly && !isUnresolvedStatus(complaint.status)) return false;
    if (needsTriage && !needsManualTriage(complaint)) return false;
    if (!created.contains(complaint.createdAt, now)) return false;
    final String? text = search;
    if (text != null && !_matchesSearch(complaint, text)) return false;
    return true;
  }

  /// The A-03 path with this filter in its query (`/complaints` for the
  /// default filter).
  ///
  /// The range is written whenever any filter is on, also as `created=all`,
  /// the way the dashboard writes it, so a dashboard preset comes back
  /// byte for byte; the default filter is the bare path.
  String get path => complaintsPathWith(
    statuses: ComplaintStatus.values.where(statuses.contains),
    priorities: Priority.values.where(priorities.contains),
    categories: ProblemCategory.values.where(categories.contains),
    departments: Department.values.where(departments.contains),
    includeUnassigned: includeUnassigned,
    building: building,
    search: search,
    unresolved: unresolvedOnly,
    triage: needsTriage,
    created: hasAnyFilter ? created : null,
  );

  /// The query of [path] as parameters: only the facets that are set, in the
  /// canonical order. `ComplaintFilter.fromQuery(toQuery())` equals this
  /// filter.
  Map<String, String> toQuery() => Uri.parse(path).queryParameters;

  /// A copy with the given facets replaced. [building] and [search] are
  /// trimmed, and cleared by a blank value or by `clearBuilding` /
  /// `clearSearch`.
  ComplaintFilter copyWith({
    Set<ComplaintStatus>? statuses,
    Set<Priority>? priorities,
    Set<ProblemCategory>? categories,
    Set<Department>? departments,
    bool? includeUnassigned,
    String? building,
    bool clearBuilding = false,
    String? search,
    bool clearSearch = false,
    bool? unresolvedOnly,
    bool? needsTriage,
    CreatedRange? created,
  }) {
    return ComplaintFilter(
      statuses: Set<ComplaintStatus>.unmodifiable(statuses ?? this.statuses),
      priorities: Set<Priority>.unmodifiable(priorities ?? this.priorities),
      categories: Set<ProblemCategory>.unmodifiable(
        categories ?? this.categories,
      ),
      departments: Set<Department>.unmodifiable(
        departments ?? this.departments,
      ),
      includeUnassigned: includeUnassigned ?? this.includeUnassigned,
      building: clearBuilding
          ? null
          : (building != null ? _text(building) : this.building),
      search: clearSearch
          ? null
          : (search != null ? _text(search) : this.search),
      unresolvedOnly: unresolvedOnly ?? this.unresolvedOnly,
      needsTriage: needsTriage ?? this.needsTriage,
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplaintFilter &&
          setEquals(other.statuses, statuses) &&
          setEquals(other.priorities, priorities) &&
          setEquals(other.categories, categories) &&
          setEquals(other.departments, departments) &&
          other.includeUnassigned == includeUnassigned &&
          other.building == building &&
          other.search == search &&
          other.unresolvedOnly == unresolvedOnly &&
          other.needsTriage == needsTriage &&
          other.created == created;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(priorities),
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(departments),
    includeUnassigned,
    building,
    search,
    unresolvedOnly,
    needsTriage,
    created,
  );

  @override
  String toString() => 'ComplaintFilter($path)';
}

/// The complaints of [views] that pass [filter] as of [now], in their given
/// order (AC-49: every facet narrows, and the facets AND together).
List<PublicComplaintView> applyComplaintFilter(
  Iterable<PublicComplaintView> views,
  ComplaintFilter filter,
  DateTime now,
) => <PublicComplaintView>[
  for (final PublicComplaintView c in views)
    if (filter.matches(c, now)) c,
];

/// The text a search is matched against: the ID, the description and the
/// location (building, floor and room), lower-cased. Public fields only.
String _searchHaystack(PublicComplaintView c) =>
    '${c.id} ${c.description} ${c.building} ${c.floor} ${c.room}'.toLowerCase();

/// Whether every word of [text] occurs somewhere in the ID, description or
/// location of [c], ignoring case.
bool _matchesSearch(PublicComplaintView c, String text) {
  final String haystack = _searchHaystack(c);
  for (final String word in text.toLowerCase().split(RegExp(r'\s+'))) {
    if (word.isNotEmpty && !haystack.contains(word)) return false;
  }
  return true;
}

/// The trimmed, non-blank items of a CSV query value.
Set<String> _csv(String? value) => <String>{
  if (value != null)
    for (final String part in value.split(','))
      if (part.trim().isNotEmpty) part.trim(),
};

/// The values of [values] named in the CSV [value] (unknown names ignored).
Set<T> _enumSet<T extends Enum>(String? value, List<T> values) {
  final Set<String> names = _csv(value);
  return Set<T>.unmodifiable(<T>{
    for (final T v in values)
      if (names.contains(v.name)) v,
  });
}

/// [value] trimmed, or `null` when it is `null` or blank.
String? _text(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
