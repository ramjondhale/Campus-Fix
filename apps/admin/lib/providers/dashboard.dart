// The aggregates behind the admin dashboard (A-02, screens-spec section 4).
//
// Everything here is typed on `PublicComplaintView` and plain numbers: the
// dashboard shows aggregates and public views only, never a reporter, an
// assignee or an actor (privacy-spec section 5.1). The pure functions hold the
// exact card definitions so they can be tested without a widget; the derived
// providers feed them from `allComplaintsProvider`, restricted to the selected
// date range.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaint_query.dart';
import 'complaints.dart';

/// How many rows each dashboard list shows (screens-spec A-02).
const int kDashboardListSize = 5;

/// How many days the intake chart covers (screens-spec A-02).
const int kIntakeDays = 14;

/// Whether [status] is unresolved: reported, reviewed, assigned or in
/// progress. Resolved, verified and closed complaints are done from the
/// admin's point of view (status-machine-spec).
bool isUnresolvedStatus(ComplaintStatus status) =>
    status.order < ComplaintStatus.resolved.order;

/// Whether [complaint] awaits manual triage: reviewed, with no department
/// assigned (Safety and Other have no default routing). The dashboard's
/// "Awaiting manual triage" list and the complaint list's "Needs manual
/// triage" toggle both use this one definition, so the preset lands on the
/// counted set.
bool needsManualTriage(PublicComplaintView complaint) =>
    complaint.status == ComplaintStatus.reviewed &&
    complaint.assignedDepartment == null;

/// Whether [priority] is one of the two the dashboard flags (Critical / High).
bool isCriticalOrHigh(Priority priority) =>
    priority == Priority.critical || priority == Priority.high;

/// The counts behind the metric cards and the charts, for one set of
/// complaints (the ones in the selected range).
///
/// Definitions (screens-spec A-02): Pending = reported + reviewed; Critical /
/// High = unresolved with an effective priority of critical or high (an
/// overlay, not part of the partition); Resolved = resolved + verified.
/// **Partition:** [pending] + [assigned] + [inProgress] + [resolved] +
/// [closed] = [total].
@immutable
class DashboardMetrics {
  const DashboardMetrics({
    required this.total,
    required this.pending,
    required this.criticalHigh,
    required this.assigned,
    required this.inProgress,
    required this.resolved,
    required this.closed,
    required this.awaitingVerification,
    required this.byStatus,
    required this.unresolvedByPriority,
    required this.unresolvedByCategory,
  });

  /// All complaints in the range.
  final int total;

  /// `status` in {reported, reviewed}.
  final int pending;

  /// Unresolved with `effectivePriority` in {critical, high}.
  final int criticalHigh;

  /// `status == assigned`.
  final int assigned;

  /// `status == inProgress`.
  final int inProgress;

  /// `status` in {resolved, verified}.
  final int resolved;

  /// `status == closed`.
  final int closed;

  /// `status == resolved`: repairs waiting for a verifier.
  final int awaitingVerification;

  /// Complaints per status, all seven, in `ComplaintStatus.order`. Sums to
  /// [total].
  final Map<ComplaintStatus, int> byStatus;

  /// Unresolved complaints per effective priority, all four, from Critical
  /// down to Low.
  final Map<Priority, int> unresolvedByPriority;

  /// Unresolved complaints per category, all eight, most first (ties keep the
  /// category order).
  final Map<ProblemCategory, int> unresolvedByCategory;

  /// Whether the card partition holds (it always does; kept so tests and
  /// asserts can state the invariant).
  bool get partitionHolds =>
      pending + assigned + inProgress + resolved + closed == total;
}

