import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart'
    show ComplaintTableColumn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/list_fixtures.dart';
import 'support/pump_app.dart';
import 'support/settled.dart';

/// The pure side of the complaint list (A-03): the filter model and its URL
/// round trip, the AND of the facets (AC-49), the default and column sorts
/// (AC-50), pagination and the list query, plus the ties to the dashboard that
/// make a preset land on exactly the counted set (AC-47).
void main() {
  final DateTime now = testSeed.now; // 2026-10-06 09:00 UTC
  final List<PublicComplaintView> all = toPublicViews(testSeed.complaints);

  Set<String> ids(Iterable<PublicComplaintView> views) => <String>{
    for (final PublicComplaintView v in views) v.id,
  };
  List<String> idList(Iterable<PublicComplaintView> views) => <String>[
    for (final PublicComplaintView v in views) v.id,
  ];
  ComplaintFilter parse(String query) => ComplaintFilter.fromQuery(
    Uri.parse('/complaints?$query').queryParameters,
  );
  List<PublicComplaintView> filtered(ComplaintFilter f) =>
      applyComplaintFilter(all, f, now);
  Set<String> idsWhere(bool Function(PublicComplaintView v) test) =>
      ids(all.where(test));
  // The public text a search may match, lower-cased.
  String hay(PublicComplaintView v) =>
      '${v.id} ${v.description} ${v.building} ${v.floor} ${v.room}'
          .toLowerCase();

  group('ComplaintFilter: the model', () {
    test('the default filter is empty and writes the bare path', () {
      const ComplaintFilter f = ComplaintFilter();
      expect(f.isEmpty, isTrue);
      expect(f.hasAnyFilter, isFalse);
      expect(f.path, '/complaints');
      expect(f.toQuery(), isEmpty);
      expect(ComplaintFilter.fromQuery(const <String, String>{}), f);
      expect(filtered(f), hasLength(29), reason: 'no filter holds everything');
    });

    test('every facet counts as a filter (it lights Reset filters)', () {
      for (final ComplaintFilter f in <ComplaintFilter>[
        const ComplaintFilter(
          statuses: <ComplaintStatus>{ComplaintStatus.closed},
        ),
        const ComplaintFilter(priorities: <Priority>{Priority.low}),
        const ComplaintFilter(
          categories: <ProblemCategory>{ProblemCategory.it},
        ),
        const ComplaintFilter(departments: <Department>{Department.plumber}),
        const ComplaintFilter(includeUnassigned: true),
        const ComplaintFilter(building: 'Central Library'),
        const ComplaintFilter(search: 'leak'),
        const ComplaintFilter(unresolvedOnly: true),
        const ComplaintFilter(needsTriage: true),
        const ComplaintFilter(created: CreatedRange.days7),
      ]) {
        expect(f.hasAnyFilter, isTrue, reason: '$f');
        expect(f.isEmpty, isFalse, reason: '$f');
      }
    });

    test('equality and hash ignore the order the sets were built in', () {
      final ComplaintFilter a = const ComplaintFilter().copyWith(
        statuses: <ComplaintStatus>{
          ComplaintStatus.reviewed,
          ComplaintStatus.reported,
        },
      );
      final ComplaintFilter b = const ComplaintFilter().copyWith(
        statuses: <ComplaintStatus>{
          ComplaintStatus.reported,
          ComplaintStatus.reviewed,
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const ComplaintFilter()));
    });

    test('copyWith trims, and a blank text or clear* removes the facet', () {
      final ComplaintFilter f = const ComplaintFilter().copyWith(
        building: '  Central Library ',
        search: ' leak  ',
      );
      expect(f.building, 'Central Library');
      expect(f.search, 'leak');
      expect(f.copyWith(search: '   ').search, isNull);
      expect(f.copyWith(clearBuilding: true).building, isNull);
      expect(f.copyWith(clearSearch: true).search, isNull);
      expect(f.copyWith(unresolvedOnly: true).search, 'leak');
    });
  });

  group('ComplaintFilter: the URL query', () {
    test('reads every canonical key', () {
      final ComplaintFilter f = parse(
        'unresolved=1&triage=1&status=reported,reviewed&priority=critical,high'
        '&category=it,safety&department=electrician,unassigned'
        '&building=Block+A+%26+B&q=leak+now&created=30d',
      );
      expect(f.unresolvedOnly, isTrue);
      expect(f.needsTriage, isTrue);
      expect(f.statuses, <ComplaintStatus>{
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
      });
      expect(f.priorities, <Priority>{Priority.critical, Priority.high});
      expect(f.categories, <ProblemCategory>{
        ProblemCategory.it,
        ProblemCategory.safety,
      });
      expect(f.departments, <Department>{Department.electrician});
      expect(f.includeUnassigned, isTrue);
      expect(f.building, 'Block A & B');
      expect(f.search, 'leak now');
      expect(f.created, CreatedRange.days30);
    });

    test('is tolerant of a hand-edited address', () {
      final ComplaintFilter f = parse(
        'status=reported,bogus,,reported&priority=urgent&category=&created=1y'
        '&unresolved=yes&triage=true&building=%20&q=%20%20&department=nobody'
        '&reporter=Asha&assignee=u-1',
      );
      expect(f.statuses, <ComplaintStatus>{ComplaintStatus.reported});
      expect(f.priorities, isEmpty);
      expect(f.categories, isEmpty);
      expect(f.created, CreatedRange.all);
      expect(f.unresolvedOnly, isFalse, reason: 'a toggle is on only for 1');
      expect(f.needsTriage, isFalse);
      expect(f.building, isNull);
      expect(f.search, isNull);
      expect(f.departments, isEmpty);
      expect(f.includeUnassigned, isFalse);
      // Unknown keys (an attempt to filter by a person) are never read back.
      expect(f.path, '/complaints?status=reported&created=all');
    });

    test('writes the canonical order whatever order it was read in', () {
      final ComplaintFilter f = parse(
        'created=7d&q=leak&department=unassigned,plumber&category=it'
        '&priority=high,critical&status=reviewed,reported&triage=1&unresolved=1',
      );
      expect(
        f.path,
        '/complaints?unresolved=1&triage=1&status=reported,reviewed'
        '&priority=critical,high&category=it&department=plumber,unassigned'
        '&q=leak&created=7d',
      );
      expect(f.toQuery().keys, <String>[
        'unresolved',
        'triage',
        'status',
        'priority',
        'category',
        'department',
        'q',
        'created',
      ]);
    });

    test(
      'toQuery then fromQuery is the same filter (all facets, odd text)',
      () {
        final ComplaintFilter f = ComplaintFilter(
          statuses: ComplaintStatus.values.toSet(),
          priorities: Priority.values.toSet(),
          categories: ProblemCategory.values.toSet(),
          departments: Department.values.toSet(),
          includeUnassigned: true,
          building: 'Block A & B, "East" wing',
          search: 'leak? 100% + more',
          unresolvedOnly: true,
          needsTriage: true,
          created: CreatedRange.days90,
        );
        expect(ComplaintFilter.fromQuery(f.toQuery()), f);
        expect(ComplaintFilter.fromQuery(f.toQuery()).path, f.path);
        // And through the actual address string.
        expect(ComplaintFilter.fromQuery(Uri.parse(f.path).queryParameters), f);
      },
    );

    test(
      'the range is written whenever a filter is on, like the dashboard',
      () {
        expect(
          const ComplaintFilter(unresolvedOnly: true).path,
          '/complaints?unresolved=1&created=all',
        );
        expect(
          const ComplaintFilter(created: CreatedRange.days7).path,
          '/complaints?created=7d',
        );
        // `created=all` alone selects nothing, so it is the bare list.
        expect(parse('created=all').isEmpty, isTrue);
        expect(parse('created=all').path, '/complaints');
      },
    );

    test('only filter values travel: no key can name a person (PV-5)', () {
      final ComplaintFilter f = ComplaintFilter(
        statuses: ComplaintStatus.values.toSet(),
        priorities: Priority.values.toSet(),
        categories: ProblemCategory.values.toSet(),
        departments: Department.values.toSet(),
        includeUnassigned: true,
        building: 'b',
        search: 'q',
        unresolvedOnly: true,
        needsTriage: true,
        created: CreatedRange.days7,
      );
      expect(f.toQuery().keys.toSet(), <String>{
        kQueryStatus,
        kQueryPriority,
        kQueryCategory,
        kQueryDepartment,
        kQueryBuilding,
        kQuerySearch,
        kQueryUnresolved,
        kQueryTriage,
        kQueryCreated,
      });
      expect(
        f.toQuery().keys.where(
          (k) => RegExp(
            r'reporter|assignee|actor|user|owner|name',
            caseSensitive: false,
          ).hasMatch(k),
        ),
        isEmpty,
      );
    });

    /// Every URL the dashboard builds (cards, chart bars, "View all"), at the
    /// ranges it offers. Each must come back from the list byte for byte.
    final List<String> dashboardPresets = <String>[
      for (final String r in <String>['all', '7d', '30d', '90d']) ...<String>[
        '/complaints?unresolved=1&priority=critical,high&created=$r',
        '/complaints?status=reported,reviewed&created=$r',
        '/complaints?status=assigned&created=$r',
        '/complaints?status=inProgress&created=$r',
        '/complaints?status=resolved,verified&created=$r',
        '/complaints?status=closed&created=$r',
        '/complaints?status=resolved&created=$r',
        '/complaints?unresolved=1&created=$r',
        '/complaints?triage=1&created=$r',
        '/complaints?unresolved=1&priority=low&created=$r',
        '/complaints?unresolved=1&category=safety&created=$r',
        '/complaints?status=verified&created=$r',
      ],
      '/complaints?created=7d',
      '/complaints?created=30d',
      '/complaints?created=90d',
    ];

    test('every dashboard preset round-trips unchanged (AC-47)', () {
      for (final String url in dashboardPresets) {
        final ComplaintFilter f = ComplaintFilter.fromQuery(
          Uri.parse(url).queryParameters,
        );
        expect(f.path, url, reason: url);
        expect(f.toQuery(), Uri.parse(url).queryParameters, reason: url);
        // Stable: reading what it wrote changes nothing.
        expect(ComplaintFilter.fromQuery(f.toQuery()), f, reason: url);
      }
    });

    test('presets built by complaintsPathWith parse back to their filter', () {
      for (final CreatedRange range in CreatedRange.values) {
        final String url = complaintsPathWith(
          unresolved: true,
          priorities: const <Priority>[Priority.critical, Priority.high],
          created: range,
        );
        final ComplaintFilter f = ComplaintFilter.fromQuery(
          Uri.parse(url).queryParameters,
        );
        expect(f.unresolvedOnly, isTrue, reason: url);
        expect(f.priorities, <Priority>{Priority.critical, Priority.high});
        expect(f.created, range, reason: url);
        expect(f.path, url);
      }
    });
  });

  group('AC-49: each filter narrows, and the filters AND together', () {
    test('Status: any of the chosen statuses', () {
      expect(
        ids(filtered(parse('status=reported'))),
        idsWhere((v) => v.status == ComplaintStatus.reported),
      );
      final Set<String> two = ids(filtered(parse('status=reported,reviewed')));
      expect(two, hasLength(7));
      expect(
        two,
        idsWhere(
          (v) =>
              v.status == ComplaintStatus.reported ||
              v.status == ComplaintStatus.reviewed,
        ),
      );
    });

    test('Priority is the effective priority: any of the chosen', () {
      expect(ids(filtered(parse('priority=critical'))), hasLength(4));
      expect(
        ids(filtered(parse('priority=critical,low'))),
        idsWhere(
          (v) =>
              v.effectivePriority == Priority.critical ||
              v.effectivePriority == Priority.low,
        ),
      );
    });

    test('Category: any of the chosen', () {
      expect(
        ids(filtered(parse('category=it'))),
        idsWhere((v) => v.category == ProblemCategory.it),
      );
      expect(
        ids(filtered(parse('category=safety,other'))),
        idsWhere(
          (v) =>
              v.category == ProblemCategory.safety ||
              v.category == ProblemCategory.other,
        ),
      );
    });

    test('Department: chosen ones, Unassigned, or both', () {
      expect(
        ids(filtered(parse('department=electrician'))),
        idsWhere((v) => v.assignedDepartment == Department.electrician),
      );
      final Set<String> unassigned = ids(
        filtered(parse('department=unassigned')),
      );
      expect(unassigned, idsWhere((v) => v.assignedDepartment == null));
      expect(unassigned, hasLength(7));
      expect(
        ids(filtered(parse('department=electrician,unassigned'))),
        idsWhere(
          (v) =>
              v.assignedDepartment == null ||
              v.assignedDepartment == Department.electrician,
        ),
      );
    });

    test('Building: exact name, any case', () {
      final Set<String> library = idsWhere(
        (v) => v.building == 'Central Library',
      );
      expect(library, isNotEmpty);
      expect(ids(filtered(parse('building=Central+Library'))), library);
      expect(ids(filtered(parse('building=central+LIBRARY'))), library);
      expect(
        ids(filtered(parse('building=Library'))),
        isEmpty,
        reason: 'a building is chosen by its whole name',
      );
    });

    test('Created range: by createdAt, counted back from now', () {
      for (final CreatedRange r in CreatedRange.values) {
        expect(
          ids(filtered(ComplaintFilter(created: r))),
          idsWhere((v) => r.contains(v.createdAt, now)),
          reason: r.label,
        );
      }
      final Set<String> last7 = ids(
        filtered(const ComplaintFilter(created: CreatedRange.days7)),
      );
      final Set<String> last30 = ids(
        filtered(const ComplaintFilter(created: CreatedRange.days30)),
      );
      expect(last7.length, lessThan(last30.length));
      expect(last30.containsAll(last7), isTrue);
      expect(
        ids(filtered(const ComplaintFilter(created: CreatedRange.all))),
        hasLength(29),
      );
    });

    test('Unresolved only: reported, reviewed, assigned, in progress', () {
      final Set<String> unresolved = ids(filtered(parse('unresolved=1')));
      expect(unresolved, hasLength(17));
      expect(
        unresolved,
        idsWhere(
          (v) => const <ComplaintStatus>{
            ComplaintStatus.reported,
            ComplaintStatus.reviewed,
            ComplaintStatus.assigned,
            ComplaintStatus.inProgress,
          }.contains(v.status),
        ),
      );
    });

    test('Needs manual triage: reviewed with no department', () {
      final Set<String> triage = ids(filtered(parse('triage=1')));
      expect(
        triage,
        idsWhere(
          (v) =>
              v.status == ComplaintStatus.reviewed &&
              v.assignedDepartment == null,
        ),
      );
      expect(triage, <String>{
        'CF-2026-00023',
        'CF-2026-00024',
        'CF-2026-00026',
      });
    });

    test('Search: ID, description and location, any case, every word', () {
      // ID.
      expect(ids(filtered(parse('q=cf-2026-00012'))), <String>{
        'CF-2026-00012',
      });
      expect(ids(filtered(parse('q=00012'))), <String>{'CF-2026-00012'});
      // Description.
      expect(ids(filtered(parse('q=WI-FI'))), <String>{'CF-2026-00012'});
      final Set<String> projector = ids(filtered(parse('q=projector')));
      expect(projector, isNotEmpty);
      expect(projector, idsWhere((v) => hay(v).contains('projector')));
      // Location: building, floor and room, several words at once.
      final Set<String> lab = ids(filtered(parse('q=computer+lab+1')));
      expect(lab, isNotEmpty);
      expect(
        lab,
        idsWhere(
          (v) =>
              hay(v).contains('computer') &&
              hay(v).contains('lab') &&
              hay(v).contains('1'),
        ),
      );
      expect(
        ids(filtered(parse('q=hostel+mess'))),
        <String>{'CF-2026-00013'},
        reason: 'every word must match, across building and room',
      );
      expect(ids(filtered(parse('q=no+such+thing+anywhere'))), isEmpty);
      // A blank search is no search.
      expect(filtered(parse('q=%20')), hasLength(29));
    });

    test('search never reads a person: only public fields are matched', () {
      for (final Complaint c in testSeed.complaints) {
        final ReporterIdentity r = c.reporter;
        // E-mail addresses and ID numbers occur in no public field.
        for (final String needle in <String>[r.email, r.idNumber, r.userId]) {
          expect(
            filtered(ComplaintFilter(search: needle)),
            isEmpty,
            reason: 'searching "$needle" must find nobody',
          );
        }
        // A name finds a complaint only through a public word, never through
        // the reporter.
        final List<PublicComplaintView> hits = filtered(
          ComplaintFilter(search: r.fullName),
        );
        for (final PublicComplaintView v in hits) {
          for (final String word in r.fullName.toLowerCase().split(' ')) {
            expect(hay(v), contains(word), reason: r.fullName);
          }
        }
      }
    });

    test('facets AND: status, priority, category, department, building, '
        'search, toggles and range, each one narrowing further', () {
      final List<(String, ComplaintFilter)> steps = <(String, ComplaintFilter)>[
        ('range 90d', const ComplaintFilter(created: CreatedRange.days90)),
      ];
      ComplaintFilter f = steps.first.$2;
      f = f.copyWith(unresolvedOnly: true);
      steps.add(('+ unresolved', f));
      f = f.copyWith(
        statuses: <ComplaintStatus>{
          ComplaintStatus.assigned,
          ComplaintStatus.inProgress,
        },
      );
      steps.add(('+ status', f));
      f = f.copyWith(priorities: <Priority>{Priority.high, Priority.critical});
      steps.add(('+ priority', f));
      f = f.copyWith(
        categories: <ProblemCategory>{
          ProblemCategory.it,
          ProblemCategory.cleanliness,
        },
      );
      steps.add(('+ category', f));
      f = f.copyWith(
        departments: <Department>{Department.itTeam},
        includeUnassigned: false,
      );
      steps.add(('+ department', f));
      f = f.copyWith(building: 'Science & Computer Block');
      steps.add(('+ building', f));
      f = f.copyWith(search: 'erp');
      steps.add(('+ search', f));

      int previous = 29;
      for (final (String name, ComplaintFilter filter) in steps) {
        final List<PublicComplaintView> hits = filtered(filter);
        expect(hits.length, lessThanOrEqualTo(previous), reason: name);
        previous = hits.length;
        // Every hit satisfies every facet that is on (checked independently).
        for (final PublicComplaintView v in hits) {
          if (filter.statuses.isNotEmpty) {
            expect(filter.statuses, contains(v.status), reason: name);
          }
          if (filter.priorities.isNotEmpty) {
            expect(filter.priorities, contains(v.effectivePriority));
          }
          if (filter.categories.isNotEmpty) {
            expect(filter.categories, contains(v.category));
          }
          if (filter.departments.isNotEmpty) {
            expect(filter.departments, contains(v.assignedDepartment));
          }
          if (filter.building != null) expect(v.building, filter.building);
          if (filter.unresolvedOnly) {
            expect(v.status.order, lessThan(ComplaintStatus.resolved.order));
          }
          expect(filter.created.contains(v.createdAt, now), isTrue);
        }
      }
      // The whole chain ends on the one complaint that satisfies all of it.
      expect(idList(filtered(steps.last.$2)), <String>['CF-2026-00019']);
      // Dropping a facet never narrows the result; priority and search are
      // what keep the (Medium) PCs in the lab out of it.
      final ComplaintFilter full = steps.last.$2;
      for (final ComplaintFilter wider in <ComplaintFilter>[
        full.copyWith(clearSearch: true),
        full.copyWith(clearBuilding: true),
        full.copyWith(departments: <Department>{}),
        full.copyWith(categories: <ProblemCategory>{}),
        full.copyWith(priorities: <Priority>{}),
        full.copyWith(statuses: <ComplaintStatus>{}),
        full.copyWith(unresolvedOnly: false),
        full.copyWith(created: CreatedRange.all),
      ]) {
        expect(ids(filtered(wider)).contains('CF-2026-00019'), isTrue);
      }
      expect(
        ids(
          filtered(full.copyWith(priorities: <Priority>{}, clearSearch: true)),
        ),
        containsAll(<String>['CF-2026-00019', 'CF-2026-00017']),
      );
    });

    test('the two toggles AND with each other and with the facets', () {
      // Needs triage implies unresolved, so the pair equals the single toggle.
      expect(
        ids(filtered(parse('unresolved=1&triage=1'))),
        ids(filtered(parse('triage=1'))),
      );
      // Triage AND Critical priority: the one critical safety complaint.
      expect(ids(filtered(parse('triage=1&priority=critical'))), <String>{
        'CF-2026-00026',
      });
      // Contradictory facets give nothing, not everything.
      expect(
        filtered(parse('triage=1&status=closed')),
        isEmpty,
        reason: 'closed complaints never await triage',
      );
      expect(filtered(parse('unresolved=1&status=closed')), isEmpty);
      expect(filtered(parse('triage=1&department=electrician')), isEmpty);
    });

    test('Unassigned AND a department facet that excludes it', () {
      expect(
        ids(filtered(parse('department=unassigned&status=closed'))),
        isEmpty,
      );
      expect(
        ids(filtered(parse('department=unassigned&status=reported'))),
        idsWhere(
          (v) =>
              v.assignedDepartment == null &&
              v.status == ComplaintStatus.reported,
        ),
      );
    });

    test('filtering keeps the order it is given and never changes a view', () {
      final List<PublicComplaintView> before = List<PublicComplaintView>.of(
        all,
      );
      final List<PublicComplaintView> hits = filtered(parse('unresolved=1'));
      expect(idList(hits), idList(all.where((v) => ids(hits).contains(v.id))));
      expect(all, before);
    });
  });

  group('AC-47: a dashboard preset selects exactly the counted set', () {
    test('Critical / High: the 9 complaints the card counted', () {
      final ComplaintFilter f = parse(
        'unresolved=1&priority=critical,high&created=all',
      );
      final List<PublicComplaintView> hits = filtered(f);
      expect(hits, hasLength(9));
      expect(hits.length, computeDashboardMetrics(all).criticalHigh);
      // Not just the same number: the same complaints as the dashboard's own
      // "Needs attention" list, which is built from the card's definition.
      expect(ids(hits), ids(needsAttentionOf(all, limit: all.length).rows));
      for (final PublicComplaintView v in hits) {
        expect(isUnresolvedStatus(v.status), isTrue);
        expect(isCriticalOrHigh(v.effectivePriority), isTrue);
      }
    });

    test('every card preset matches its card, at every range', () {
      for (final CreatedRange r in CreatedRange.values) {
        final DashboardMetrics m = computeDashboardMetrics(
          complaintsInRange(all, r, now),
        );
        final Map<String, int> cards = <String, int>{
          'created=${r.queryValue}': m.total,
          'status=reported,reviewed&created=${r.queryValue}': m.pending,
          'unresolved=1&priority=critical,high&created=${r.queryValue}':
              m.criticalHigh,
          'status=assigned&created=${r.queryValue}': m.assigned,
          'status=inProgress&created=${r.queryValue}': m.inProgress,
          'status=resolved,verified&created=${r.queryValue}': m.resolved,
          'status=closed&created=${r.queryValue}': m.closed,
          'status=resolved&created=${r.queryValue}': m.awaitingVerification,
        };
        for (final MapEntry<String, int> card in cards.entries) {
          expect(
            filtered(parse(card.key)),
            hasLength(card.value),
            reason: '${card.key} (${r.label})',
          );
        }
      }
    });

    test('the "View all" presets match the dashboard lists', () {
      for (final CreatedRange r in CreatedRange.values) {
        final List<PublicComplaintView> inRange = complaintsInRange(
          all,
          r,
          now,
        );
        expect(
          ids(filtered(parse('unresolved=1&created=${r.queryValue}'))),
          ids(oldestUnresolvedOf(inRange, limit: all.length).rows),
          reason: 'oldest unresolved, ${r.label}',
        );
        expect(
          ids(filtered(parse('triage=1&created=${r.queryValue}'))),
          ids(awaitingTriageOf(inRange, limit: all.length).rows),
          reason: 'awaiting triage, ${r.label}',
        );
        expect(
          ids(
            filtered(
              parse(
                'unresolved=1&priority=critical,high&created=${r.queryValue}',
              ),
            ),
          ),
          ids(needsAttentionOf(inRange, limit: all.length).rows),
          reason: 'needs attention, ${r.label}',
        );
      }
    });

    test('a chart bar preset matches its bar', () {
      final DashboardMetrics m = computeDashboardMetrics(all);
      for (final Priority p in Priority.values) {
        expect(
          filtered(parse('unresolved=1&priority=${p.name}&created=all')),
          hasLength(m.unresolvedByPriority[p]),
          reason: p.name,
        );
      }
      for (final ProblemCategory c in ProblemCategory.values) {
        expect(
          filtered(parse('unresolved=1&category=${c.name}&created=all')),
          hasLength(m.unresolvedByCategory[c]),
          reason: c.name,
        );
      }
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(
          filtered(parse('status=${s.name}&created=all')),
          hasLength(m.byStatus[s]),
          reason: s.name,
        );
      }
    });
  });

  group('AC-50: the default sort', () {
    test('priority weight descending, then longest waiting first', () {
      final List<PublicComplaintView> sorted = sortComplaints(
        all.reversed,
        kDefaultSortColumn,
        ascending: kDefaultSortAscending,
      );
      expect(sorted, hasLength(29));
      for (int i = 1; i < sorted.length; i++) {
        final PublicComplaintView a = sorted[i - 1];
        final PublicComplaintView b = sorted[i];
        final int wa = a.effectivePriority.weight;
        final int wb = b.effectivePriority.weight;
        expect(wa, greaterThanOrEqualTo(wb), reason: '${a.id} before ${b.id}');
        if (wa == wb) {
          expect(
            a.createdAt.isAfter(b.createdAt),
            isFalse,
            reason: 'the longer-waiting ${a.id} comes before ${b.id}',
          );
        }
      }
    });

    test('the seed in that order', () {
      final List<String> order = idList(
        sortComplaints(
          all,
          kDefaultSortColumn,
          ascending: kDefaultSortAscending,
        ),
      );
      // Critical (4), oldest first.
      expect(order.take(4), <String>[
        'CF-2026-00006',
        'CF-2026-00016',
        'CF-2026-00026',
        'CF-2026-00027',
      ]);
      // Then High, oldest first; Low last (the newest Low at the very end).
      expect(order[4], 'CF-2026-00002');
      expect(order.last, 'CF-2026-00029');
    });

    test('is the default query: no sort in the address', () {
      const ComplaintListQuery q = ComplaintListQuery();
      expect(q.isDefaultSort, isTrue);
      expect(q.sortColumn, ComplaintTableColumn.priority);
      expect(q.sortAscending, isFalse);
      expect(q.path, '/complaints');
      final List<PublicComplaintView> viaPage = buildComplaintListPage(
        all,
        q,
        now,
      ).rows;
      expect(
        idList(viaPage),
        idList(all.toList()..sort(compareComplaintsByDefault)).take(25),
      );
    });

    test('equal priority and age fall back to the ID: a total order', () {
      final DateTime t = DateTime.utc(2026, 9, 1);
      final List<PublicComplaintView> same = <PublicComplaintView>[
        listView(id: 'CF-T-3', createdAt: t),
        listView(id: 'CF-T-1', createdAt: t),
        listView(id: 'CF-T-2', createdAt: t),
      ];
      expect(
        idList(
          sortComplaints(same, ComplaintTableColumn.priority, ascending: false),
        ),
        <String>['CF-T-1', 'CF-T-2', 'CF-T-3'],
      );
    });

    test('the effective priority is what counts: an overridden one sorts as '
        'its override', () {
      // The view already carries the effective priority, so a Low complaint
      // overridden to Critical is a Critical row.
      final DateTime t = DateTime.utc(2026, 9, 1);
      final List<PublicComplaintView> rows = sortComplaints(
        <PublicComplaintView>[
          listView(id: 'CF-T-1', priority: Priority.high, createdAt: t),
          listView(id: 'CF-T-2', priority: Priority.critical, createdAt: t),
        ],
        ComplaintTableColumn.priority,
        ascending: false,
      );
      expect(idList(rows), <String>['CF-T-2', 'CF-T-1']);
    });
  });

  group('sorting by a column (asc / desc)', () {
    final DateTime t = DateTime.utc(2026, 9, 1);
    final List<PublicComplaintView> rows = <PublicComplaintView>[
      listView(
        id: 'CF-T-1',
        category: ProblemCategory.plumbing,
        building: 'Hostel Block A',
        floor: '10',
        room: 'Washroom',
        priority: Priority.low,
        status: ComplaintStatus.closed,
        department: Department.plumber,
        createdAt: t,
        updatedAt: t.add(const Duration(days: 5)),
      ),
      listView(
        id: 'CF-T-2',
        category: ProblemCategory.electrical,
        building: 'Academic Block A',
        floor: 'Terrace',
        room: 'Roof',
        priority: Priority.critical,
        status: ComplaintStatus.reported,
        createdAt: t.add(const Duration(days: 1)),
        updatedAt: t.add(const Duration(days: 1)),
      ),
      listView(
        id: 'CF-T-3',
        category: ProblemCategory.it,
        building: 'Academic Block A',
        floor: '2',
        room: 'Lab',
        priority: Priority.high,
        status: ComplaintStatus.inProgress,
        department: Department.itTeam,
        createdAt: t.add(const Duration(days: 2)),
        updatedAt: t.add(const Duration(days: 3)),
      ),
      listView(
        id: 'CF-T-4',
        category: ProblemCategory.furniture,
        building: 'Academic Block A',
        floor: 'Ground',
        room: 'Hall',
        priority: Priority.medium,
        status: ComplaintStatus.verified,
        department: Department.carpenter,
        createdAt: t.add(const Duration(days: 3)),
        updatedAt: t.add(const Duration(days: 4)),
      ),
      listView(
        id: 'CF-T-5',
        category: ProblemCategory.safety,
        building: 'Academic Block A',
        floor: 'Basement',
        room: 'Store',
        priority: Priority.medium,
        status: ComplaintStatus.reviewed,
        createdAt: t.add(const Duration(days: 4)),
        updatedAt: t.add(const Duration(days: 4, hours: 1)),
      ),
    ];

    List<String> by(ComplaintTableColumn c, {required bool asc}) =>
        idList(sortComplaints(rows, c, ascending: asc));

    test('ID', () {
      expect(by(ComplaintTableColumn.id, asc: true), <String>[
        'CF-T-1', 'CF-T-2', 'CF-T-3', 'CF-T-4', 'CF-T-5', //
      ]);
      expect(by(ComplaintTableColumn.id, asc: false), <String>[
        'CF-T-5', 'CF-T-4', 'CF-T-3', 'CF-T-2', 'CF-T-1', //
      ]);
    });

    test('Category: by label', () {
      // Electrical, Furniture, IT..., Plumbing, Safety (labels, any case).
      final List<String> labels = <String>[
        for (final PublicComplaintView v in sortComplaints(
          rows,
          ComplaintTableColumn.category,
          ascending: true,
        ))
          v.category.label.toLowerCase(),
      ];
      expect(labels, <String>[...labels]..sort());
      expect(
        by(ComplaintTableColumn.category, asc: false),
        by(ComplaintTableColumn.category, asc: true).reversed.toList(),
      );
    });

    test('Location: building, then floor by height, then room', () {
      expect(by(ComplaintTableColumn.location, asc: true), <String>[
        'CF-T-5', // Academic Block A, Basement
        'CF-T-4', // Ground
        'CF-T-3', // 2
        'CF-T-2', // Terrace
        'CF-T-1', // Hostel Block A (a later building)
      ]);
      expect(by(ComplaintTableColumn.location, asc: false), <String>[
        'CF-T-1',
        'CF-T-2',
        'CF-T-3',
        'CF-T-4',
        'CF-T-5',
      ]);
    });

    test('Priority: by weight', () {
      expect(by(ComplaintTableColumn.priority, asc: true), <String>[
        'CF-T-1', // low
        'CF-T-4', // medium, older
        'CF-T-5', // medium
        'CF-T-3', // high
        'CF-T-2', // critical
      ]);
      expect(by(ComplaintTableColumn.priority, asc: false), <String>[
        'CF-T-2',
        'CF-T-3',
        'CF-T-4',
        'CF-T-5',
        'CF-T-1',
      ]);
    });

    test('Status: by lifecycle order', () {
      expect(by(ComplaintTableColumn.status, asc: true), <String>[
        'CF-T-2', // reported
        'CF-T-5', // reviewed
        'CF-T-3', // in progress
        'CF-T-4', // verified
        'CF-T-1', // closed
      ]);
      expect(by(ComplaintTableColumn.status, asc: false), <String>[
        'CF-T-1',
        'CF-T-4',
        'CF-T-3',
        'CF-T-5',
        'CF-T-2',
      ]);
    });

    test(
      'Department: by the label the column shows; Unassigned is a label',
      () {
        expect(by(ComplaintTableColumn.department, asc: true), <String>[
          'CF-T-4', // Carpenter
          'CF-T-3', // IT Team
          'CF-T-1', // Plumber
          'CF-T-2', // Unassigned (by priority: critical first)
          'CF-T-5', // Unassigned
        ]);
      },
    );

    test('Waiting: longest first when descending; "-" rows stay last', () {
      // Unresolved: 2 (day 1), 3 (day 2), 5 (day 4); resolved/closed: 1, 4.
      expect(by(ComplaintTableColumn.waiting, asc: false), <String>[
        'CF-T-2', // waited longest
        'CF-T-3',
        'CF-T-5',
        'CF-T-4', // no waiting time ("-"), by default order
        'CF-T-1',
      ]);
      expect(by(ComplaintTableColumn.waiting, asc: true), <String>[
        'CF-T-5', // waited least
        'CF-T-3',
        'CF-T-2',
        'CF-T-4', // still last in both directions
        'CF-T-1',
      ]);
    });

    test('Updated: by updatedAt', () {
      expect(by(ComplaintTableColumn.updated, asc: true), <String>[
        'CF-T-2', // day 1
        'CF-T-3', // day 3
        'CF-T-4', // day 4
        'CF-T-5', // day 4 + 1 h
        'CF-T-1', // day 5
      ]);
      expect(by(ComplaintTableColumn.updated, asc: false), <String>[
        'CF-T-1',
        'CF-T-5',
        'CF-T-4',
        'CF-T-3',
        'CF-T-2',
      ]);
    });

    test('ties inside a column keep the default order, in both directions', () {
      // CF-T-4 and CF-T-5 are both Medium: the older (4) leads either way.
      for (final bool asc in <bool>[true, false]) {
        final List<String> order = by(ComplaintTableColumn.priority, asc: asc);
        expect(
          order.indexOf('CF-T-4'),
          lessThan(order.indexOf('CF-T-5')),
          reason: 'asc=$asc',
        );
      }
    });

    test('there is no column that sorts by a person (PV-5)', () {
      expect(
        ComplaintTableColumn.values.map((c) => c.title).join(' ').toLowerCase(),
        isNot(matches(RegExp(r'reporter|name|email|phone|requester|owner'))),
      );
      expect(ComplaintTableColumn.values, hasLength(8));
    });

    test(
      'a click on a header: same column reverses, another starts ascending',
      () {
        ComplaintListQuery q = const ComplaintListQuery();
        expect(
          (q.sortColumn, q.sortAscending),
          (ComplaintTableColumn.priority, false),
        );
        q = q.sortedBy(ComplaintTableColumn.priority);
        expect(
          (q.sortColumn, q.sortAscending),
          (ComplaintTableColumn.priority, true),
        );
        q = q.sortedBy(ComplaintTableColumn.priority);
        expect(q.sortAscending, isFalse);
        expect(q.isDefaultSort, isTrue);
        q = q.sortedBy(ComplaintTableColumn.updated);
        expect(
          (q.sortColumn, q.sortAscending),
          (ComplaintTableColumn.updated, true),
        );
        q = q.sortedBy(ComplaintTableColumn.updated);
        expect(q.sortAscending, isFalse);
        q = q.sortedBy(ComplaintTableColumn.status);
        expect(
          (q.sortColumn, q.sortAscending),
          (ComplaintTableColumn.status, true),
        );
      },
    );

    test('sorting does not touch its input', () {
      final List<String> before = idList(rows);
      sortComplaints(rows, ComplaintTableColumn.updated, ascending: false);
      expect(idList(rows), before);
    });
  });

  group('pagination (25 / 50)', () {
    final List<PublicComplaintView> sixty = manyViews(60);

    test('25 per page: the pages, the totals, the last short page', () {
      ComplaintListPage page(int p, {int size = 25}) => buildComplaintListPage(
        sixty,
        ComplaintListQuery(page: p, rowsPerPage: size),
        now,
      );
      expect(page(0).rows, hasLength(25));
      expect(page(1).rows, hasLength(25));
      expect(page(2).rows, hasLength(10));
      expect(page(0).totalCount, 60);
      expect(page(0).allCount, 60);
      expect(page(0).pageCount, 3);
      // Pages are disjoint and cover everything, in order.
      final List<String> seen = <String>[
        ...idList(page(0).rows),
        ...idList(page(1).rows),
        ...idList(page(2).rows),
      ];
      expect(seen, hasLength(60));
      expect(seen.toSet(), hasLength(60));
      expect(seen, idList(sixty.toList()..sort(compareComplaintsByDefault)));
    });

    test('50 per page', () {
      final ComplaintListPage p0 = buildComplaintListPage(
        sixty,
        const ComplaintListQuery(rowsPerPage: 50),
        now,
      );
      expect(p0.rows, hasLength(50));
      expect(p0.pageCount, 2);
      expect(
        buildComplaintListPage(
          sixty,
          const ComplaintListQuery(page: 1, rowsPerPage: 50),
          now,
        ).rows,
        hasLength(10),
      );
    });

    test(
      'a page past the end shows the last page; a negative one the first',
      () {
        final ComplaintListPage far = buildComplaintListPage(
          sixty,
          const ComplaintListQuery(page: 99),
          now,
        );
        expect(far.page, 2);
        expect(far.rows, hasLength(10));
        expect(
          buildComplaintListPage(
            sixty,
            const ComplaintListQuery(page: -4),
            now,
          ).page,
          0,
        );
      },
    );

    test('the numbers behind the footer, page counts at the edges', () {
      expect(pageCountOf(0, 25), 1);
      expect(pageCountOf(1, 25), 1);
      expect(pageCountOf(25, 25), 1);
      expect(pageCountOf(26, 25), 2);
      expect(pageCountOf(50, 25), 2);
      expect(pageCountOf(51, 25), 3);
      expect(pageCountOf(51, 50), 2);
      expect(kRowsPerPageOptions, <int>[25, 50]);
    });

    test('a short list is one page; an empty one has an empty first page', () {
      final ComplaintListPage few = buildComplaintListPage(
        manyViews(7),
        const ComplaintListQuery(),
        now,
      );
      expect((few.rows.length, few.pageCount, few.page), (7, 1, 0));
      final ComplaintListPage none = buildComplaintListPage(
        const <PublicComplaintView>[],
        const ComplaintListQuery(),
        now,
      );
      expect(none.rows, isEmpty);
      expect((none.totalCount, none.pageCount, none.page), (0, 1, 0));
      expect(none.isEmpty, isTrue);
      expect(none.isFilteredEmpty, isFalse);
    });

    test('empty vs filtered-empty', () {
      final ComplaintListPage filteredOut = buildComplaintListPage(
        all,
        ComplaintListQuery(filter: parse('q=no+such+thing+anywhere')),
        now,
      );
      expect(filteredOut.rows, isEmpty);
      expect(filteredOut.totalCount, 0);
      expect(filteredOut.allCount, 29);
      expect(filteredOut.isEmpty, isFalse);
      expect(filteredOut.isFilteredEmpty, isTrue);
    });

    test('the filter runs before the page: totals count the filtered list', () {
      final ComplaintListPage p = buildComplaintListPage(
        all,
        ComplaintListQuery(filter: parse('unresolved=1')),
        now,
      );
      expect(p.totalCount, 17);
      expect(p.rows, hasLength(17));
      expect(p.allCount, 29);
    });

    test('the page is immutable and carries the clock it was measured at', () {
      final ComplaintListPage p = buildComplaintListPage(
        all,
        const ComplaintListQuery(),
        now,
      );
      expect(p.now, now);
      expect(() => p.rows.add(all.first), throwsUnsupportedError);
    });
  });

  group('ComplaintListQuery: the whole view in the address', () {
    ComplaintListQuery parseView(String query) => ComplaintListQuery.fromQuery(
      Uri.parse('/complaints?$query').queryParameters,
    );

    test('the default view is the bare path', () {
      expect(const ComplaintListQuery().path, '/complaints');
      expect(parseView('').path, '/complaints');
      expect(parseView(''), const ComplaintListQuery());
    });

    test(
      'sort, page and size are written only when they are not the default',
      () {
        expect(
          const ComplaintListQuery(
            sortColumn: ComplaintTableColumn.updated,
            sortAscending: true,
          ).path,
          '/complaints?sort=updated&dir=asc',
        );
        expect(
          const ComplaintListQuery(
            sortColumn: ComplaintTableColumn.priority,
            sortAscending: true,
          ).path,
          '/complaints?sort=priority&dir=asc',
        );
        expect(const ComplaintListQuery(page: 2).path, '/complaints?page=3');
        expect(
          const ComplaintListQuery(rowsPerPage: 50).path,
          '/complaints?size=50',
        );
        expect(
          ComplaintListQuery(
            filter: parse('unresolved=1&priority=critical,high&created=all'),
            sortColumn: ComplaintTableColumn.waiting,
            sortAscending: false,
            page: 1,
            rowsPerPage: 50,
          ).path,
          '/complaints?unresolved=1&priority=critical,high&created=all'
          '&sort=waiting&dir=desc&page=2&size=50',
        );
      },
    );

    test('a view round-trips through its address', () {
      for (final ComplaintListQuery q in <ComplaintListQuery>[
        const ComplaintListQuery(),
        ComplaintListQuery(
          filter: parse('triage=1&q=leak&created=7d'),
          sortColumn: ComplaintTableColumn.location,
          sortAscending: true,
          page: 3,
          rowsPerPage: 50,
        ),
        const ComplaintListQuery(
          sortColumn: ComplaintTableColumn.department,
          sortAscending: false,
        ),
      ]) {
        expect(
          ComplaintListQuery.fromQuery(Uri.parse(q.path).queryParameters),
          q,
          reason: q.path,
        );
        expect(
          ComplaintListQuery.fromQuery(q.toQuery()).path,
          q.path,
          reason: q.path,
        );
      }
    });

    test('a hand-edited address falls back to the defaults', () {
      expect(
        parseView('sort=reporter&dir=up&page=zero&size=500'),
        const ComplaintListQuery(),
      );
      expect(parseView('page=0').page, 0);
      expect(parseView('page=-3').page, 0);
      expect(parseView('page=2').page, 1, reason: 'the address counts from 1');
      expect(parseView('size=25').rowsPerPage, 25);
      expect(parseView('size=50').rowsPerPage, 50);
      expect(parseView('size=30').rowsPerPage, 25);
      // A column without a direction starts ascending; a direction alone
      // changes the default column.
      expect(parseView('sort=status').sortAscending, isTrue);
      expect(parseView('dir=asc').sortColumn, ComplaintTableColumn.priority);
      expect(parseView('dir=asc').sortAscending, isTrue);
    });

    test('a changed filter goes back to page one; Reset keeps the sort', () {
      const ComplaintListQuery q = ComplaintListQuery(
        sortColumn: ComplaintTableColumn.updated,
        sortAscending: true,
        page: 4,
        rowsPerPage: 50,
      );
      final ComplaintListQuery narrowed = q.withFilter(parse('status=closed'));
      expect(narrowed.page, 0);
      expect(narrowed.sortColumn, ComplaintTableColumn.updated);
      expect(narrowed.rowsPerPage, 50);
      final ComplaintListQuery reset = narrowed.reset();
      expect(reset.filter.isEmpty, isTrue);
      expect(reset.page, 0);
      expect(reset.sortColumn, ComplaintTableColumn.updated);
      expect(reset.sortAscending, isTrue);
      expect(reset.rowsPerPage, 50);
      expect(reset.path, '/complaints?sort=updated&dir=asc&size=50');
    });

    test('the view-state keys name no person either (PV-5)', () {
      for (final String key in <String>[
        kQuerySort,
        kQuerySortDir,
        kQueryPage,
        kQueryPageSize,
      ]) {
        expect(
          key,
          isNot(matches(RegExp(r'reporter|assignee|actor|user|owner|name'))),
        );
      }
      for (final ComplaintTableColumn c in ComplaintTableColumn.values) {
        final ComplaintListQuery q = ComplaintListQuery(sortColumn: c);
        expect(q.toQuery()[kQuerySort], anyOf(isNull, c.name));
      }
    });
  });

  group('providers', () {
    Future<ProviderContainer> signedIn(UserRole role) async {
      final ProviderContainer container = testContainer();
      final MockAccount account = demoAccount(role);
      await container
          .read(sessionProvider.notifier)
          .signIn(account.user.idNumber, account.password);
      return container;
    }

    test(
      'complaintListProvider serves a page of public views, live clock',
      () async {
        final ProviderContainer container = await signedIn(UserRole.admin);
        final ComplaintListPage page = await settled(
          container,
          complaintListProvider(const ComplaintListQuery()),
        );
        expect(page.rows, hasLength(25));
        expect(page.totalCount, 29);
        expect(page.allCount, 29);
        expect(page.now, now, reason: 'the console clock, pinned in tests');
        expect(page.rows.first, isA<PublicComplaintView>());
        expect(
          idList(page.rows),
          idList(all.toList()..sort(compareComplaintsByDefault)).take(25),
        );
      },
    );

    test('equal queries share a provider; different ones do not', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final ComplaintListQuery a = ComplaintListQuery(
        filter: parse('status=closed'),
      );
      final ComplaintListQuery b = ComplaintListQuery(
        filter: parse('status=closed'),
      );
      expect(a, b);
      expect(complaintListProvider(a), complaintListProvider(b));
      expect(
        (await settled(container, complaintListProvider(a))).totalCount,
        5,
      );
      expect(
        (await settled(
          container,
          complaintListProvider(const ComplaintListQuery()),
        )).totalCount,
        29,
      );
    });

    test(
      'a verifier gets the same list; other roles and signed-out get none',
      () async {
        final ProviderContainer verifier = await signedIn(UserRole.verifier);
        expect(
          (await settled(
            verifier,
            complaintListProvider(const ComplaintListQuery()),
          )).totalCount,
          29,
        );
        final ProviderContainer signedOut = testContainer();
        final ComplaintListPage none = await settled(
          signedOut,
          complaintListProvider(const ComplaintListQuery()),
        );
        expect(none.rows, isEmpty);
        expect(none.allCount, 0);
      },
    );

    test(
      'the Building filter offers the campus, then any other building',
      () async {
        final ProviderContainer container = await signedIn(UserRole.admin);
        await settled(container, allComplaintsProvider);
        final List<String> buildings = container.read(
          complaintBuildingsProvider,
        );
        expect(
          buildings.take(CampusDirectory.standard.buildingNames.length),
          CampusDirectory.standard.buildingNames,
        );
        // Every building that has a complaint is offered.
        for (final PublicComplaintView v in all) {
          expect(buildings, contains(v.building));
        }
        expect(buildings.toSet(), hasLength(buildings.length));
      },
    );
  });
}
