import 'package:campusfix_admin/features/dashboard/dashboard_layout.dart';
import 'package:campusfix_admin/features/dashboard/dashboard_screen.dart';
import 'package:campusfix_admin/features/dashboard/intake_chart.dart';
import 'package:campusfix_admin/features/dashboard/metric_card_grid.dart';
import 'package:campusfix_admin/providers/providers.dart';
// The barrel deliberately hides the raw complaint repository; tests reach it
// (to simulate failures and live changes) through its own library.
import 'package:campusfix_admin/providers/repositories.dart'
    show complaintRepositoryProvider;
import 'package:campusfix_admin/router/app_router.dart';
import 'package:campusfix_admin/router/routes.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/rendered_text.dart';

/// A window tall enough to lay the whole dashboard out without scrolling.
const Size tallDesktop = Size(1440, 2600);

/// A-02 Admin Dashboard: the cards, charts, lists, range control, navigation
/// presets, states and privacy (AC-46, AC-47).
void main() {
  Future<ProviderContainer> openDashboard(
    WidgetTester tester, {
    UserRole role = UserRole.admin,
    Size size = tallDesktop,
    Duration latency = Duration.zero,
    List<Override> overrides = const <Override>[],
  }) async {
    final ProviderContainer container = await pumpAdmin(
      tester,
      size: size,
      latency: latency,
      overrides: overrides,
    );
    await signInAs(tester, role);
    return container;
  }

  Finder cardFinder(String id) => find.byKey(ValueKey<String>('metric-$id'));
  MetricCard card(WidgetTester tester, String id) =>
      tester.widget<MetricCard>(cardFinder(id));
  int value(WidgetTester tester, String id) =>
      int.parse(card(tester, id).value);

  Finder barFinder(String label) =>
      find.byWidgetPredicate((w) => w is MetricBarRow && w.label == label);
  MetricBarRow bar(WidgetTester tester, String label) =>
      tester.widget<MetricBarRow>(barFinder(label));

  String location(ProviderContainer c) =>
      c.read(appRouterProvider).state.uri.toString();

  Future<void> tapCard(WidgetTester tester, String id) async {
    await tester.tap(cardFinder(id));
    await tester.pumpAndSettle();
  }

  const List<String> cardIds = <String>[
    'total',
    'pending',
    'criticalHigh',
    'assigned',
    'inProgress',
    'resolved',
    'closed',
    'awaitingVerification',
  ];

  group('metric cards (AC-46)', () {
    testWidgets('eight cards with the seed numbers, in order', (tester) async {
      await openDashboard(tester);

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(MetricCard), findsNWidgets(8));
      expect(
        <String>[for (final String id in cardIds) card(tester, id).label],
        <String>[
          'Total',
          'Pending',
          'Critical / High',
          'Assigned',
          'In progress',
          'Resolved',
          'Closed',
          'Awaiting verification',
        ],
      );
      expect(
        <int>[for (final String id in cardIds) value(tester, id)],
        <int>[
          29, // Total
          7, // Pending: 4 reported + 3 reviewed
          9, // Critical / High
          4, // Assigned
          6, // In progress
          7, // Resolved: 4 resolved + 3 verified
          5, // Closed
          4, // Awaiting verification
        ],
      );
      // Every card carries its one-line definition and is clickable.
      for (final String id in cardIds) {
        expect(card(tester, id).definition, isNotEmpty, reason: id);
        expect(card(tester, id).onTap, isNotNull, reason: id);
        expect(card(tester, id).loading, isFalse);
        expect(card(tester, id).hasError, isFalse);
      }
      expect(card(tester, 'criticalHigh').attention, isTrue);
      expect(card(tester, 'total').attention, isFalse);
    });

    testWidgets(
      'the partition holds on screen; Critical / High is an overlay',
      (tester) async {
        await openDashboard(tester);
        expect(
          value(tester, 'pending') +
              value(tester, 'assigned') +
              value(tester, 'inProgress') +
              value(tester, 'resolved') +
              value(tester, 'closed'),
          value(tester, 'total'),
        );
        // The overlay is not one of the five partition parts.
        expect(value(tester, 'criticalHigh'), isNot(value(tester, 'total')));
        expect(
          value(tester, 'awaitingVerification'),
          lessThanOrEqualTo(value(tester, 'resolved')),
        );
      },
    );

    testWidgets('a verifier sees exactly what an admin sees', (tester) async {
      final Map<UserRole, String> screens = <UserRole, String>{};
      final Map<UserRole, List<int>> numbers = <UserRole, List<int>>{};
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        await openDashboard(tester, role: role);
        numbers[role] = <int>[
          for (final String id in cardIds) value(tester, id),
        ];
        screens[role] = allRenderedText(
          tester,
          within: find.byType(DashboardScreen),
        );
        // Tear the app down so the next role boots from a clean session.
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(numbers[UserRole.verifier], numbers[UserRole.admin]);
      expect(screens[UserRole.verifier], screens[UserRole.admin]);
      expect(screens[UserRole.admin], isNotEmpty);
    });

    testWidgets('the cards sit four to a row on the console, equally tall', (
      tester,
    ) async {
      await openDashboard(tester);
      final List<Rect> rects = <Rect>[
        for (final String id in cardIds) tester.getRect(cardFinder(id)),
      ];
      // Two rows of four.
      expect(rects.take(4).map((r) => r.top).toSet().length, 1);
      expect(rects.skip(4).map((r) => r.top).toSet().length, 1);
      expect(rects[4].top, greaterThan(rects[0].bottom));
      expect(rects.map((r) => r.width).toSet().length, 1);
      // Cards of one row are as tall as the tallest of them.
      expect(rects.take(4).map((r) => r.height).toSet().length, 1);
      expect(rects.skip(4).map((r) => r.height).toSet().length, 1);
    });
  });

  group('date range', () {
    testWidgets('defaults to All and offers 7 d / 30 d / 90 d / All', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      final AppSegmented<CreatedRange> control = tester
          .widget<AppSegmented<CreatedRange>>(
            find.byType(AppSegmented<CreatedRange>),
          );
      expect(control.selected, CreatedRange.all);
      expect(control.segments.map((s) => s.label), <String>[
        '7 d',
        '30 d',
        '90 d',
        'All',
      ]);
      expect(container.read(dashboardRangeProvider), CreatedRange.all);
    });

    testWidgets('picking a range recomputes the cards, charts and lists', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);

      await tester.tap(find.text('7 d'));
      await tester.pumpAndSettle();
      expect(container.read(dashboardRangeProvider), CreatedRange.days7);
      expect(
        <int>[for (final String id in cardIds) value(tester, id)],
        <int>[
          18, // Total
          7, // Pending
          6, // Critical / High
          3, // Assigned
          4, // In progress
          4, // Resolved
          0, // Closed
          4, // Awaiting verification
        ],
      );
      // The partition still holds in the narrower range...
      expect(
        value(tester, 'pending') +
            value(tester, 'assigned') +
            value(tester, 'inProgress') +
            value(tester, 'resolved') +
            value(tester, 'closed'),
        value(tester, 'total'),
      );
      // ...the status chart follows the same range...
      expect(bar(tester, 'Closed').value, 0);
      expect(bar(tester, 'Verified').value, 0);
      expect(bar(tester, 'In Progress').value, 4);
      // ...and so do the lists ("Showing 5 of 14").
      expect(find.textContaining('Showing 5 of 14'), findsOneWidget);

      await tester.tap(find.text('90 d'));
      await tester.pumpAndSettle();
      expect(value(tester, 'total'), 29);
      await tester.tap(find.text('30 d'));
      await tester.pumpAndSettle();
      expect(value(tester, 'total'), 29);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(value(tester, 'total'), 29);
      expect(value(tester, 'closed'), 5);
    });

    testWidgets('the intake chart is a fixed 14-day window', (tester) async {
      await openDashboard(tester);
      String intakeLabel() => tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byType(IntakeChart),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .label!;
      final String before = intakeLabel();
      await tester.tap(find.text('7 d'));
      await tester.pumpAndSettle();
      expect(intakeLabel(), before);
    });

    testWidgets('the range survives opening a complaint list and coming back', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      await tester.tap(find.text('30 d'));
      await tester.pumpAndSettle();
      await tapCard(tester, 'pending');
      expect(location(container), startsWith(AppRoutes.complaints));

      container.read(appRouterProvider).go(AppRoutes.dashboard);
      await tester.pumpAndSettle();
      expect(container.read(dashboardRangeProvider), CreatedRange.days30);
      expect(
        tester
            .widget<AppSegmented<CreatedRange>>(
              find.byType(AppSegmented<CreatedRange>),
            )
            .selected,
        CreatedRange.days30,
      );
    });
  });

  group('charts', () {
    testWidgets('one bar per status, priority and category, summing right', (
      tester,
    ) async {
      await openDashboard(tester);
      expect(find.byType(MetricBarRow), findsNWidgets(7 + 4 + 8));

      // Status: all seven, sums to Total.
      final List<int> statusValues = <int>[
        for (final ComplaintStatus s in ComplaintStatus.values)
          bar(tester, s.label).value,
      ];
      expect(statusValues, <int>[4, 3, 4, 6, 4, 3, 5]);
      expect(
        statusValues.fold<int>(0, (a, b) => a + b),
        value(tester, 'total'),
      );

      // Priority: unresolved, Critical down to Low.
      final List<int> priorityValues = <int>[
        for (final Priority p in <Priority>[
          Priority.critical,
          Priority.high,
          Priority.medium,
          Priority.low,
        ])
          bar(tester, p.label).value,
      ];
      expect(priorityValues, <int>[2, 7, 5, 3]);
      // Unresolved = Pending + Assigned + In progress.
      expect(
        priorityValues.fold<int>(0, (a, b) => a + b),
        value(tester, 'pending') +
            value(tester, 'assigned') +
            value(tester, 'inProgress'),
      );

      // Category: all eight, unresolved, most first.
      final List<int> categoryValues = <int>[
        for (final ProblemCategory c in ProblemCategory.values)
          bar(tester, c.label).value,
      ];
      expect(categoryValues, <int>[2, 2, 2, 2, 2, 2, 3, 2]);
      expect(
        categoryValues.fold<int>(0, (a, b) => a + b),
        value(tester, 'pending') +
            value(tester, 'assigned') +
            value(tester, 'inProgress'),
      );
      // The most-loaded category is drawn first.
      final List<MetricBarRow> categoryRows = <MetricBarRow>[
        for (final MetricBarRow r in tester.widgetList<MetricBarRow>(
          find.byType(MetricBarRow),
        ))
          if (ProblemCategory.values.any((c) => c.label == r.label)) r,
      ];
      expect(categoryRows.first.label, ProblemCategory.safety.label);
    });

    testWidgets('a chart never mixes semantic sets', (tester) async {
      await openDashboard(tester);
      for (final ComplaintStatus s in ComplaintStatus.values) {
        final Element e = tester.element(barFinder(s.label));
        expect(
          bar(tester, s.label).fill,
          e.statusStyle(s).accent,
          reason: s.name,
        );
      }
      for (final Priority p in Priority.values) {
        final Element e = tester.element(barFinder(p.label));
        expect(
          bar(tester, p.label).fill,
          e.priorityStyle(p).accent,
          reason: p.name,
        );
      }
      for (final ProblemCategory c in ProblemCategory.values) {
        final Element e = tester.element(barFinder(c.label));
        expect(
          bar(tester, c.label).fill,
          e.categoryStyle(c).accent,
          reason: c.name,
        );
      }
    });

    testWidgets('the 14-day intake chart: one bar per day with its count', (
      tester,
    ) async {
      await openDashboard(tester);
      expect(find.byType(IntakeChart), findsOneWidget);
      final IntakeChart chart = tester.widget<IntakeChart>(
        find.byType(IntakeChart),
      );
      expect(chart.days.length, 14);
      expect(chart.days.map((d) => d.count).toList(), <int>[
        0, 1, 0, 1, 2, 1, 0, 1, 1, 2, 2, 1, 5, 6, //
      ]);
      // 14 counts + 14 day numbers + the "from to" caption.
      expect(
        find.descendant(
          of: find.byType(IntakeChart),
          matching: find.byType(Text),
        ),
        findsNWidgets(29),
      );
      expect(
        find.descendant(
          of: find.byType(IntakeChart),
          matching: find.text('Sep 23 to Oct 6'),
        ),
        findsOneWidget,
      );
    });
  });

  group('lists', () {
    testWidgets(
      'Awaiting manual triage lists reviewed, unassigned complaints',
      (tester) async {
        await openDashboard(tester);
        final Set<String> expected = <String>{
          for (final Complaint c in testSeed.complaints)
            if (c.status == ComplaintStatus.reviewed && c.assignment == null)
              c.id,
        };
        expect(expected, hasLength(3));
        final Finder panel = find.ancestor(
          of: find.text('Awaiting manual triage'),
          matching: find.byType(DashboardPanel),
        );
        // The three rows sit in the "Awaiting manual triage" panel.
        for (final String id in expected) {
          expect(
            find.descendant(
              of: panel,
              matching: find.byKey(ValueKey<String>('row-$id')),
            ),
            findsOneWidget,
            reason: id,
          );
        }
        expect(
          find.descendant(of: panel, matching: find.byType(ComplaintCard)),
          findsNWidgets(3),
        );
      },
    );

    testWidgets('each list shows at most five rows with the full count', (
      tester,
    ) async {
      await openDashboard(tester);
      // 9 Critical / High, 17 unresolved, 3 awaiting triage.
      expect(find.textContaining('Showing 5 of 9'), findsOneWidget);
      expect(find.textContaining('Showing 5 of 17'), findsOneWidget);
      expect(find.textContaining('3 complaints'), findsOneWidget);
      // 5 + 5 + 3 rows (A complaint can appear in more than one list.)
      expect(find.byType(ComplaintCard), findsNWidgets(13));
    });

    testWidgets('Needs attention: Critical first, then High, oldest first', (
      tester,
    ) async {
      await openDashboard(tester);
      final List<ComplaintCard> rows = tester
          .widgetList<ComplaintCard>(find.byType(ComplaintCard))
          .take(5)
          .toList();
      expect(rows.map((r) => r.complaint.effectivePriority), <Priority>[
        Priority.critical,
        Priority.critical,
        Priority.high,
        Priority.high,
        Priority.high,
      ]);
      for (final ComplaintCard r in rows) {
        expect(r.variant, ComplaintCardVariant.row);
        expect(
          r.complaint.status.order,
          lessThan(ComplaintStatus.resolved.order),
        );
      }
    });

    testWidgets('a row opens the complaint detail (A-04), with no filter', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      final ComplaintCard first = tester
          .widgetList<ComplaintCard>(find.byType(ComplaintCard))
          .first;
      await tester.tap(find.byType(ComplaintCard).first);
      await tester.pumpAndSettle();
      expect(location(container), AppRoutes.complaint(first.complaint.id));
      expect(container.read(appRouterProvider).state.uri.query, isEmpty);
    });

    testWidgets('View all opens the list pre-filtered to the whole list', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      final Map<String, String> presets = <String, String>{
        'Needs attention':
            '/complaints?unresolved=1&priority=critical,high&created=all',
        'Oldest unresolved': '/complaints?unresolved=1&created=all',
        'Awaiting manual triage': '/complaints?triage=1&created=all',
      };
      for (final MapEntry<String, String> e in presets.entries) {
        final Finder viewAll = find.descendant(
          of: find.ancestor(
            of: find.text(e.key),
            matching: find.byType(DashboardPanel),
          ),
          matching: find.text('View all'),
        );
        expect(viewAll, findsOneWidget, reason: e.key);
        await tester.tap(viewAll);
        await tester.pumpAndSettle();
        expect(location(container), e.value, reason: e.key);
        container.read(appRouterProvider).go(AppRoutes.dashboard);
        await tester.pumpAndSettle();
      }
    });
  });

  group('navigation presets (AC-47)', () {
    testWidgets('Critical / High lands on exactly the counted set', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      await tapCard(tester, 'criticalHigh');
      expect(
        location(container),
        '/complaints?unresolved=1&priority=critical,high&created=all',
      );
      final Uri uri = container.read(appRouterProvider).state.uri;
      expect(uri.path, AppRoutes.complaints);
      expect(uri.queryParameters, <String, String>{
        'unresolved': '1',
        'priority': 'critical,high',
        'created': 'all',
      });
      // That filter selects the 9 complaints the card counted, no more.
      final int selected = testSeed.complaints
          .where(
            (c) =>
                c.status.order < ComplaintStatus.resolved.order &&
                (c.effectivePriority == Priority.critical ||
                    c.effectivePriority == Priority.high),
          )
          .length;
      expect(selected, 9);
    });

    testWidgets('the preset carries the dashboard range', (tester) async {
      final ProviderContainer container = await openDashboard(tester);
      await tester.tap(find.text('30 d'));
      await tester.pumpAndSettle();
      await tapCard(tester, 'criticalHigh');
      expect(
        location(container),
        '/complaints?unresolved=1&priority=critical,high&created=30d',
      );
    });

    testWidgets('every card opens its own preset', (tester) async {
      final ProviderContainer container = await openDashboard(tester);
      final Map<String, String> presets = <String, String>{
        'total': '/complaints?created=7d',
        'pending': '/complaints?status=reported,reviewed&created=7d',
        'criticalHigh':
            '/complaints?unresolved=1&priority=critical,high&created=7d',
        'assigned': '/complaints?status=assigned&created=7d',
        'inProgress': '/complaints?status=inProgress&created=7d',
        'resolved': '/complaints?status=resolved,verified&created=7d',
        'closed': '/complaints?status=closed&created=7d',
        'awaitingVerification': '/complaints?status=resolved&created=7d',
      };
      expect(presets.keys, cardIds);
      await tester.tap(find.text('7 d'));
      await tester.pumpAndSettle();
      for (final MapEntry<String, String> e in presets.entries) {
        await tapCard(tester, e.key);
        expect(location(container), e.value, reason: e.key);
        container.read(appRouterProvider).go(AppRoutes.dashboard);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a chart bar opens the list filtered to that bar', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      final Map<String, String> presets = <String, String>{
        // status
        'In Progress': '/complaints?status=inProgress&created=all',
        'Verified': '/complaints?status=verified&created=all',
        // priority (unresolved)
        'Critical': '/complaints?unresolved=1&priority=critical&created=all',
        'Low': '/complaints?unresolved=1&priority=low&created=all',
        // category (unresolved)
        'Safety': '/complaints?unresolved=1&category=safety&created=all',
        'IT / Network / Projector / Computer':
            '/complaints?unresolved=1&category=it&created=all',
      };
      for (final MapEntry<String, String> e in presets.entries) {
        await tester.tap(barFinder(e.key));
        await tester.pumpAndSettle();
        expect(location(container), e.value, reason: e.key);
        container.read(appRouterProvider).go(AppRoutes.dashboard);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a verifier gets the same presets', (tester) async {
      final ProviderContainer container = await openDashboard(
        tester,
        role: UserRole.verifier,
      );
      await tapCard(tester, 'criticalHigh');
      expect(
        location(container),
        '/complaints?unresolved=1&priority=critical,high&created=all',
      );
    });

    testWidgets('no preset carries anything but filter values (PV-5)', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      final RegExp allowed = RegExp(
        r'^(status|priority|category|department|building|q|unresolved|triage|created)$',
      );
      for (final String id in cardIds) {
        await tapCard(tester, id);
        final Uri uri = container.read(appRouterProvider).state.uri;
        expect(
          uri.queryParameters.keys.every(allowed.hasMatch),
          isTrue,
          reason: id,
        );
        container.read(appRouterProvider).go(AppRoutes.dashboard);
        await tester.pumpAndSettle();
      }
    });
  });

  group('states', () {
    testWidgets('loading: skeleton cards, nothing shown as a number', (
      tester,
    ) async {
      final StalledComplaintRepository stalled = StalledComplaintRepository();
      await pumpAdmin(
        tester,
        size: tallDesktop,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(stalled),
        ],
      );
      await signInAs(tester, UserRole.admin);

      expect(find.byType(MetricCard), findsNWidgets(8));
      for (final String id in cardIds) {
        expect(card(tester, id).loading, isTrue, reason: id);
        expect(card(tester, id).onTap, isNull, reason: id);
      }
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(MetricBarRow), findsNothing);
      // The range control is there while the data loads.
      expect(find.byType(AppSegmented<CreatedRange>), findsOneWidget);
    });

    testWidgets('empty: zeros and "No complaints yet"', (tester) async {
      await openDashboard(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(
            MockComplaintRepository(),
          ),
        ],
      );
      for (final String id in cardIds) {
        expect(card(tester, id).value, '0', reason: id);
      }
      expect(find.text('No complaints yet'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(MetricBarRow), findsNothing);
      expect(find.byType(ComplaintCard), findsNothing);
    });

    testWidgets('error: each widget shows its own error with Retry', (
      tester,
    ) async {
      await openDashboard(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(
            FlakyComplaintRepository(initial: testSeed.complaints),
          ),
        ],
      );
      for (final String id in cardIds) {
        expect(card(tester, id).hasError, isTrue, reason: id);
        expect(card(tester, id).onRetry, isNotNull, reason: id);
      }
      expect(find.text('Could not load.'), findsNWidgets(8));
      // Four charts and three lists each carry their own error state.
      expect(find.text("Couldn't load this section"), findsNWidgets(7));
      expect(find.byType(MetricBarRow), findsNothing);

      // Retry on one widget re-reads the data for all of them.
      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();
      expect(find.text('Could not load.'), findsNothing);
      expect(find.text("Couldn't load this section"), findsNothing);
      expect(value(tester, 'total'), 29);
      expect(find.byType(MetricBarRow), findsNWidgets(19));
    });

    testWidgets('live: a status change moves the cards without a reload', (
      tester,
    ) async {
      final ProviderContainer container = await openDashboard(tester);
      expect(value(tester, 'closed'), 5);
      expect(value(tester, 'assigned'), 4);

      final ComplaintRepository repo = container.read(
        complaintRepositoryProvider,
      );
      final Complaint assigned = testSeed.complaints.firstWhere(
        (c) => c.status == ComplaintStatus.assigned,
      );
      await tester.runAsync(
        () => repo.update(assigned.copyWith(status: ComplaintStatus.closed)),
      );
      await tester.pumpAndSettle();

      expect(value(tester, 'closed'), 6);
      expect(value(tester, 'assigned'), 3);
      expect(value(tester, 'total'), 29);
    });
  });

  group('privacy (R5, PV-5)', () {
    testWidgets('no identity anywhere on the dashboard, for either role', (
      tester,
    ) async {
      // Positive control: the sentinels are real. The top bar shows the
      // signed-in user's own name, so a sweep of the whole page finds it, and
      // the dashboard sweep below is scoped to the dashboard body.
      await openDashboard(tester);
      expect(identityLeaks(allRenderedText(tester)), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        final ProviderContainer container = await openDashboard(
          tester,
          role: role,
        );
        for (final CreatedRange r in CreatedRange.values) {
          container.read(dashboardRangeProvider.notifier).select(r);
          await tester.pumpAndSettle();
          final String text = allRenderedText(
            tester,
            within: find.byType(DashboardScreen),
          );
          expect(text, isNotEmpty);
          expect(identityLeaks(text), isEmpty, reason: '$role ${r.queryValue}');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('the screen has no way to reveal or filter by a person', (
      tester,
    ) async {
      await openDashboard(tester);
      for (final String word in <String>[
        'Reveal',
        'Reporter',
        'Assignee',
        'Assigned to',
        'Reported by',
      ]) {
        expect(
          find.descendant(
            of: find.byType(DashboardScreen),
            matching: find.textContaining(word),
          ),
          findsNothing,
          reason: word,
        );
      }
    });
  });

  group('responsive', () {
    testWidgets('columns per window class', (tester) async {
      expect(MetricCardGrid.columnsFor(AppWindowClass.expanded), 4);
      expect(MetricCardGrid.columnsFor(AppWindowClass.medium), 3);
      expect(MetricCardGrid.columnsFor(AppWindowClass.compact), 2);
    });

    testWidgets('a medium window lays out without overflow', (tester) async {
      await openDashboard(tester, size: const Size(900, 3200));
      expect(find.byType(MetricCard), findsNWidgets(8));
      final Set<double> firstRow = <double>{
        for (final String id in cardIds.take(3))
          tester.getRect(cardFinder(id)).top,
      };
      expect(firstRow, hasLength(1));
      expect(
        tester.getRect(cardFinder('assigned')).top,
        greaterThan(tester.getRect(cardFinder('total')).bottom),
      );
    });

    testWidgets('a compact window lays out without overflow', (tester) async {
      await openDashboard(tester, size: const Size(420, 4600));
      expect(find.byType(MetricCard), findsNWidgets(8));
      expect(find.byType(MetricBarRow), findsNWidgets(19));
      expect(tester.takeException(), isNull);
    });
  });
}
