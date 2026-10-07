import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dashboard_fixtures.dart';
import 'support/pump_app.dart';
import 'support/settled.dart';

/// The pure side of the admin dashboard (A-02): the card definitions, the
/// partition invariant, the chart counts, the triage lists, the date range and
/// the intake days, plus the A-03 URL contract the presets are built with.
void main() {
  final DateTime now = testSeed.now; // 2026-10-06 09:00 UTC
  final List<PublicComplaintView> all = toPublicViews(testSeed.complaints);
  final List<Complaint> raw = testSeed.complaints;

  int rawCount(bool Function(Complaint c) test) => raw.where(test).length;
  bool unresolved(ComplaintStatus s) =>
      s == ComplaintStatus.reported ||
      s == ComplaintStatus.reviewed ||
      s == ComplaintStatus.assigned ||
      s == ComplaintStatus.inProgress;

  group('AC-46 card definitions on the seed (range: All)', () {
    final DashboardMetrics m = computeDashboardMetrics(all);

    test('every card matches its definition, counted independently', () {
      expect(m.total, raw.length);
      expect(
        m.pending,
        rawCount(
          (c) =>
              c.status == ComplaintStatus.reported ||
              c.status == ComplaintStatus.reviewed,
        ),
      );
      expect(
        m.criticalHigh,
        rawCount(
          (c) =>
              unresolved(c.status) &&
              (c.effectivePriority == Priority.critical ||
                  c.effectivePriority == Priority.high),
        ),
      );
      expect(m.assigned, rawCount((c) => c.status == ComplaintStatus.assigned));
      expect(
        m.inProgress,
        rawCount((c) => c.status == ComplaintStatus.inProgress),
      );
      expect(
        m.resolved,
        rawCount(
          (c) =>
              c.status == ComplaintStatus.resolved ||
              c.status == ComplaintStatus.verified,
        ),
      );
      expect(m.closed, rawCount((c) => c.status == ComplaintStatus.closed));
      expect(
        m.awaitingVerification,
        rawCount((c) => c.status == ComplaintStatus.resolved),
      );
    });

    test('the numbers of the deterministic seed', () {
      expect(m.total, 29);
      expect(m.pending, 7);
      expect(m.criticalHigh, 9);
      expect(m.assigned, 4);
      expect(m.inProgress, 6);
      expect(m.resolved, 7);
      expect(m.closed, 5);
      expect(m.awaitingVerification, 4);
    });

    test('partition: Pending + Assigned + In progress + Resolved + Closed '
        '= Total', () {
      expect(m.pending + m.assigned + m.inProgress + m.resolved + m.closed, 29);
      expect(m.partitionHolds, isTrue);
    });

    test('Critical / High is an overlay, not a part of the partition', () {
      // It cuts across Pending, Assigned and In progress...
      final Set<ComplaintStatus> statuses = <ComplaintStatus>{
        for (final PublicComplaintView c in all)
          if (unresolved(c.status) &&
              (c.effectivePriority == Priority.critical ||
                  c.effectivePriority == Priority.high))
            c.status,
      };
      expect(statuses.length, greaterThan(1));
      // ...and leaving it out still sums to the total.
      expect(m.partitionHolds, isTrue);
      expect(m.criticalHigh, lessThan(m.total));
    });

    test('the partition holds for every range on the seed', () {
      for (final CreatedRange r in CreatedRange.values) {
        final DashboardMetrics rm = computeDashboardMetrics(
          complaintsInRange(all, r, now),
        );
        expect(rm.partitionHolds, isTrue, reason: r.queryValue);
        expect(
          rm.byStatus.values.fold<int>(0, (a, b) => a + b),
          rm.total,
          reason: r.queryValue,
        );
      }
    });
  });

  group('definitions on synthetic data', () {
    final DateTime t = DateTime.utc(2026, 10, 1);
    int n = 0;
    PublicComplaintView v(
      ComplaintStatus s, {
      Priority p = Priority.medium,
      ProblemCategory c = ProblemCategory.electrical,
      Department? d,
      DateTime? at,
    }) => viewOf(
      id: 'CF-X-${n++}',
      status: s,
      priority: p,
      category: c,
      department: d,
      createdAt: at ?? t,
    );

    test('an empty set is all zeros and still partitions', () {
      final DashboardMetrics m = computeDashboardMetrics(const []);
      expect(m.total, 0);
      expect(<int>[
        m.pending,
        m.criticalHigh,
        m.assigned,
        m.inProgress,
        m.resolved,
        m.closed,
        m.awaitingVerification,
      ], everyElement(0));
      expect(m.partitionHolds, isTrue);
      expect(m.byStatus.length, 7);
      expect(m.unresolvedByPriority.length, 4);
      expect(m.unresolvedByCategory.length, 8);
    });

    test('Critical / High counts unresolved only; resolved and closed do not '
        'count', () {
      final DashboardMetrics m = computeDashboardMetrics(<PublicComplaintView>[
        v(ComplaintStatus.reported, p: Priority.critical),
        v(ComplaintStatus.reviewed, p: Priority.high),
        v(ComplaintStatus.assigned, p: Priority.high),
        v(ComplaintStatus.inProgress, p: Priority.critical),
        v(ComplaintStatus.resolved, p: Priority.critical),
        v(ComplaintStatus.verified, p: Priority.high),
        v(ComplaintStatus.closed, p: Priority.critical),
        v(ComplaintStatus.reported, p: Priority.medium),
        v(ComplaintStatus.inProgress, p: Priority.low),
      ]);
      expect(m.total, 9);
      expect(m.criticalHigh, 4);
      expect(m.partitionHolds, isTrue);
    });

    test(
      'Resolved includes verified; Awaiting verification is resolved only',
      () {
        final DashboardMetrics m =
            computeDashboardMetrics(<PublicComplaintView>[
              v(ComplaintStatus.resolved),
              v(ComplaintStatus.resolved),
              v(ComplaintStatus.verified),
            ]);
        expect(m.resolved, 3);
        expect(m.awaitingVerification, 2);
        expect(m.closed, 0);
      },
    );

    test('Pending is reported plus reviewed', () {
      final DashboardMetrics m = computeDashboardMetrics(<PublicComplaintView>[
        v(ComplaintStatus.reported),
        v(ComplaintStatus.reviewed),
        v(ComplaintStatus.assigned),
      ]);
      expect(m.pending, 2);
      expect(m.assigned, 1);
    });
  });

  group('charts', () {
    final DashboardMetrics m = computeDashboardMetrics(all);

    test('status: all seven in lifecycle order, summing to Total', () {
      expect(m.byStatus.keys.toList(), <ComplaintStatus>[
        ...ComplaintStatus.values,
      ]);
      expect(m.byStatus.values.fold<int>(0, (a, b) => a + b), m.total);
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(m.byStatus[s], rawCount((c) => c.status == s), reason: s.name);
      }
    });

    test('priority: unresolved, all four, Critical down to Low', () {
      expect(m.unresolvedByPriority.keys.toList(), <Priority>[
        Priority.critical,
        Priority.high,
        Priority.medium,
        Priority.low,
      ]);
      for (final Priority p in Priority.values) {
        expect(
          m.unresolvedByPriority[p],
          rawCount((c) => unresolved(c.status) && c.effectivePriority == p),
          reason: p.name,
        );
      }
      expect(
        m.unresolvedByPriority.values.fold<int>(0, (a, b) => a + b),
        rawCount((c) => unresolved(c.status)),
      );
    });

    test('category: unresolved, all eight, most first', () {
      expect(m.unresolvedByCategory.length, 8);
      final List<int> counts = m.unresolvedByCategory.values.toList();
      expect(counts, orderedEquals(counts.toList()..sort((a, b) => b - a)));
      for (final ProblemCategory c in ProblemCategory.values) {
        expect(
          m.unresolvedByCategory[c],
          rawCount((r) => unresolved(r.status) && r.category == c),
          reason: c.name,
        );
      }
      expect(
        m.unresolvedByCategory.values.fold<int>(0, (a, b) => a + b),
        rawCount((c) => unresolved(c.status)),
      );
    });

    test('category ties keep the category order', () {
      final DateTime t = DateTime.utc(2026, 10, 1);
      final DashboardMetrics tm = computeDashboardMetrics(<PublicComplaintView>[
        viewOf(id: 'a', category: ProblemCategory.it, createdAt: t),
        viewOf(id: 'b', category: ProblemCategory.electrical, createdAt: t),
        viewOf(id: 'c', category: ProblemCategory.it, createdAt: t),
      ]);
      expect(tm.unresolvedByCategory.keys.take(2).toList(), <ProblemCategory>[
        ProblemCategory.it,
        ProblemCategory.electrical,
      ]);
      // The zero rows keep their enum order after the non-zero ones.
      expect(
        tm.unresolvedByCategory.keys.skip(2).toList(),
        ProblemCategory.values
            .where(
              (c) => c != ProblemCategory.it && c != ProblemCategory.electrical,
            )
            .toList(),
      );
    });
  });

  group('date range (createdAt)', () {
    test('7 d / 30 d / 90 d / All narrow the counts', () {
      final Map<CreatedRange, int> expected = <CreatedRange, int>{
        CreatedRange.days7: rawCount(
          (c) => !c.createdAt.isBefore(now.subtract(const Duration(days: 7))),
        ),
        CreatedRange.days30: rawCount(
          (c) => !c.createdAt.isBefore(now.subtract(const Duration(days: 30))),
        ),
        CreatedRange.days90: rawCount(
          (c) => !c.createdAt.isBefore(now.subtract(const Duration(days: 90))),
        ),
        CreatedRange.all: raw.length,
      };
      for (final MapEntry<CreatedRange, int> e in expected.entries) {
        expect(
          computeDashboardMetrics(complaintsInRange(all, e.key, now)).total,
          e.value,
          reason: e.key.queryValue,
        );
      }
      // The seed spans a month, so the range really bites.
      expect(expected[CreatedRange.days7], 18);
      expect(expected[CreatedRange.days7]!, lessThan(raw.length));
    });

    test(
      'the window edge: exactly N days old is in, a moment older is out',
      () {
        final DateTime edge = now.subtract(const Duration(days: 7));
        expect(CreatedRange.days7.contains(edge, now), isTrue);
        expect(
          CreatedRange.days7.contains(
            edge.subtract(const Duration(milliseconds: 1)),
            now,
          ),
          isFalse,
        );
        expect(CreatedRange.all.contains(DateTime.utc(2000), now), isTrue);
      },
    );

    test('query values round-trip', () {
      for (final CreatedRange r in CreatedRange.values) {
        expect(CreatedRange.fromQueryValue(r.queryValue), r);
      }
      expect(CreatedRange.fromQueryValue('1y'), isNull);
      expect(CreatedRange.fromQueryValue(null), isNull);
      expect(
        <String>[
          for (final CreatedRange r in CreatedRange.values) r.queryValue,
        ],
        <String>['7d', '30d', '90d', 'all'],
      );
    });
  });

  group('lists', () {
    test('Awaiting manual triage = reviewed and no assignment', () {
      final DashboardList l = awaitingTriageOf(all);
      final Set<String> expected = <String>{
        for (final Complaint c in raw)
          if (c.status == ComplaintStatus.reviewed && c.assignment == null)
            c.id,
      };
      expect(expected, isNotEmpty);
      expect(l.total, expected.length);
      expect(l.rows.map((c) => c.id).toSet(), expected);
      for (final PublicComplaintView c in l.rows) {
        expect(c.status, ComplaintStatus.reviewed);
        expect(c.assignedDepartment, isNull);
      }
    });

    test('Needs attention: unresolved Critical / High, heaviest first then '
        'oldest', () {
      final DashboardList l = needsAttentionOf(all);
      expect(l.total, 9);
      expect(l.rows.length, kDashboardListSize);
      for (final PublicComplaintView c in l.rows) {
        expect(unresolved(c.status), isTrue);
        expect(
          c.effectivePriority == Priority.critical ||
              c.effectivePriority == Priority.high,
          isTrue,
        );
      }
      for (int i = 1; i < l.rows.length; i++) {
        final PublicComplaintView a = l.rows[i - 1];
        final PublicComplaintView b = l.rows[i];
        final int byWeight = b.effectivePriority.weight.compareTo(
          a.effectivePriority.weight,
        );
        expect(byWeight, lessThanOrEqualTo(0));
        if (byWeight == 0) {
          expect(a.createdAt.isAfter(b.createdAt), isFalse);
        }
      }
    });

    test('Oldest unresolved: every unresolved complaint, oldest first', () {
      final DashboardList l = oldestUnresolvedOf(all);
      expect(l.total, rawCount((c) => unresolved(c.status)));
      expect(l.rows.length, kDashboardListSize);
      for (int i = 1; i < l.rows.length; i++) {
        expect(l.rows[i - 1].createdAt.isAfter(l.rows[i].createdAt), isFalse);
      }
      final DateTime oldest = <DateTime>[
        for (final Complaint c in raw)
          if (unresolved(c.status)) c.createdAt,
      ].reduce((a, b) => a.isBefore(b) ? a : b);
      expect(l.rows.first.createdAt, oldest);
    });

    test('lists show at most five rows but report the full total', () {
      final DateTime t = DateTime.utc(2026, 10, 1);
      final List<PublicComplaintView> many = <PublicComplaintView>[
        for (int i = 0; i < 8; i++)
          viewOf(
            id: 'CF-$i',
            status: ComplaintStatus.reviewed,
            priority: Priority.high,
            createdAt: t.add(Duration(hours: i)),
          ),
      ];
      expect(awaitingTriageOf(many).rows.length, 5);
      expect(awaitingTriageOf(many).total, 8);
      expect(needsAttentionOf(many).total, 8);
      // Same weight: oldest first, the ID breaks exact ties.
      expect(awaitingTriageOf(many).rows.first.id, 'CF-0');
    });

    test('lists follow the range', () {
      final List<PublicComplaintView> week = complaintsInRange(
        all,
        CreatedRange.days7,
        now,
      );
      expect(oldestUnresolvedOf(week).total, 14);
      expect(needsAttentionOf(week).total, 6);
      expect(awaitingTriageOf(week).total, 3);
    });
  });

  group('intake per day', () {
    test('14 calendar days ending today, oldest first, on the seed', () {
      final List<IntakeDay> days = intakePerDay(all, now);
      expect(days.length, kIntakeDays);
      expect(days.last.day, DateTime.utc(2026, 10, 6));
      expect(days.first.day, DateTime.utc(2026, 9, 23));
      for (int i = 1; i < days.length; i++) {
        expect(
          days[i].day.difference(days[i - 1].day),
          const Duration(days: 1),
        );
      }
      // Counted independently by createdAt calendar day.
      for (final IntakeDay d in days) {
        expect(
          d.count,
          rawCount(
            (c) =>
                c.createdAt.toUtc().year == d.day.year &&
                c.createdAt.toUtc().month == d.day.month &&
                c.createdAt.toUtc().day == d.day.day,
          ),
          reason: '${d.day}',
        );
      }
    });

    test('only complaints inside the 14 days count', () {
      final DateTime today = DateTime.utc(2026, 10, 14, 15);
      final List<IntakeDay> days = intakePerDay(<PublicComplaintView>[
        viewOf(id: 'a', createdAt: DateTime.utc(2026, 10, 14, 0, 1)),
        viewOf(id: 'b', createdAt: DateTime.utc(2026, 10, 14, 23, 59)),
        viewOf(id: 'c', createdAt: DateTime.utc(2026, 10, 1, 8)),
        // 13 days before today is the first day of the window...
        viewOf(id: 'd', createdAt: DateTime.utc(2026, 10, 1, 23)),
        // ...and the day before that is out.
        viewOf(id: 'e', createdAt: DateTime.utc(2026, 9, 30, 23, 59)),
      ], today);
      expect(days.first.day, DateTime.utc(2026, 10, 1));
      expect(days.first.count, 2);
      expect(days.last.count, 2);
      expect(days.fold<int>(0, (a, d) => a + d.count), 4);
    });

    test('is not narrowed by the date range', () {
      // The provider feeds the intake from every complaint, not the range.
      final int inWindow = intakePerDay(
        all,
        now,
      ).fold<int>(0, (a, d) => a + d.count);
      final int inWeek = intakePerDay(
        complaintsInRange(all, CreatedRange.days7, now),
        now,
      ).fold<int>(0, (a, d) => a + d.count);
      expect(inWindow, greaterThan(inWeek));
    });

    test('an empty set is fourteen zero days', () {
      final List<IntakeDay> days = intakePerDay(const [], now);
      expect(days.length, 14);
      expect(days.every((d) => d.count == 0), isTrue);
    });
  });

  group('derived providers', () {
    test('follow the range provider', () async {
      final ProviderContainer container = testContainer();
      await container
          .read(sessionProvider.notifier)
          .signIn(
            demoAccount(UserRole.admin).user.idNumber,
            demoAccount(UserRole.admin).password,
          );
      final DashboardMetrics allM = await settled(
        container,
        dashboardMetricsProvider,
      );
      expect(allM.total, 29);

      container
          .read(dashboardRangeProvider.notifier)
          .select(CreatedRange.days7);
      final DashboardMetrics weekM = await settled(
        container,
        dashboardMetricsProvider,
      );
      expect(weekM.total, 18);
      expect(weekM.partitionHolds, isTrue);
    });

    test('the range defaults to All', () {
      expect(testContainer().read(dashboardRangeProvider), CreatedRange.all);
    });
  });

  group('A-03 query contract (complaintsPathWith)', () {
    test('the canonical keys', () {
      expect(
        <String>[
          kQueryStatus,
          kQueryPriority,
          kQueryCategory,
          kQueryDepartment,
          kQueryBuilding,
          kQuerySearch,
          kQueryUnresolved,
          kQueryTriage,
          kQueryCreated,
        ],
        <String>[
          'status',
          'priority',
          'category',
          'department',
          'building',
          'q',
          'unresolved',
          'triage',
          'created',
        ],
      );
      expect(kQueryFlagOn, '1');
      expect(kUnassignedDepartment, 'unassigned');
    });

    test('no filter is the bare list path', () {
      expect(complaintsPathWith(), '/complaints');
    });

    test('Critical / High lands on exactly the counted set (AC-47)', () {
      expect(
        complaintsPathWith(
          unresolved: true,
          priorities: const <Priority>[Priority.critical, Priority.high],
          created: CreatedRange.all,
        ),
        '/complaints?unresolved=1&priority=critical,high&created=all',
      );
    });

    test('CSV values keep commas; the order is canonical, not call order', () {
      expect(
        complaintsPathWith(
          created: CreatedRange.days30,
          triage: true,
          statuses: const <ComplaintStatus>[
            ComplaintStatus.reported,
            ComplaintStatus.reviewed,
          ],
          categories: const <ProblemCategory>[ProblemCategory.it],
          departments: const <Department>[Department.electrician],
          includeUnassigned: true,
        ),
        '/complaints?triage=1&status=reported,reviewed&category=it'
        '&department=electrician,unassigned&created=30d',
      );
    });

    test('free text is percent-encoded; empty text is dropped', () {
      expect(
        complaintsPathWith(building: 'Block A & B', search: 'leak? now'),
        '/complaints?building=Block+A+%26+B&q=leak%3F+now',
      );
      expect(complaintsPathWith(building: '', search: ''), '/complaints');
    });

    test('no key can carry an identity (PV-5)', () {
      final String path = complaintsPathWith(
        statuses: ComplaintStatus.values,
        priorities: Priority.values,
        categories: ProblemCategory.values,
        departments: Department.values,
        includeUnassigned: true,
        building: 'b',
        search: 'q',
        unresolved: true,
        triage: true,
        created: CreatedRange.days7,
      );
      final Set<String> keys = Uri.parse(path).queryParameters.keys.toSet();
      expect(keys, <String>{
        'status',
        'priority',
        'category',
        'department',
        'building',
        'q',
        'unresolved',
        'triage',
        'created',
      });
      expect(
        keys.where(
          (k) => RegExp(
            r'reporter|assignee|actor|user|owner|name',
            caseSensitive: false,
          ).hasMatch(k),
        ),
        isEmpty,
      );
    });
  });
}