/// The metrics of [complaints] (already restricted to the range).
DashboardMetrics computeDashboardMetrics(
  Iterable<PublicComplaintView> complaints,
) {
  final Map<ComplaintStatus, int> byStatus = <ComplaintStatus, int>{
    for (final ComplaintStatus s in ComplaintStatus.values) s: 0,
  };
  final Map<Priority, int> byPriority = <Priority, int>{
    for (final Priority p in Priority.values) p: 0,
  };
  final Map<ProblemCategory, int> byCategory = <ProblemCategory, int>{
    for (final ProblemCategory c in ProblemCategory.values) c: 0,
  };
  int total = 0;
  int criticalHigh = 0;
  for (final PublicComplaintView c in complaints) {
    total++;
    byStatus[c.status] = byStatus[c.status]! + 1;
    if (!isUnresolvedStatus(c.status)) continue;
    byPriority[c.effectivePriority] = byPriority[c.effectivePriority]! + 1;
    byCategory[c.category] = byCategory[c.category]! + 1;
    if (isCriticalOrHigh(c.effectivePriority)) criticalHigh++;
  }

  // Priority from the heaviest down (design contract 2.8).
  final List<Priority> priorities = Priority.values.toList()
    ..sort((Priority a, Priority b) => b.weight.compareTo(a.weight));
  // Category by count, most first; the sort is stable so ties keep the enum
  // order.
  final List<ProblemCategory> categories = ProblemCategory.values.toList()
    ..sort(
      (ProblemCategory a, ProblemCategory b) =>
          byCategory[b]!.compareTo(byCategory[a]!),
    );

  return DashboardMetrics(
    total: total,
    pending:
        byStatus[ComplaintStatus.reported]! +
        byStatus[ComplaintStatus.reviewed]!,
    criticalHigh: criticalHigh,
    assigned: byStatus[ComplaintStatus.assigned]!,
    inProgress: byStatus[ComplaintStatus.inProgress]!,
    resolved:
        byStatus[ComplaintStatus.resolved]! +
        byStatus[ComplaintStatus.verified]!,
    closed: byStatus[ComplaintStatus.closed]!,
    awaitingVerification: byStatus[ComplaintStatus.resolved]!,
    byStatus: Map<ComplaintStatus, int>.unmodifiable(byStatus),
    unresolvedByPriority: Map<Priority, int>.unmodifiable(<Priority, int>{
      for (final Priority p in priorities) p: byPriority[p]!,
    }),
    unresolvedByCategory: Map<ProblemCategory, int>.unmodifiable(
      <ProblemCategory, int>{
        for (final ProblemCategory c in categories) c: byCategory[c]!,
      },
    ),
  );
}

/// [complaints] created inside [range] as of [now], in their given order.
List<PublicComplaintView> complaintsInRange(
  Iterable<PublicComplaintView> complaints,
  CreatedRange range,
  DateTime now,
) => <PublicComplaintView>[
  for (final PublicComplaintView c in complaints)
    if (range.contains(c.createdAt, now)) c,
];

/// One bar of the intake chart: the complaints created on [day].
@immutable
class IntakeDay {
  const IntakeDay({required this.day, required this.count});

  /// The calendar day (a date at midnight in the zone of the clock).
  final DateTime day;

  /// Complaints created that day.
  final int count;
}

/// Complaints created per calendar day over the last [days] days up to and
/// including today (by `createdAt`), oldest day first. Days are taken in the
/// time zone of [now] (UTC when [now] is UTC, local time otherwise).
List<IntakeDay> intakePerDay(
  Iterable<PublicComplaintView> complaints,
  DateTime now, {
  int days = kIntakeDays,
}) {
  final bool utc = now.isUtc;
  DateTime dayOf(DateTime t) {
    final DateTime z = utc ? t.toUtc() : t.toLocal();
    return utc
        ? DateTime.utc(z.year, z.month, z.day)
        : DateTime(z.year, z.month, z.day);
  }

  final DateTime today = dayOf(now);
  final List<DateTime> window = <DateTime>[
    for (int i = days - 1; i >= 0; i--)
      utc
          ? DateTime.utc(today.year, today.month, today.day - i)
          : DateTime(today.year, today.month, today.day - i),
  ];
  final Map<DateTime, int> counts = <DateTime, int>{
    for (final DateTime d in window) d: 0,
  };
  for (final PublicComplaintView c in complaints) {
    final DateTime d = dayOf(c.createdAt);
    final int? n = counts[d];
    if (n != null) counts[d] = n + 1;
  }
  return <IntakeDay>[
    for (final DateTime d in window) IntakeDay(day: d, count: counts[d]!),
  ];
}

/// A dashboard list: the first [rows] of a longer ordered set of [total].
@immutable
class DashboardList {
  const DashboardList({required this.rows, required this.total});

  /// At most [kDashboardListSize] complaints, in display order.
  final List<PublicComplaintView> rows;

  /// How many complaints the whole list holds ("View all" opens them).
  final int total;
}

DashboardList _topOf(
  Iterable<PublicComplaintView> matching,
  int Function(PublicComplaintView, PublicComplaintView) compare,
  int limit,
) {
  final List<PublicComplaintView> sorted = matching.toList()..sort(compare);
  return DashboardList(
    rows: List<PublicComplaintView>.unmodifiable(sorted.take(limit)),
    total: sorted.length,
  );
}

