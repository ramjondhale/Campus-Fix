import 'package:campusfix_admin/features/complaint_detail/complaint_detail_screen.dart';
import 'package:campusfix_admin/features/dashboard/dashboard_layout.dart';
import 'package:campusfix_admin/features/complaints/complaint_filter_bar.dart';
import 'package:campusfix_admin/features/complaints/complaint_list_screen.dart';
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

/// A window tall enough to lay a full page of rows out without scrolling.
const Size tallDesktop = Size(1440, 2600);

/// A-03 Complaint List + Filters: the table, the filter bar, sorting,
/// pagination, the URL contract with the dashboard, the states and privacy
/// (AC-47, AC-48, AC-49, AC-50).
void main() {
  final DateTime now = testSeed.now;
  final List<PublicComplaintView> all = toPublicViews(testSeed.complaints);

  Future<ProviderContainer> openList(
    WidgetTester tester, {
    String query = '',
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
    container
        .read(appRouterProvider)
        .go(query.isEmpty ? AppRoutes.complaints : '/complaints?$query');
    await tester.pumpAndSettle();
    return container;
  }

  String location(ProviderContainer c) =>
      c.read(appRouterProvider).state.uri.toString();

  ComplaintTable table(WidgetTester tester) =>
      tester.widget<ComplaintTable>(find.byType(ComplaintTable));
  List<String> rowIds(WidgetTester tester) => <String>[
    for (final PublicComplaintView v in table(tester).complaints) v.id,
  ];
  Set<String> idSet(Iterable<PublicComplaintView> views) => <String>{
    for (final PublicComplaintView v in views) v.id,
  };
  Set<String> shownIds(WidgetTester tester) => rowIds(tester).toSet();

  Finder chip(String label) => find.widgetWithText(AppFilterChip, label);
  AppFilterChip chipWidget(WidgetTester tester, String label) =>
      tester.widget<AppFilterChip>(chip(label));
  Finder menuBox(String label) =>
      find.widgetWithText(CheckboxMenuButton, label);
  Finder menuItem(String label) => find.widgetWithText(MenuItemButton, label);
  Finder searchInput() => find.descendant(
    of: find.byType(AppSearchField),
    matching: find.byType(EditableText),
  );
  String searchText(WidgetTester tester) =>
      tester.widget<EditableText>(searchInput()).controller.text;

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String label) =>
      tapAndSettle(tester, chip(label));

  /// Ticks [option] in the open multi-select menu.
  Future<void> tick(WidgetTester tester, String option) =>
      tapAndSettle(tester, menuBox(option));

  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(searchInput(), text);
    await tester.pump(kSearchDebounce);
    await tester.pumpAndSettle();
  }

  Finder resetInBar() => find.descendant(
    of: find.byType(FilterBar),
    matching: find.text('Reset filters'),
  );

  group('the table (AC-48, AC-50)', () {
    testWidgets('the first page of the seed, in the default order', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);

      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(find.byType(ComplaintTable), findsOneWidget);
      expect(find.byType(FilterBar), findsOneWidget);
      expect(location(container), '/complaints');
      expect(table(tester).complaints, hasLength(25));
      expect(table(tester).totalCount, 29);
      expect(table(tester).page, 0);
      expect(table(tester).rowsPerPage, 25);
      expect(find.text('1-25 of 29'), findsOneWidget);
      // AC-50: priority weight descending, then longest waiting first.
      expect(rowIds(tester).take(4), <String>[
        'CF-2026-00006',
        'CF-2026-00016',
        'CF-2026-00026',
        'CF-2026-00027',
      ]);
      final List<PublicComplaintView> rows = table(tester).complaints;
      for (int i = 1; i < rows.length; i++) {
        final PublicComplaintView a = rows[i - 1];
        final PublicComplaintView b = rows[i];
        expect(
          a.effectivePriority.weight,
          greaterThanOrEqualTo(b.effectivePriority.weight),
        );
        if (a.effectivePriority == b.effectivePriority) {
          expect(a.createdAt.isAfter(b.createdAt), isFalse);
        }
      }
      // The sort indicator sits on Priority, descending.
      expect(table(tester).sortColumn, ComplaintTableColumn.priority);
      expect(table(tester).sortAscending, isFalse);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('the "now" of the Waiting column is the console clock', (
      tester,
    ) async {
      await openList(tester);
      expect(table(tester).now, now);
    });

    testWidgets('AC-48: the header is the eight public columns, no identity', (
      tester,
    ) async {
      await openList(tester);
      expect(ComplaintTableColumn.values, hasLength(8));
      expect(
        <String>[for (final c in ComplaintTableColumn.values) c.title],
        <String>[
          'ID',
          'Category',
          'Location',
          'Priority',
          'Status',
          'Department',
          'Waiting',
          'Updated',
        ],
      );
      for (final ComplaintTableColumn c in ComplaintTableColumn.values) {
        expect(
          find.text(c.title.toUpperCase()),
          findsOneWidget,
          reason: c.title,
        );
      }
      expect(
        allRenderedText(tester, within: find.byType(ComplaintTable)),
        isNot(
          matches(
            RegExp(
              r'reporter|requester|submitted by|e-?mail|phone|assignee|'
              r'assigned to|owner',
              caseSensitive: false,
            ),
          ),
        ),
      );
    });

    testWidgets('a row shows the public fields of its complaint', (
      tester,
    ) async {
      await openList(tester);
      final PublicComplaintView first = table(tester).complaints.first;
      expect(find.text(first.id), findsOneWidget);
      expect(find.byType(StatusBadge), findsWidgets);
      expect(find.byType(PriorityTag), findsWidgets);
      expect(
        find.text('${first.building} · ${first.floor} · ${first.room}'),
        findsWidgets,
      );
    });

    testWidgets('a verifier gets the same list', (tester) async {
      await openList(tester, role: UserRole.verifier);
      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(table(tester).totalCount, 29);
      expect(rowIds(tester).first, 'CF-2026-00006');
    });

    testWidgets('a window of every class lays out without overflow', (
      tester,
    ) async {
      await openList(tester);
      for (final Size size in <Size>[
        const Size(1440, 900),
        const Size(1100, 800),
        const Size(800, 700),
        const Size(420, 800),
      ]) {
        await resizeTo(tester, size);
        expect(find.byType(ComplaintTable), findsOneWidget, reason: '$size');
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  group('the filter bar is composed from the design system', () {
    testWidgets('search first, then the filters, the range and Reset', (
      tester,
    ) async {
      await openList(tester);
      expect(find.byType(FilterBar), findsOneWidget);
      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text(AppSearchField.defaultHint), findsOneWidget);
      for (final String label in <String>[
        'Status',
        'Priority',
        'Category',
        'Department',
        'Building',
        'Unresolved only',
        'Needs manual triage',
      ]) {
        expect(chip(label), findsOneWidget, reason: label);
        expect(chipWidget(tester, label).selected, isFalse, reason: label);
      }
      expect(
        chipWidget(tester, 'Unresolved only').kind,
        AppFilterChipKind.toggle,
      );
      expect(chipWidget(tester, 'Status').kind, AppFilterChipKind.menu);
      expect(find.byType(AppSegmented<CreatedRange>), findsOneWidget);
      for (final CreatedRange r in CreatedRange.values) {
        expect(find.text(r.label), findsOneWidget, reason: r.label);
      }
      // Nothing is on, so there is nothing to reset.
      expect(find.text('Reset filters'), findsNothing);
    });

    testWidgets('no control filters, searches or sorts by a person (PV-5)', (
      tester,
    ) async {
      await openList(tester);
      final String bar = allRenderedText(
        tester,
        within: find.byType(FilterBar),
      );
      expect(
        bar,
        isNot(
          matches(
            RegExp(
              r'reporter|requester|assignee|submitted by|e-?mail|phone',
              caseSensitive: false,
            ),
          ),
        ),
      );
      expect(
        tester.widget<EditableText>(searchInput()).controller.text,
        isEmpty,
      );
    });
  });

  group('AC-49: each filter narrows the list, and they AND together', () {
    testWidgets('Status (multi-select): the menu stays open, values OR', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await openMenu(tester, 'Status');
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(menuBox(s.label), findsOneWidget, reason: s.label);
      }

      await tick(tester, 'Reported');
      expect(location(container), '/complaints?status=reported&created=all');
      expect(table(tester).totalCount, 4);
      expect(chipWidget(tester, 'Status').selected, isTrue);
      expect(chipWidget(tester, 'Status').count, 1);
      expect(menuBox('Reviewed'), findsOneWidget, reason: 'still open');

      await tick(tester, 'Reviewed');
      expect(
        location(container),
        '/complaints?status=reported,reviewed&created=all',
      );
      expect(table(tester).totalCount, 7);
      expect(chipWidget(tester, 'Status').count, 2);
      expect(
        shownIds(tester),
        idSet(
          all.where(
            (v) =>
                v.status == ComplaintStatus.reported ||
                v.status == ComplaintStatus.reviewed,
          ),
        ),
      );

      // Unticking goes back, and the last untick removes the filter.
      await tick(tester, 'Reported');
      await tick(tester, 'Reviewed');
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
      expect(chipWidget(tester, 'Status').selected, isFalse);
    });

    testWidgets('Priority (multi-select) is the effective priority', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await openMenu(tester, 'Priority');
      await tick(tester, 'Critical');
      await tick(tester, 'High');
      expect(
        location(container),
        '/complaints?priority=critical,high&created=all',
      );
      expect(
        shownIds(tester),
        idSet(all.where((v) => isCriticalOrHigh(v.effectivePriority))),
      );
      expect(table(tester).totalCount, 16);
    });

    testWidgets('Category (multi-select)', (tester) async {
      final ProviderContainer container = await openList(tester);
      await openMenu(tester, 'Category');
      await tick(tester, ProblemCategory.it.label);
      await tick(tester, ProblemCategory.safety.label);
      expect(location(container), '/complaints?category=it,safety&created=all');
      expect(
        shownIds(tester),
        idSet(
          all.where(
            (v) =>
                v.category == ProblemCategory.it ||
                v.category == ProblemCategory.safety,
          ),
        ),
      );
    });

    testWidgets('Department (multi-select) includes Unassigned', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await openMenu(tester, 'Department');
      for (final Department d in Department.values) {
        expect(menuBox(d.label), findsOneWidget, reason: d.label);
      }
      expect(menuBox('Unassigned'), findsOneWidget);

      await tick(tester, 'Unassigned');
      expect(
        location(container),
        '/complaints?department=unassigned&created=all',
      );
      expect(
        shownIds(tester),
        idSet(all.where((v) => v.assignedDepartment == null)),
      );
      expect(table(tester).totalCount, 7);

      await tick(tester, Department.electrician.label);
      expect(
        location(container),
        '/complaints?department=electrician,unassigned&created=all',
      );
      expect(
        shownIds(tester),
        idSet(
          all.where(
            (v) =>
                v.assignedDepartment == null ||
                v.assignedDepartment == Department.electrician,
          ),
        ),
      );
      expect(chipWidget(tester, 'Department').count, 2);
    });

    testWidgets('Building (single choice) and "Any building"', (tester) async {
      final ProviderContainer container = await openList(tester);
      await openMenu(tester, 'Building');
      expect(menuItem('Any building'), findsOneWidget);
      for (final String b in CampusDirectory.standard.buildingNames) {
        expect(menuItem(b), findsOneWidget, reason: b);
      }

      await tapAndSettle(tester, menuItem('Central Library'));
      expect(
        location(container),
        '/complaints?building=Central+Library&created=all',
      );
      expect(
        shownIds(tester),
        idSet(all.where((v) => v.building == 'Central Library')),
      );
      expect(chipWidget(tester, 'Building').selected, isTrue);
      expect(find.byType(MenuItemButton), findsNothing, reason: 'menu closed');

      await openMenu(tester, 'Building');
      await tapAndSettle(tester, menuItem('Any building'));
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
    });

    testWidgets('Created range (7 d / 30 d / 90 d / All)', (tester) async {
      final ProviderContainer container = await openList(tester);
      for (final CreatedRange r in <CreatedRange>[
        CreatedRange.days7,
        CreatedRange.days30,
        CreatedRange.days90,
      ]) {
        await tapAndSettle(tester, find.text(r.label));
        expect(location(container), '/complaints?created=${r.queryValue}');
        final Set<String> inRange = idSet(
          all.where((v) => r.contains(v.createdAt, now)),
        );
        expect(table(tester).totalCount, inRange.length, reason: r.label);
        expect(inRange.containsAll(shownIds(tester)), isTrue, reason: r.label);
      }
      await tapAndSettle(tester, find.text('7 d'));
      expect(table(tester).totalCount, lessThan(29));
      await tapAndSettle(tester, find.text('All'));
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
    });

    testWidgets('"Unresolved only" and "Needs manual triage" toggles', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await tapAndSettle(tester, chip('Unresolved only'));
      expect(location(container), '/complaints?unresolved=1&created=all');
      expect(chipWidget(tester, 'Unresolved only').selected, isTrue);
      expect(table(tester).totalCount, 17);
      expect(
        shownIds(tester),
        idSet(all.where((v) => isUnresolvedStatus(v.status))),
      );

      await tapAndSettle(tester, chip('Needs manual triage'));
      expect(
        location(container),
        '/complaints?unresolved=1&triage=1&created=all',
      );
      expect(shownIds(tester), idSet(all.where(needsManualTriage)));
      expect(table(tester).totalCount, 3);

      await tapAndSettle(tester, chip('Unresolved only'));
      await tapAndSettle(tester, chip('Needs manual triage'));
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
    });

    testWidgets('Search: ID, description or location, after a short pause', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);

      // Description, any case.
      await tester.enterText(searchInput(), 'WI-FI');
      await tester.pump(const Duration(milliseconds: 100));
      expect(location(container), '/complaints', reason: 'still typing');
      expect(table(tester).totalCount, 29);
      await tester.pump(kSearchDebounce);
      await tester.pumpAndSettle();
      expect(location(container), '/complaints?q=WI-FI&created=all');
      expect(rowIds(tester), <String>['CF-2026-00012']);

      // The ID.
      await typeSearch(tester, 'cf-2026-00023');
      expect(rowIds(tester), <String>['CF-2026-00023']);

      // The location (building, floor and room words).
      await typeSearch(tester, 'hostel mess');
      expect(location(container), '/complaints?q=hostel+mess&created=all');
      expect(rowIds(tester), <String>['CF-2026-00013']);

      // Enter applies at once, without waiting.
      await tester.enterText(searchInput(), 'main gate');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(rowIds(tester), <String>['CF-2026-00024']);

      // Clearing the text removes the filter.
      await typeSearch(tester, '');
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
    });

    testWidgets('the filters AND: status, priority, category, department, '
        'building, search, toggle and range, one after the other', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      int previous = 29;
      void narrowed() {
        final int now = table(tester).totalCount!;
        expect(now, lessThanOrEqualTo(previous));
        previous = now;
      }

      await tapAndSettle(tester, find.text('90 d'));
      narrowed();
      await tapAndSettle(tester, chip('Unresolved only'));
      narrowed();
      await openMenu(tester, 'Status');
      await tick(tester, 'Assigned');
      await tick(tester, 'In Progress');
      narrowed();
      await openMenu(tester, 'Priority');
      await tick(tester, 'High');
      await tick(tester, 'Critical');
      narrowed();
      await openMenu(tester, 'Category');
      await tick(tester, ProblemCategory.it.label);
      await tick(tester, ProblemCategory.cleanliness.label);
      narrowed();
      await openMenu(tester, 'Department');
      await tick(tester, Department.itTeam.label);
      narrowed();
      await openMenu(tester, 'Building');
      await tapAndSettle(tester, menuItem('Science & Computer Block'));
      narrowed();
      await typeSearch(tester, 'erp');
      narrowed();

      expect(rowIds(tester), <String>['CF-2026-00019']);
      expect(
        location(container),
        '/complaints?unresolved=1&status=assigned,inProgress'
        '&priority=critical,high&category=cleanliness,it&department=itTeam'
        '&building=Science+%26+Computer+Block&q=erp&created=90d',
      );
      // Every active filter shows on its chip.
      expect(chipWidget(tester, 'Status').count, 2);
      expect(chipWidget(tester, 'Priority').count, 2);
      expect(chipWidget(tester, 'Category').count, 2);
      expect(chipWidget(tester, 'Department').count, 1);
      expect(chipWidget(tester, 'Building').selected, isTrue);
      expect(chipWidget(tester, 'Unresolved only').selected, isTrue);

      // Contradicting one facet leaves nothing: closed is never unresolved.
      await openMenu(tester, 'Status');
      await tick(tester, 'Closed');
      expect(table(tester).totalCount, 1, reason: 'OR inside Status');
      await tick(tester, 'Assigned');
      await tick(tester, 'In Progress');
      expect(table(tester).totalCount, 0);
      expect(find.text('No complaints match'), findsOneWidget);
    });

    testWidgets('a filter change goes back to the first page', (tester) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'page=2',
      );
      expect(table(tester).page, 1);
      await tapAndSettle(tester, chip('Unresolved only'));
      expect(table(tester).page, 0);
      expect(
        location(container),
        '/complaints?unresolved=1&created=all',
        reason: 'no page key on the first page',
      );
    });
  });

  group('Reset filters', () {
    testWidgets('appears with the first filter and restores the default', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      expect(find.text('Reset filters'), findsNothing);

      await tapAndSettle(tester, chip('Unresolved only'));
      await openMenu(tester, 'Priority');
      await tick(tester, 'Critical');
      await typeSearch(tester, 'lab');
      expect(resetInBar(), findsOneWidget);
      expect(
        location(container),
        '/complaints?unresolved=1&priority=critical&q=lab&created=all',
      );

      await tapAndSettle(tester, resetInBar());
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
      expect(chipWidget(tester, 'Unresolved only').selected, isFalse);
      expect(chipWidget(tester, 'Priority').selected, isFalse);
      expect(searchText(tester), isEmpty);
      expect(find.text('Reset filters'), findsNothing);
    });

    testWidgets('Reset also clears text still waiting to be applied', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'unresolved=1&created=all',
      );
      await tester.enterText(searchInput(), 'lab');
      await tester.pump(const Duration(milliseconds: 100));
      await tapAndSettle(tester, resetInBar());
      await tester.pump(kSearchDebounce);
      await tester.pumpAndSettle();
      expect(location(container), '/complaints');
      expect(searchText(tester), isEmpty);
    });

    testWidgets('keeps the sort and the page size (they are not filters)', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'status=closed&created=all&sort=updated&dir=asc&size=50',
      );
      await tapAndSettle(tester, resetInBar());
      expect(location(container), '/complaints?sort=updated&dir=asc&size=50');
      expect(table(tester).sortColumn, ComplaintTableColumn.updated);
      expect(table(tester).rowsPerPage, 50);
    });
  });

  group('the URL is the state (AC-47)', () {
    testWidgets('Critical / High preset: exactly the 9 counted complaints', (
      tester,
    ) async {
      await openList(
        tester,
        query: 'unresolved=1&priority=critical,high&created=all',
      );
      expect(table(tester).totalCount, 9);
      expect(
        shownIds(tester),
        idSet(
          all.where(
            (v) =>
                isUnresolvedStatus(v.status) &&
                isCriticalOrHigh(v.effectivePriority),
          ),
        ),
      );
      expect(shownIds(tester), idSet(needsAttentionOf(all, limit: 99).rows));
      // The chips show what the address says.
      expect(chipWidget(tester, 'Priority').selected, isTrue);
      expect(chipWidget(tester, 'Priority').count, 2);
      expect(chipWidget(tester, 'Unresolved only').selected, isTrue);
      expect(chipWidget(tester, 'Status').selected, isFalse);
      expect(resetInBar(), findsOneWidget);
    });

    testWidgets('every dashboard preset lands on its counted set', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      final DashboardMetrics m = computeDashboardMetrics(all);
      final Map<String, int> presets = <String, int>{
        'created=all': m.total,
        'status=reported,reviewed&created=all': m.pending,
        'unresolved=1&priority=critical,high&created=all': m.criticalHigh,
        'status=assigned&created=all': m.assigned,
        'status=inProgress&created=all': m.inProgress,
        'status=resolved,verified&created=all': m.resolved,
        'status=closed&created=all': m.closed,
        'status=resolved&created=all': m.awaitingVerification,
        'unresolved=1&created=all': oldestUnresolvedOf(all, limit: 99).total,
        'triage=1&created=all': awaitingTriageOf(all, limit: 99).total,
      };
      for (final MapEntry<String, int> e in presets.entries) {
        container.read(appRouterProvider).go('/complaints?${e.key}');
        await tester.pumpAndSettle();
        expect(table(tester).totalCount, e.value, reason: e.key);
      }
    });

    testWidgets('a dashboard card opens the list on the counted set', (
      tester,
    ) async {
      final ProviderContainer container = await pumpAdmin(
        tester,
        size: tallDesktop,
      );
      await signInAs(tester, UserRole.admin);
      await tester.tap(
        find.byKey(const ValueKey<String>('metric-criticalHigh')),
      );
      await tester.pumpAndSettle();

      expect(
        location(container),
        '/complaints?unresolved=1&priority=critical,high&created=all',
      );
      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(table(tester).totalCount, 9);
      expect(chipWidget(tester, 'Unresolved only').selected, isTrue);
    });

    testWidgets('a dashboard range reaches the list', (tester) async {
      final ProviderContainer container = await pumpAdmin(
        tester,
        size: tallDesktop,
      );
      await signInAs(tester, UserRole.admin);
      await tester.tap(find.text('7 d'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('metric-pending')));
      await tester.pumpAndSettle();
      expect(
        location(container),
        '/complaints?status=reported,reviewed&created=7d',
      );
      expect(
        shownIds(tester),
        idSet(
          all.where(
            (v) =>
                (v.status == ComplaintStatus.reported ||
                    v.status == ComplaintStatus.reviewed) &&
                CreatedRange.days7.contains(v.createdAt, now),
          ),
        ),
      );
    });

    testWidgets('a "View all" link opens its whole list', (tester) async {
      final ProviderContainer container = await pumpAdmin(
        tester,
        size: tallDesktop,
      );
      await signInAs(tester, UserRole.admin);
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Awaiting manual triage'),
            matching: find.byType(DashboardPanel),
          ),
          matching: find.text('View all'),
        ),
      );
      await tester.pumpAndSettle();
      expect(location(container), '/complaints?triage=1&created=all');
      expect(table(tester).totalCount, 3);
      expect(chipWidget(tester, 'Needs manual triage').selected, isTrue);
    });

    testWidgets('the address is shareable: the same URL, the same list', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await tapAndSettle(tester, chip('Unresolved only'));
      await openMenu(tester, 'Priority');
      await tick(tester, 'Critical');
      await tapAndSettle(tester, find.text('Priority').first);
      final String shared = location(container);
      final Set<String> before = shownIds(tester);
      final List<String> order = rowIds(tester);
      expect(before, isNotEmpty);

      // A fresh session opening that address sees the same rows, in order.
      await tester.pumpWidget(const SizedBox.shrink());
      final ProviderContainer other = await openList(
        tester,
        query: Uri.parse(shared).query,
      );
      expect(location(other), shared);
      expect(rowIds(tester), order);
    });

    testWidgets('a hand-edited address is read leniently', (tester) async {
      await openList(
        tester,
        query:
            'status=reported,bogus&priority=urgent&created=1y&reporter=Asha'
            '&page=zero&sort=reporter',
      );
      expect(table(tester).totalCount, 4, reason: 'only the valid status');
      expect(table(tester).sortColumn, ComplaintTableColumn.priority);
      expect(table(tester).page, 0);
    });

    testWidgets('the side nav opens the bare list (filters are reset)', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'unresolved=1&created=all&q=lab',
      );
      expect(searchText(tester), 'lab');
      await tester.tap(
        find.descendant(
          of: find.byType(AdminSideNav),
          matching: find.text('Dashboard'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AdminSideNav),
          matching: find.text('Complaints'),
        ),
      );
      await tester.pumpAndSettle();
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
      expect(searchText(tester), isEmpty);
    });

    testWidgets('moving to another address while open updates the search box', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      container.read(appRouterProvider).go('/complaints?q=wifi&created=all');
      await tester.pumpAndSettle();
      expect(searchText(tester), 'wifi');
      container.read(appRouterProvider).go('/complaints');
      await tester.pumpAndSettle();
      expect(searchText(tester), isEmpty);
    });

    testWidgets('only filter values and view state are ever in the address', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      final RegExp allowed = RegExp(
        r'^(status|priority|category|department|building|q|unresolved|triage'
        r'|created|sort|dir|page|size)$',
      );
      await tapAndSettle(tester, chip('Unresolved only'));
      await typeSearch(tester, 'lab');
      await tapAndSettle(tester, find.text('UPDATED'));
      await tapAndSettle(tester, find.widgetWithText(AppButton, 'Next'));
      final Uri uri = container.read(appRouterProvider).state.uri;
      expect(uri.path, AppRoutes.complaints);
      expect(uri.queryParameters.keys.every(allowed.hasMatch), isTrue);
      expect(uri.toString(), isNot(contains('@')));
    });
  });

  group('sorting (AC-50)', () {
    testWidgets('a header click sorts, a second click reverses', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);

      await tapAndSettle(tester, find.text('UPDATED'));
      expect(location(container), '/complaints?sort=updated&dir=asc');
      expect(table(tester).sortColumn, ComplaintTableColumn.updated);
      expect(table(tester).sortAscending, isTrue);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      List<PublicComplaintView> rows = table(tester).complaints;
      for (int i = 1; i < rows.length; i++) {
        expect(rows[i - 1].updatedAt.isAfter(rows[i].updatedAt), isFalse);
      }

      await tapAndSettle(tester, find.text('UPDATED'));
      expect(location(container), '/complaints?sort=updated&dir=desc');
      expect(table(tester).sortAscending, isFalse);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      rows = table(tester).complaints;
      for (int i = 1; i < rows.length; i++) {
        expect(rows[i - 1].updatedAt.isBefore(rows[i].updatedAt), isFalse);
      }
    });

    testWidgets('every column sorts, one indicator at a time', (tester) async {
      final ProviderContainer container = await openList(tester);
      for (final ComplaintTableColumn c in ComplaintTableColumn.values) {
        await tapAndSettle(tester, find.text(c.title.toUpperCase()));
        final ComplaintListQuery q = ComplaintListQuery.fromQuery(
          container.read(appRouterProvider).state.uri.queryParameters,
        );
        expect(q.sortColumn, c, reason: c.title);
        expect(table(tester).sortColumn, c, reason: c.title);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Icon &&
                (w.icon == Icons.arrow_upward ||
                    w.icon == Icons.arrow_downward),
          ),
          findsOneWidget,
          reason: c.title,
        );
      }
    });

    testWidgets('Priority: the default is descending, a click reverses it', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      await tapAndSettle(tester, find.text('PRIORITY'));
      expect(location(container), '/complaints?sort=priority&dir=asc');
      expect(table(tester).complaints.first.effectivePriority, Priority.low);
      await tapAndSettle(tester, find.text('PRIORITY'));
      expect(location(container), '/complaints', reason: 'back to default');
      expect(rowIds(tester).first, 'CF-2026-00006');
    });

    testWidgets('sorting applies to the filtered list and keeps the filter', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'unresolved=1&created=all',
      );
      await tapAndSettle(tester, find.text('WAITING'));
      expect(
        location(container),
        '/complaints?unresolved=1&created=all&sort=waiting&dir=asc',
      );
      expect(table(tester).totalCount, 17);
      final List<PublicComplaintView> rows = table(tester).complaints;
      // Ascending waiting: the newest complaint first.
      for (int i = 1; i < rows.length; i++) {
        expect(rows[i - 1].createdAt.isBefore(rows[i].createdAt), isFalse);
      }
    });

    testWidgets('a sort from the address is applied and shown', (tester) async {
      await openList(tester, query: 'sort=id&dir=desc');
      expect(rowIds(tester).first, 'CF-2026-00029');
      expect(table(tester).sortColumn, ComplaintTableColumn.id);
      expect(table(tester).sortAscending, isFalse);
    });
  });

  group('pagination (25 / 50)', () {
    testWidgets('Next and Previous move between pages', (tester) async {
      final ProviderContainer container = await openList(tester);
      final List<String> first = rowIds(tester);

      await tapAndSettle(tester, find.widgetWithText(AppButton, 'Next'));
      expect(location(container), '/complaints?page=2');
      expect(table(tester).page, 1);
      expect(table(tester).complaints, hasLength(4));
      expect(find.text('26-29 of 29'), findsOneWidget);
      expect(
        rowIds(tester).toSet().intersection(first.toSet()),
        isEmpty,
        reason: 'the pages do not overlap',
      );
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Next'))
            .onPressed,
        isNull,
        reason: 'last page',
      );

      await tapAndSettle(tester, find.widgetWithText(AppButton, 'Previous'));
      expect(location(container), '/complaints');
      expect(rowIds(tester), first);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Previous'))
            .onPressed,
        isNull,
        reason: 'first page',
      );
    });

    testWidgets('50 per page shows everything and goes back to page one', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'page=2',
      );
      expect(table(tester).page, 1);
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AppSegmented<int>),
          matching: find.text('50'),
        ),
      );
      expect(location(container), '/complaints?size=50');
      expect(table(tester).rowsPerPage, 50);
      expect(table(tester).page, 0);
      expect(table(tester).complaints, hasLength(29));
      expect(find.text('1-29 of 29'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AppSegmented<int>),
          matching: find.text('25'),
        ),
      );
      expect(location(container), '/complaints');
      expect(table(tester).complaints, hasLength(25));
    });

    testWidgets('a page past the end shows the last page', (tester) async {
      await openList(tester, query: 'page=9');
      expect(table(tester).page, 1);
      expect(table(tester).complaints, hasLength(4));
      expect(find.text('26-29 of 29'), findsOneWidget);
    });

    testWidgets('the footer counts the filtered list', (tester) async {
      await openList(tester, query: 'unresolved=1&created=all');
      expect(find.text('1-17 of 17'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Next'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('page and size survive a sort click only as the first page', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'page=2&size=25',
      );
      await tapAndSettle(tester, find.text('STATUS'));
      expect(location(container), '/complaints?sort=status&dir=asc');
      expect(table(tester).page, 0);
    });
  });

  group('states (G-3, G-4, G-5)', () {
    testWidgets('loading: skeleton rows, the filter bar is already there', (
      tester,
    ) async {
      final StalledComplaintRepository stalled = StalledComplaintRepository();
      await openList(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(stalled),
        ],
      );
      expect(table(tester).loading, isTrue);
      expect(table(tester).complaints, isEmpty);
      expect(table(tester).totalCount, isNull, reason: 'no footer yet');
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(FilterBar), findsOneWidget);
      expect(find.text('No complaints yet'), findsNothing);
      expect(find.text('No complaints match'), findsNothing);
    });

    testWidgets('empty: no complaints at all', (tester) async {
      await openList(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(
            MockComplaintRepository(),
          ),
        ],
      );
      expect(find.text('No complaints yet'), findsOneWidget);
      expect(find.text('No complaints match'), findsNothing);
      expect(table(tester).complaints, isEmpty);
      expect(table(tester).loading, isFalse);
      expect(find.text('0-0 of 0'), findsOneWidget);
    });

    testWidgets('filtered-empty: "No complaints match" and a Reset action', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'q=no+such+thing+anywhere',
      );
      expect(find.text('No complaints match'), findsOneWidget);
      expect(find.text('No complaints yet'), findsNothing);
      expect(table(tester).complaints, isEmpty);
      expect(table(tester).totalCount, 0);
      // Reset is offered by the filter bar and by the empty state itself.
      expect(find.text('Reset filters'), findsNWidgets(2));

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.text('Reset filters'),
        ),
      );
      expect(location(container), '/complaints');
      expect(table(tester).totalCount, 29);
      expect(find.text('No complaints match'), findsNothing);
      expect(searchText(tester), isEmpty);
    });

    testWidgets('filtered-empty through the UI: contradictory filters', (
      tester,
    ) async {
      await openList(tester, query: 'triage=1&status=closed&created=all');
      expect(find.text('No complaints match'), findsOneWidget);
      await tapAndSettle(tester, resetInBar());
      expect(table(tester).totalCount, 29);
    });

    testWidgets('error: a message and Retry, then the table', (tester) async {
      await openList(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(
            FlakyComplaintRepository(initial: testSeed.complaints),
          ),
        ],
      );
      expect(find.text("Couldn't load complaints"), findsOneWidget);
      expect(find.byType(ComplaintTable), findsNothing);
      expect(find.byType(FilterBar), findsOneWidget);

      await tapAndSettle(tester, find.text('Retry'));
      expect(find.text("Couldn't load complaints"), findsNothing);
      expect(table(tester).totalCount, 29);
    });

    testWidgets('live: a status change moves the list without a reload', (
      tester,
    ) async {
      final ProviderContainer container = await openList(
        tester,
        query: 'status=assigned&created=all',
      );
      expect(table(tester).totalCount, 4);

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

      expect(table(tester).totalCount, 3);
      expect(shownIds(tester), isNot(contains(assigned.id)));
    });
  });

  group('opening a complaint (A-04) and coming back', () {
    testWidgets('a row opens the complaint; the route carries only its ID', (
      tester,
    ) async {
      final ProviderContainer container = await openList(tester);
      final String id = rowIds(tester).first;
      await tapAndSettle(tester, find.text(id));
      expect(location(container), AppRoutes.complaint(id));
      expect(Uri.parse(location(container)).query, isEmpty);
      expect(find.byType(ComplaintDetailScreen), findsOneWidget);
    });

    testWidgets('Back returns to the same filters, sort and page, with the '
        'row still highlighted', (tester) async {
      final ProviderContainer container = await openList(
        tester,
        query:
            'unresolved=1&priority=critical,high&created=all'
            '&sort=updated&dir=asc',
      );
      final String url = location(container);
      final List<String> order = rowIds(tester);
      final String id = order[2];

      await tapAndSettle(tester, find.text(id));
      expect(location(container), AppRoutes.complaint(id));

      container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(location(container), url);
      expect(rowIds(tester), order);
      expect(table(tester).selectedId, id);
      expect(chipWidget(tester, 'Priority').count, 2);
      expect(table(tester).sortColumn, ComplaintTableColumn.updated);
    });
  });

  group('privacy (AC-48, R5, PV-5)', () {
    testWidgets('no reporter identity anywhere on the list, for either role', (
      tester,
    ) async {
      // Positive control: the sentinels are real. The top bar shows the
      // signed-in user's own name, so a sweep of the whole page finds it, and
      // the list sweeps below are scoped to the list screen.
      await openList(tester);
      expect(identityLeaks(allRenderedText(tester)), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        final ProviderContainer container = await openList(tester, role: role);
        final List<String> queries = <String>[
          '',
          'created=all&unresolved=1',
          'page=2',
          'size=50',
          'q=lab&created=all',
          'status=reported&created=all',
          'sort=location&dir=asc',
          'triage=1&created=all',
          'q=no+such+thing+anywhere',
        ];
        for (final String q in queries) {
          container
              .read(appRouterProvider)
              .go(q.isEmpty ? AppRoutes.complaints : '/complaints?$q');
          await tester.pumpAndSettle();
          final String text = allRenderedText(
            tester,
            within: find.byType(ComplaintListScreen),
          );
          expect(identityLeaks(text), isEmpty, reason: '$role $q');
        }
        // With a menu open too.
        await openMenu(tester, 'Department');
        expect(
          identityLeaks(
            allRenderedText(tester, within: find.byType(ComplaintListScreen)),
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('searching a person finds nobody (no reporter-based search)', (
      tester,
    ) async {
      await openList(tester);
      final ReporterIdentity r = testSeed.complaints.first.reporter;
      for (final String needle in <String>[r.email, r.idNumber, r.userId]) {
        await typeSearch(tester, needle);
        expect(table(tester).totalCount, 0, reason: needle);
        expect(find.text('No complaints match'), findsOneWidget);
      }
      // The address holds what was typed, nothing resolved about the person.
      expect(
        allRenderedText(tester, within: find.byType(ComplaintTable)),
        isNot(contains(r.fullName)),
      );
    });
  });
}
