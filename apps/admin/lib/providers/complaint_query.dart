// The URL filter contract of the complaint list (A-03, screens-spec section 4).
//
// The dashboard (A-02) opens `/complaints` pre-filtered by a card, a chart bar
// or a list's "View all"; the list screen (A-03, S5.3) reads the same keys back
// from the URL query. This file is the one place that names them, so the two
// screens cannot drift apart.
//
// Filter VALUES only (privacy-spec PV-5, LK-5): there is deliberately no key
// that could carry a reporter, an assignee or any other identity.
//
// | key          | value                                                    |
// |--------------|----------------------------------------------------------|
// | `status`     | CSV of `ComplaintStatus.name` (`reported,reviewed`)      |
// | `priority`   | CSV of `Priority.name`, the effective priority           |
// | `category`   | CSV of `ProblemCategory.name`                            |
// | `department` | CSV of `Department.name`, plus `unassigned`              |
// | `building`   | a building name (free text, URL-encoded)                 |
// | `q`          | the search text (URL-encoded)                            |
// | `unresolved` | `1`: status in reported, reviewed, assigned, inProgress  |
// | `triage`     | `1`: status == reviewed and no department assigned       |
// | `created`    | `7d`, `30d`, `90d` or `all`: window on `createdAt`       |
//
// Filters AND together (AC-49); a missing key means "no filter on that field".
// The dashboard always sends `created` (also `all`) so a preset matches the
// set the dashboard counted.

import 'package:campusfix_core/campusfix_core.dart';

import '../router/routes.dart';

/// Query key: CSV of [ComplaintStatus] names.
const String kQueryStatus = 'status';

/// Query key: CSV of [Priority] names (the effective priority).
const String kQueryPriority = 'priority';

/// Query key: CSV of [ProblemCategory] names.
const String kQueryCategory = 'category';

/// Query key: CSV of [Department] names, plus [kUnassignedDepartment].
const String kQueryDepartment = 'department';

/// Query key: a building name.
const String kQueryBuilding = 'building';

/// Query key: the search text.
const String kQuerySearch = 'q';

/// Query key: the "Unresolved only" toggle ([kQueryFlagOn] when set).
const String kQueryUnresolved = 'unresolved';

/// Query key: the "Needs manual triage" toggle ([kQueryFlagOn] when set).
const String kQueryTriage = 'triage';

/// Query key: the [CreatedRange] on `createdAt` (a [CreatedRange.queryValue]).
const String kQueryCreated = 'created';

/// The value of a set toggle (`unresolved=1`, `triage=1`).
const String kQueryFlagOn = '1';

/// The extra `department` value for complaints with no department.
const String kUnassignedDepartment = 'unassigned';

/// The "created within" window shared by the dashboard's range control (A-02)
/// and the list's Created filter (A-03): the last 7, 30 or 90 days of
/// `createdAt`, or all time.
enum CreatedRange {
  /// The last 7 days.
  days7('7 d', '7d', 7),

  /// The last 30 days.
  days30('30 d', '30d', 30),

  /// The last 90 days.
  days90('90 d', '90d', 90),

  /// No window (the dashboard default).
  all('All', 'all', null);

  const CreatedRange(this.label, this.queryValue, this.days);

  /// The control label ("7 d").
  final String label;

  /// The value of the `created` query key.
  final String queryValue;

  /// The window length in days; `null` for [all].
  final int? days;

  /// The range for a `created` [value], or `null` when it is not one.
  static CreatedRange? fromQueryValue(String? value) {
    for (final CreatedRange r in values) {
      if (r.queryValue == value) return r;
    }
    return null;
  }

  /// Whether a complaint created at [createdAt] falls in this range as of
  /// [now]: not older than [days] x 24 h; [all] holds everything. The one
  /// definition the dashboard counts with and the list filters with, so a
  /// preset lands on exactly the counted set (AC-47).
  bool contains(DateTime createdAt, DateTime now) {
    final int? window = days;
    if (window == null) return true;
    return !createdAt.isBefore(now.subtract(Duration(days: window)));
  }
}

/// The path of the complaint list (A-03) with the given filters in its query.
///
/// Only the filters that are set appear, always in the canonical order of the
/// table above, so the same filter always yields the same URL. CSV values keep
/// their commas literal (`priority=critical,high`); free text is
/// percent-encoded. With no filter at all the result is the bare
/// `/complaints`.
String complaintsPathWith({
  Iterable<ComplaintStatus> statuses = const <ComplaintStatus>[],
  Iterable<Priority> priorities = const <Priority>[],
  Iterable<ProblemCategory> categories = const <ProblemCategory>[],
  Iterable<Department> departments = const <Department>[],
  bool includeUnassigned = false,
  String? building,
  String? search,
  bool unresolved = false,
  bool triage = false,
  CreatedRange? created,
}) {
  final List<String> pairs = <String>[];
  void csv(String key, Iterable<String> values) {
    final List<String> list = values.toList();
    if (list.isNotEmpty) pairs.add('$key=${list.join(',')}');
  }

  csv(kQueryStatus, statuses.map((ComplaintStatus s) => s.name));
  csv(kQueryPriority, priorities.map((Priority p) => p.name));
  csv(kQueryCategory, categories.map((ProblemCategory c) => c.name));
  csv(kQueryDepartment, <String>[
    ...departments.map((Department d) => d.name),
    if (includeUnassigned) kUnassignedDepartment,
  ]);
  if (building != null && building.isNotEmpty) {
    pairs.add('$kQueryBuilding=${Uri.encodeQueryComponent(building)}');
  }
  if (search != null && search.isNotEmpty) {
    pairs.add('$kQuerySearch=${Uri.encodeQueryComponent(search)}');
  }
  if (unresolved) pairs.add('$kQueryUnresolved=$kQueryFlagOn');
  if (triage) pairs.add('$kQueryTriage=$kQueryFlagOn');
  if (created != null) pairs.add('$kQueryCreated=${created.queryValue}');

  return pairs.isEmpty
      ? AppRoutes.complaints
      : '${AppRoutes.complaints}?${pairs.join('&')}';
}