/// Oldest first; the ID breaks a tie so the order is stable.
int _byAge(PublicComplaintView a, PublicComplaintView b) {
  final int byTime = a.createdAt.compareTo(b.createdAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Heaviest effective priority first, then oldest.
int _byWeightThenAge(PublicComplaintView a, PublicComplaintView b) {
  final int byWeight = b.effectivePriority.weight.compareTo(
    a.effectivePriority.weight,
  );
  return byWeight != 0 ? byWeight : _byAge(a, b);
}

/// **Needs attention:** unresolved complaints with an effective priority of
/// critical or high, heaviest first, then longest waiting.
DashboardList needsAttentionOf(
  Iterable<PublicComplaintView> complaints, {
  int limit = kDashboardListSize,
}) => _topOf(
  complaints.where(
    (PublicComplaintView c) =>
        isUnresolvedStatus(c.status) && isCriticalOrHigh(c.effectivePriority),
  ),
  _byWeightThenAge,
  limit,
);

/// **Oldest unresolved:** every unresolved complaint, longest waiting first.
DashboardList oldestUnresolvedOf(
  Iterable<PublicComplaintView> complaints, {
  int limit = kDashboardListSize,
}) => _topOf(
  complaints.where((PublicComplaintView c) => isUnresolvedStatus(c.status)),
  _byAge,
  limit,
);

/// **Awaiting manual triage:** reviewed complaints with no department
/// assigned (Safety and Other have no default routing), heaviest first, then
/// longest waiting.
DashboardList awaitingTriageOf(
  Iterable<PublicComplaintView> complaints, {
  int limit = kDashboardListSize,
}) => _topOf(complaints.where(needsManualTriage), _byWeightThenAge, limit);

/// The "created within" range the whole dashboard is computed for (default
/// All). Kept in a provider so every card, chart and list recomputes when it
/// changes, and so it survives opening a complaint and coming back.
class DashboardRangeNotifier extends Notifier<CreatedRange> {
  @override
  CreatedRange build() => CreatedRange.all;

  /// Selects [range].
  void select(CreatedRange range) => state = range;
}

final dashboardRangeProvider =
    NotifierProvider<DashboardRangeNotifier, CreatedRange>(
      DashboardRangeNotifier.new,
    );

/// The clock the dashboard measures ranges, intake days and waiting times
/// with. The real clock in the app; tests pin it to the seed's reference time.
final dashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

// The derived providers below are auto-disposed: they hold nothing worth
// keeping once the dashboard is closed (the range choice above is what
// survives), and a provider that outlives its screen would be stale against
// `allComplaintsProvider` the next time the console is opened after a sign-in.

/// The complaints created inside the selected range (public views).
final dashboardComplaintsProvider =
    Provider.autoDispose<AsyncValue<List<PublicComplaintView>>>((ref) {
      final CreatedRange range = ref.watch(dashboardRangeProvider);
      final DateTime now = ref.watch(dashboardClockProvider)();
      return ref
          .watch(allComplaintsProvider)
          .whenData((all) => complaintsInRange(all, range, now));
    });

/// The metric-card and chart counts for the selected range.
final dashboardMetricsProvider =
    Provider.autoDispose<AsyncValue<DashboardMetrics>>(
      (ref) => ref
          .watch(dashboardComplaintsProvider)
          .whenData(computeDashboardMetrics),
    );

/// Intake per day over the last [kIntakeDays] days. A fixed trailing window,
/// not narrowed by the range control.
final dashboardIntakeProvider =
    Provider.autoDispose<AsyncValue<List<IntakeDay>>>((ref) {
      final DateTime now = ref.watch(dashboardClockProvider)();
      return ref
          .watch(allComplaintsProvider)
          .whenData((all) => intakePerDay(all, now));
    });

/// The Needs attention list for the selected range.
final dashboardNeedsAttentionProvider =
    Provider.autoDispose<AsyncValue<DashboardList>>(
      (ref) =>
          ref.watch(dashboardComplaintsProvider).whenData(needsAttentionOf),
    );

/// The Oldest unresolved list for the selected range.
final dashboardOldestUnresolvedProvider =
    Provider.autoDispose<AsyncValue<DashboardList>>(
      (ref) =>
          ref.watch(dashboardComplaintsProvider).whenData(oldestUnresolvedOf),
    );

/// The Awaiting manual triage list for the selected range.
final dashboardAwaitingTriageProvider =
    Provider.autoDispose<AsyncValue<DashboardList>>(
      (ref) =>
          ref.watch(dashboardComplaintsProvider).whenData(awaitingTriageOf),
    );
