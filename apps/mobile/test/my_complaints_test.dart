import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/features/my_complaints/my_complaints_screen.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:campusfix_mobile/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';

/// The IDs of the complaint cards currently built, top to bottom.
List<String> shownIds(WidgetTester tester) => <String>[
  for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
    find.byType(ComplaintCard),
  ))
    c.complaint.id,
];

/// The seed's complaints of the demo reporter, `updatedAt` descending.
List<Complaint> ownSeedComplaints() {
  final String me = demoAccount(UserRole.reporter).user.id;
  return <Complaint>[
    for (final Complaint c in testSeed.complaints)
      if (c.reporter.userId == me) c,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

Future<ProviderContainer> openMyComplaints(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: overrides,
  );
  await signInAs(tester, UserRole.reporter);
  useTallView(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('My Complaints'),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('lists the reporter\'s own complaints, newest update first, '
      'and no one else\'s (AC-23)', (tester) async {
    await openMyComplaints(tester);

    final List<String> expected = <String>[
      for (final Complaint c in ownSeedComplaints()) c.id,
    ];
    expect(expected, hasLength(5));
    expect(shownIds(tester), expected);

    // Another reporter's complaints never appear.
    final String me = demoAccount(UserRole.reporter).user.id;
    for (final Complaint c in testSeed.complaints) {
      if (c.reporter.userId != me) {
        expect(find.text(c.id), findsNothing, reason: c.id);
      }
    }

    // Every card is the "mine" variant with status and priority.
    for (final ComplaintCard card in tester.widgetList<ComplaintCard>(
      find.byType(ComplaintCard),
    )) {
      expect(card.variant, ComplaintCardVariant.mine);
    }
    expect(find.byType(StatusBadge), findsNWidgets(5));
    expect(find.byType(PriorityTag), findsNWidgets(5));
    expect(find.text('Report a Problem'), findsOneWidget); // the FAB
  });

  testWidgets('segments split Active and Closed (M-09)', (tester) async {
    await openMyComplaints(tester);
    final List<Complaint> own = ownSeedComplaints();
    final List<String> open = <String>[
      for (final Complaint c in own)
        if (c.status != ComplaintStatus.closed) c.id,
    ];
    final List<String> closed = <String>[
      for (final Complaint c in own)
        if (c.status == ComplaintStatus.closed) c.id,
    ];
    expect(closed, isNotEmpty);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), open);

    await tester.tap(find.text('Closed'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), closed);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(own.length));
  });

  testWidgets('search by ID or description, with a filtered-empty state and '
      'Clear', (tester) async {
    await openMyComplaints(tester);
    final Complaint target = ownSeedComplaints().first;

    await tester.enterText(find.byType(TextField), target.id);
    await tester.pumpAndSettle();
    expect(shownIds(tester), <String>[target.id]);

    // A word of the description finds it too.
    final String word = target.description
        .split(' ')
        .firstWhere((w) => w.length > 5);
    await tester.enterText(find.byType(TextField), word.toUpperCase());
    await tester.pumpAndSettle();
    expect(shownIds(tester), contains(target.id));

    await tester.enterText(find.byType(TextField), 'zzz-no-such-complaint');
    await tester.pumpAndSettle();
    expect(find.text('No matching complaints'), findsOneWidget);
    expect(find.byType(ComplaintCard), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(5));
  });

  testWidgets('tapping a card opens its details (M-10)', (tester) async {
    final ProviderContainer container = await openMyComplaints(tester);
    final String id = ownSeedComplaints().first.id;

    await tester.tap(
      find.byWidgetPredicate((w) => w is ComplaintCard && w.complaint.id == id),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.complaint(id),
    );
    expect(find.text('Complaint details'), findsOneWidget);
  });

  testWidgets('a new complaint appears at the top without a refresh '
      '(AC-24)', (tester) async {
    final ProviderContainer container = await openMyComplaints(tester);
    final List<String> before = shownIds(tester);

    final AppUser me = demoAccount(UserRole.reporter).user;
    final Complaint draft = testSeed.complaints
        .firstWhere((c) => c.reporter.userId == me.id)
        .copyWith(
          id: 'CF-2026-09999',
          description: 'A brand new problem filed from the test.',
          status: ComplaintStatus.reported,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          timeline: const <StatusEvent>[],
          afterPhotos: const <Attachment>[],
          clearAssignment: true,
          clearResolutionNote: true,
        );
    await container.read(complaintRepositoryProvider).submit(draft);
    await tester.pumpAndSettle();

    final List<String> after = shownIds(tester);
    expect(after.first, 'CF-2026-09999');
    expect(after.skip(1), before);
  });

  testWidgets('nothing reported yet: empty state with a call to action, and '
      'no duplicate floating button', (tester) async {
    await openMyComplaints(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          MockComplaintRepository(),
        ),
      ],
    );

    expect(find.text("You haven't reported anything yet"), findsOneWidget);
    expect(find.byType(ComplaintCard), findsNothing);
    expect(find.text('Report a Problem'), findsOneWidget);
    await tester.tap(find.text('Report a Problem'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5 · Category'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with Retry', (tester) async {
    await openMyComplaints(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          FlakyComplaintRepository(initial: testSeed.complaints),
        ),
      ],
    );

    expect(find.text("Couldn't load your complaints"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your complaints"), findsNothing);
    expect(shownIds(tester), hasLength(5));
  });

  testWidgets('while loading it shows skeleton cards', (tester) async {
    final ProviderContainer container = await pumpCampusFix(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          StalledComplaintRepository(),
        ),
      ],
    );
    await signInAs(tester, UserRole.reporter);
    container.read(appRouterProvider).go(AppRoutes.complaints);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ComplaintCardSkeleton), findsWidgets);
    expect(find.byType(ComplaintCard), findsNothing);
  });

  test('filterMyComplaints narrows by segment and query', () {
    final List<PublicComplaintView> all = toPublicViews(testSeed.complaints);
    final List<PublicComplaintView> active = filterMyComplaints(
      all,
      segment: MyComplaintsSegment.active,
      query: '',
    );
    expect(active.every((c) => c.status != ComplaintStatus.closed), isTrue);
    final List<PublicComplaintView> closed = filterMyComplaints(
      all,
      segment: MyComplaintsSegment.closed,
      query: '',
    );
    expect(closed.every((c) => c.status == ComplaintStatus.closed), isTrue);
    expect(active.length + closed.length, all.length);
    expect(
      filterMyComplaints(
        all,
        segment: MyComplaintsSegment.all,
        query: all.first.id.toLowerCase(),
      ).map((c) => c.id),
      <String>[all.first.id],
    );
  });
}
