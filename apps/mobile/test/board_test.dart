import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/features/board/board_query.dart';
import 'package:campusfix_mobile/features/board/board_screen.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:campusfix_mobile/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/rendered_text.dart';

/// Every seed complaint as the board sees it.
List<PublicComplaintView> allViews() => toPublicViews(testSeed.complaints);

/// The default board: not closed, most urgent then newest.
List<PublicComplaintView> defaultBoard() =>
    const BoardFilters().apply(allViews());

/// IDs of the cards currently built, top to bottom.
List<String> shownIds(WidgetTester tester) => <String>[
  for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
    find.byType(ComplaintCard),
  ))
    c.complaint.id,
];

Finder chip(String label) => find.widgetWithText(AppFilterChip, label);

/// Taps a filter chip, first scrolling the filter row so it is on screen.
Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(chip(label));
  await tester.pumpAndSettle();
  await tester.tap(chip(label));
  await tester.pumpAndSettle();
}

/// A row of the open bottom sheet (cards behind it may repeat the label).
Finder sheetRow(String label) =>
    find.descendant(of: find.byType(AppSheetBody), matching: find.text(label));

Future<void> pickMany(
  WidgetTester tester,
  String chipLabel,
  List<String> options,
) async {
  await tapChip(tester, chipLabel);
  for (final String o in options) {
    await tester.tap(sheetRow(o));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(AppButton, 'Done'));
  await tester.pumpAndSettle();
}

Finder countText(int n) => find.text(n == 1 ? '1 complaint' : '$n complaints');

Future<ProviderContainer> openBoard(
  WidgetTester tester, {
  UserRole role = UserRole.reporter,
  double? height = 6000,
  List<Override> overrides = const <Override>[],
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: overrides,
  );
  await signInAs(tester, role);
  if (height != null) useTallView(tester, height: height);
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Board'),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('the default board excludes closed complaints, most urgent '
      'then newest first (AC-28)', (tester) async {
    await openBoard(tester);

    final List<String> expected = <String>[
      for (final PublicComplaintView c in defaultBoard()) c.id,
    ];
    expect(expected.length, greaterThan(boardPageSize));
    expect(
      defaultBoard().any((c) => c.status == ComplaintStatus.closed),
      isFalse,
    );
    expect(countText(expected.length), findsOneWidget);
    expect(shownIds(tester), expected);
    // Priority never increases down the list.
    final List<int> weights = <int>[
      for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
        find.byType(ComplaintCard),
      ))
        c.complaint.effectivePriority.weight,
    ];
    for (int i = 1; i < weights.length; i++) {
      expect(weights[i], lessThanOrEqualTo(weights[i - 1]));
    }
    expect(find.byType(FilterBar), findsOneWidget);
    expect(find.byType(AppSearchField), findsOneWidget);
    expect(find.textContaining('Identity is hidden'), findsOneWidget);
  });

  testWidgets('lists a page of 20 and loads more on scroll', (tester) async {
    await openBoard(tester, height: null);
    final List<String> expected = <String>[
      for (final PublicComplaintView c in defaultBoard()) c.id,
    ];

    // Lazily built: far fewer than the whole list at first.
    expect(shownIds(tester).length, lessThan(expected.length));
    expect(shownIds(tester).take(3), expected.take(3));

    await tester.scrollUntilVisible(
      find.text(expected.last),
      400,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text(expected.last), findsOneWidget);
  });

  testWidgets('category, priority and status filters narrow the list and '
      'AND together (M-11)', (tester) async {
    await openBoard(tester);
    final List<PublicComplaintView> open = defaultBoard();

    // Category (multi).
    await pickMany(tester, 'Category', <String>['Electrical']);
    List<PublicComplaintView> expected = <PublicComplaintView>[
      for (final c in open)
        if (c.category == ProblemCategory.electrical) c,
    ];
    expect(expected, isNotEmpty);
    expect(countText(expected.length), findsOneWidget);
    expect(shownIds(tester), <String>[for (final c in expected) c.id]);

    await pickMany(tester, 'Category', <String>['Plumbing / Water / Washroom']);
    expected = <PublicComplaintView>[
      for (final c in open)
        if (c.category == ProblemCategory.electrical ||
            c.category == ProblemCategory.plumbing)
          c,
    ];
    expect(shownIds(tester), <String>[for (final c in expected) c.id]);

    // Priority (multi) ANDs with the category.
    final Priority priority = expected.first.effectivePriority;
    await pickMany(tester, 'Priority', <String>[priority.label]);
    final List<PublicComplaintView> both = <PublicComplaintView>[
      for (final c in expected)
        if (c.effectivePriority == priority) c,
    ];
    expect(both.length, lessThanOrEqualTo(expected.length));
    expect(shownIds(tester), <String>[for (final c in both) c.id]);

    // Status (multi) narrows further.
    final ComplaintStatus status = both.first.status;
    await pickMany(tester, 'Status', <String>[status.label]);
    final List<PublicComplaintView> all3 = <PublicComplaintView>[
      for (final c in both)
        if (c.status == status) c,
    ];
    expect(shownIds(tester), <String>[for (final c in all3) c.id]);

    // Clear filters resets everything.
    await tester.tap(find.widgetWithText(AppButton, 'Clear filters'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppButton, 'Clear filters'), findsNothing);
    expect(countText(open.length), findsOneWidget);
  });

  testWidgets('building, include closed and search', (tester) async {
    await openBoard(tester);
    final List<PublicComplaintView> open = defaultBoard();

    // Building (single).
    final String building = open.first.building;
    await tapChip(tester, 'Building');
    await tester.tap(sheetRow(building));
    await tester.pumpAndSettle();
    List<PublicComplaintView> expected = <PublicComplaintView>[
      for (final c in open)
        if (c.building == building) c,
    ];
    expect(countText(expected.length), findsOneWidget);
    expect(shownIds(tester), <String>[for (final c in expected) c.id]);

    // Back to any building.
    await tapChip(tester, building);
    await tester.tap(sheetRow('Any building'));
    await tester.pumpAndSettle();
    expect(countText(open.length), findsOneWidget);

    // Include closed.
    await tapChip(tester, 'Include closed');
    expect(countText(allViews().length), findsOneWidget);
    await tapChip(tester, 'Include closed');
    expect(countText(open.length), findsOneWidget);

    // Search by ID, and by location text.
    final PublicComplaintView target = open.last;
    await tester.enterText(find.byType(TextField), target.id);
    await tester.pumpAndSettle();
    expect(shownIds(tester), <String>[target.id]);
    expect(countText(1), findsOneWidget);

    await tester.enterText(find.byType(TextField), target.room.toUpperCase());
    await tester.pumpAndSettle();
    expect(shownIds(tester), contains(target.id));
  });

  testWidgets('closed complaints show when Closed is picked as a status', (
    tester,
  ) async {
    await openBoard(tester);
    await pickMany(tester, 'Status', <String>['Closed']);
    final List<String> closed = <String>[
      for (final c in allViews())
        if (c.status == ComplaintStatus.closed) c.id,
    ];
    expect(closed, isNotEmpty);
    expect(shownIds(tester).toSet(), closed.toSet());
  });

  testWidgets('sorting: newest, oldest and recently updated', (tester) async {
    await openBoard(tester);
    final List<PublicComplaintView> open = defaultBoard();

    Future<void> sortBy(String from, String label) async {
      await tapChip(tester, 'Sort: $from');
      await tester.tap(sheetRow(label));
      await tester.pumpAndSettle();
    }

    await sortBy('Priority', 'Oldest');
    expect(shownIds(tester), <String>[
      for (final c in <PublicComplaintView>[
        ...open,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        c.id,
    ]);
    await sortBy('Oldest', 'Newest');
    expect(shownIds(tester), <String>[
      for (final c in <PublicComplaintView>[
        ...open,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        c.id,
    ]);
    await sortBy('Newest', 'Recently updated');
    expect(shownIds(tester), <String>[
      for (final c in <PublicComplaintView>[
        ...open,
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        c.id,
    ]);
  });

  testWidgets('a search with no result offers Clear filters', (tester) async {
    await openBoard(tester);
    await tester.enterText(find.byType(TextField), 'zzz-no-such-complaint');
    await tester.pumpAndSettle();
    expect(find.text('No matching complaints'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(countText(defaultBoard().length), findsOneWidget);
  });

  testWidgets('no open complaints on campus', (tester) async {
    await openBoard(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          MockComplaintRepository(
            initial: <Complaint>[
              for (final c in testSeed.complaints)
                if (c.status == ComplaintStatus.closed) c,
            ],
          ),
        ),
      ],
    );
    expect(find.text('No open complaints on campus'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with Retry', (tester) async {
    await openBoard(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          FlakyComplaintRepository(initial: testSeed.complaints),
        ),
      ],
    );
    expect(find.text("Couldn't load the campus board"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(countText(defaultBoard().length), findsOneWidget);
  });

  testWidgets('the board shows no identity and no "mine" marker (AC-30, '
      'R6)', (tester) async {
    await openBoard(tester);
    // Include closed so every complaint of the seed is on screen.
    await tapChip(tester, 'Include closed');

    final String text = allRenderedText(tester);
    expect(identityLeaks(text), isEmpty);
    // Every card is the plain board card: no "mine" variant or marker.
    for (final ComplaintCard card in tester.widgetList<ComplaintCard>(
      find.byType(ComplaintCard),
    )) {
      expect(card.variant, ComplaintCardVariant.board);
    }
    // Public fields are there.
    expect(find.text(defaultBoard().first.id), findsOneWidget);
  });

  testWidgets('a board item shows only the public fields, with no tracking '
      'history (M-11b)', (tester) async {
    final ProviderContainer container = await openBoard(tester);
    // A complaint with a department, notes and a resolution: all of which a
    // board item must leave out.
    final Complaint rich = testSeed.complaints.firstWhere(
      (c) =>
          c.assignment != null &&
          c.timeline.any((e) => e.note != null) &&
          c.status != ComplaintStatus.closed,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is ComplaintCard && w.complaint.id == rich.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.boardItem(rich.id),
    );
    expect(find.text('Board item'), findsOneWidget);
    expect(find.text(rich.id), findsOneWidget);
    expect(find.text(rich.category.label), findsOneWidget);
    expect(
      find.text('${rich.building} · ${rich.floor} · ${rich.room}'),
      findsOneWidget,
    );
    expect(find.text(rich.description), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byType(PriorityTag), findsOneWidget);
    expect(find.byType(PhotoThumbnail), findsWidgets);

    // Not shown on the board (privacy-spec section 4).
    for (final String hidden in <String>[
      'Timeline',
      'Progress',
      'Assigned department',
      'Resolution note',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.byType(ComplaintTimeline), findsNothing);
    expect(find.byType(StatusStepper), findsNothing);
    for (final StatusEvent e in rich.timeline) {
      if (e.note != null) expect(find.text(e.note!), findsNothing);
    }
    expect(identityLeaks(allRenderedText(tester)), isEmpty);

    // Back returns to the board.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Campus Board'), findsWidgets);
  });

  for (final UserRole role in <UserRole>[
    UserRole.maintenance,
    UserRole.verifier,
  ]) {
    testWidgets('${role.label} reads the board and a board item, with no '
        'report button', (tester) async {
      final ProviderContainer container = await openBoard(tester, role: role);
      expect(countText(defaultBoard().length), findsOneWidget);
      expect(find.text('Report a Problem'), findsNothing);

      final String id = defaultBoard().first.id;
      await openRoute(tester, container, AppRoutes.boardItem(id));
      expect(find.text(id), findsOneWidget);
      expect(find.text('Timeline'), findsNothing);
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  }

  group('BoardFilters', () {
    final List<PublicComplaintView> all = allViews();

    test(
      'the default hides closed and sorts by priority weight then newest',
      () {
        final List<PublicComplaintView> list = const BoardFilters().apply(all);
        expect(list.every((c) => c.status != ComplaintStatus.closed), isTrue);
        for (int i = 1; i < list.length; i++) {
          final int a = list[i - 1].effectivePriority.weight;
          final int b = list[i].effectivePriority.weight;
          expect(b, lessThanOrEqualTo(a));
          if (a == b) {
            expect(list[i].createdAt.isAfter(list[i - 1].createdAt), isFalse);
          }
        }
      },
    );

    test('hasActive ignores the sort order', () {
      expect(const BoardFilters().hasActive, isFalse);
      expect(const BoardFilters(sort: BoardSort.oldest).hasActive, isFalse);
      expect(const BoardFilters(includeClosed: true).hasActive, isTrue);
      expect(const BoardFilters(query: ' x ').hasActive, isTrue);
    });
  });
}
