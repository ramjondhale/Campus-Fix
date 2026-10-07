import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/features/complaint_details/complaint_details_view.dart';
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
import 'support/work_fixtures.dart';

/// The IDs of the complaint cards currently built, top to bottom.
List<String> shownIds(WidgetTester tester) => <String>[
  for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
    find.byType(ComplaintCard),
  ))
    c.complaint.id,
];

/// [ids] in the order the work queue lists them: most urgent first, then the
/// longest waiting (screens-spec M-13).
List<String> queueOrder(Iterable<String> ids) {
  final List<Complaint> jobs =
      <Complaint>[
        for (final Complaint c in workSeed())
          if (ids.contains(c.id)) c,
      ]..sort((a, b) {
        final int byWeight = b.effectivePriority.weight.compareTo(
          a.effectivePriority.weight,
        );
        return byWeight != 0 ? byWeight : a.createdAt.compareTo(b.createdAt);
      });
  return <String>[for (final Complaint c in jobs) c.id];
}

Finder button(String label) => find.byWidgetPredicate(
  (Widget w) => w is AppButton && w.label == label,
  description: 'AppButton "$label"',
);

Finder dialogButton(String label) =>
    find.descendant(of: find.byType(AppDialog), matching: button(label));

bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(button(label)).onPressed != null;

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(button(label));
  await tester.pumpAndSettle();
}

String pathOf(ProviderContainer container) =>
    container.read(appRouterProvider).state.uri.path;

/// Signs the demo maintenance worker in and opens the work queue from Home.
Future<ProviderContainer> openWork(
  WidgetTester tester, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await signedInAsMaintenance(
    tester,
    repository: repository,
  );
  await tester.tap(find.text('Open my work'));
  await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> signedInAsMaintenance(
  WidgetTester tester, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: <Override>[
      complaintRepositoryProvider.overrideWithValue(
        repository ?? workRepository(),
      ),
    ],
  );
  await signInAs(tester, UserRole.maintenance);
  useTallView(tester);
  return container;
}

/// Opens [location] as the signed-in maintenance worker.
Future<ProviderContainer> openAt(
  WidgetTester tester,
  String location, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await signedInAsMaintenance(
    tester,
    repository: repository,
  );
  await openRoute(tester, container, location);
  return container;
}

Future<Complaint> stored(ProviderContainer container, String id) async =>
    (await container.read(complaintRepositoryProvider).byId(id))!;

Finder noteField(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

/// Adds one sample after-photo through the picker sheet.
Future<void> addAfterPhoto(WidgetTester tester) async {
  final Finder add = find.text('Add a photo').evaluate().isNotEmpty
      ? find.text('Add a photo')
      : find.text('Add photo');
  await tester.tap(add);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Take a photo (sample)'));
  await tester.pumpAndSettle();
}

Future<void> typeResolutionNote(WidgetTester tester, String text) async {
  await tester.enterText(noteField('Resolution note'), text);
  await tester.pump();
}

void main() {
  group('M-13 Assigned Work', () {
    testWidgets('three tabs list the right jobs, most urgent then oldest '
        'first, and the counts equal Home (AC-33, AC-34)', (tester) async {
      final ProviderContainer container = await signedInAsMaintenance(tester);

      // Home counts first.
      final List<String> homeCounts = <String>[
        for (final MetricCard m in tester.widgetList<MetricCard>(
          find.byType(MetricCard),
        ))
          m.value,
      ];
      expect(homeCounts, <String>['2', '1', '1']);

      await tester.tap(find.text('Open my work'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.work);
      expect(find.text('Assigned work'), findsOneWidget);
      expect(find.text('To start (2)'), findsOneWidget);
      expect(find.text('In progress (1)'), findsOneWidget);
      expect(find.text('Rework (1)'), findsOneWidget);

      // To start (the default tab).
      expect(shownIds(tester), queueOrder(<String>[toStartA, toStartB]));
      for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
        find.byType(ComplaintCard),
      )) {
        expect(c.variant, ComplaintCardVariant.work);
      }
      expect(find.byType(StatusBadge), findsNWidgets(2));
      expect(find.byType(PriorityTag), findsNWidgets(2));

      await tester.tap(find.text('In progress (1)'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), <String>[inProgressJob]);

      await tester.tap(find.text('Rework (1)'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), <String>[reworkJob]);
    });

    testWidgets('a colleague\'s work and other departments\' complaints '
        'never appear (AC-33, P7)', (tester) async {
      await openWork(tester);
      final Set<String> mine = <String>{
        toStartA,
        toStartB,
        inProgressJob,
        reworkJob,
      };
      final Set<String> everyShown = <String>{};
      for (final String tab in <String>[
        'To start (2)',
        'In progress (1)',
        'Rework (1)',
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        everyShown.addAll(shownIds(tester));
      }
      expect(everyShown, mine);
      expect(everyShown, isNot(contains(colleagueInProgress)));
      expect(everyShown, isNot(contains(assignedToColleague)));
      expect(everyShown, isNot(contains(plumberJob)));
    });

    testWidgets('tapping a card opens the work detail (M-14)', (tester) async {
      final ProviderContainer container = await openWork(tester);
      final String first = queueOrder(<String>[toStartA, toStartB]).first;

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ComplaintCard && w.complaint.id == first,
        ),
      );
      await tester.pumpAndSettle();

      expect(pathOf(container), AppRoutes.workItem(first));
      expect(find.text('Work detail'), findsOneWidget);

      // Back lands on the queue it came from.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.work);
      expect(find.text('Assigned work'), findsOneWidget);
    });

    testWidgets('nothing assigned: "No work assigned to <department>"', (
      tester,
    ) async {
      await openWork(tester, repository: MockComplaintRepository());

      expect(
        find.text('No work assigned to $meDepartmentLabel'),
        findsOneWidget,
      );
      expect(find.byType(ComplaintCard), findsNothing);
      expect(find.text('To start (0)'), findsOneWidget);
    });

    testWidgets('an empty tab says what it is for while the others have '
        'work', (tester) async {
      // A queue with only one to-start job.
      final ProviderContainer container = await signedInAsMaintenance(
        tester,
        repository: MockComplaintRepository(
          initial: <Complaint>[
            for (final Complaint c in workSeed())
              if (c.id == toStartA) c,
          ],
        ),
      );
      await openRoute(tester, container, AppRoutes.work);
      expect(shownIds(tester), <String>[toStartA]);

      await tester.tap(find.text('In progress (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing in progress'), findsOneWidget);
      expect(find.text('No work assigned to $meDepartmentLabel'), findsNothing);

      await tester.tap(find.text('Rework (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No rework needed'), findsOneWidget);
    });

    testWidgets('a failed load shows an error with Retry', (tester) async {
      await openWork(
        tester,
        repository: FlakyComplaintRepository(initial: workSeed()),
      );

      expect(find.text("Couldn't load your work"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load your work"), findsNothing);
      expect(shownIds(tester), hasLength(2));
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
      await signInAs(tester, UserRole.maintenance);
      container.read(appRouterProvider).go(AppRoutes.work);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ComplaintCardSkeleton), findsWidgets);
      expect(find.byType(ComplaintCard), findsNothing);
    });

    testWidgets('a new assignment appears without a refresh', (tester) async {
      final ProviderContainer container = await openWork(tester);
      expect(shownIds(tester), hasLength(2));

      final Complaint another = (await stored(
        container,
        toStartA,
      )).copyWith(id: 'CF-2026-09001');
      await container.read(complaintRepositoryProvider).submit(another);
      await tester.pumpAndSettle();

      expect(shownIds(tester), contains('CF-2026-09001'));
      expect(find.text('To start (3)'), findsOneWidget);
    });

    testWidgets('shows no identity', (tester) async {
      await openWork(tester);
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  });

  group('M-14 Work Detail', () {
    testWidgets('an assigned job offers Start work with an optional note, '
        'and no resolve', (tester) async {
      await openAt(tester, AppRoutes.workItem(toStartA));

      expect(find.byType(ComplaintDetailsView), findsOneWidget);
      expect(find.text('Work detail'), findsOneWidget);
      expect(find.text(toStartA), findsWidgets);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.assigned,
      );
      expect(button('Start work'), findsOneWidget);
      expect(isEnabled(tester, 'Start work'), isTrue);
      expect(button('Mark as resolved'), findsNothing);
      expect(find.text('Note (optional)'), findsOneWidget);
      expect(find.textContaining('Visible to people involved'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);
    });

    testWidgets('an in-progress job of mine offers Mark as resolved, and no '
        'start', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(inProgressJob),
      );

      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.inProgress,
      );
      expect(button('Mark as resolved'), findsOneWidget);
      expect(button('Start work'), findsNothing);
      expect(find.text('Note (optional)'), findsNothing);

      await tapButton(tester, 'Mark as resolved');
      expect(pathOf(container), AppRoutes.workResolve(inProgressJob));
      expect(find.text('After-repair photos'), findsOneWidget);
    });

    testWidgets('Start work claims the job and the screen updates in place '
        '(AC-35)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(toStartA),
      );
      final int events = (await stored(container, toStartA)).timeline.length;

      await tester.enterText(noteField('Note (optional)'), 'Bringing a ladder');
      await tester.pump();
      expect(find.text('17/500'), findsOneWidget);
      await tapButton(tester, 'Start work');

      // The screen reflects the new status without leaving.
      expect(pathOf(container), AppRoutes.workItem(toStartA));
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.inProgress,
      );
      expect(button('Start work'), findsNothing);
      expect(button('Mark as resolved'), findsOneWidget);
      expect(find.text('Work started'), findsOneWidget); // toast
      expect(find.text('Bringing a ladder'), findsWidgets); // timeline note

      final Complaint after = await stored(container, toStartA);
      expect(after.status, ComplaintStatus.inProgress);
      expect(after.timeline, hasLength(events + 1));
      expect(after.timeline.last.actorRole, UserRole.maintenance);
      expect(after.timeline.last.note, 'Bringing a ladder');
      expect(after.assignment!.assigneeId, meId);
    });

    testWidgets('a colleague holds the job: Start work shows the P7 message '
        'and changes nothing (AC-36)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(assignedToColleague),
      );
      final Complaint before = await stored(container, assignedToColleague);

      await tapButton(tester, 'Start work');

      expect(find.text("Couldn't start the work"), findsOneWidget);
      expect(
        find.textContaining('Already claimed by a colleague.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing, reason: 'a rule block');
      expect(await stored(container, assignedToColleague), before);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.assigned,
      );
    });

    testWidgets('a job a colleague is working on offers no action', (
      tester,
    ) async {
      await openAt(tester, AppRoutes.workItem(colleagueInProgress));

      expect(find.text('Already claimed by a colleague.'), findsOneWidget);
      expect(button('Mark as resolved'), findsNothing);
      expect(button('Start work'), findsNothing);
    });

    testWidgets('a rework job shows the verifier\'s rejection note '
        'prominently', (tester) async {
      await openAt(tester, AppRoutes.workItem(reworkJob));

      final String note = testSeed.complaints
          .firstWhere((c) => c.id == reworkJob)
          .timeline
          .last
          .note!;
      expect(find.text('Rework needed'), findsOneWidget);
      expect(find.text(note), findsWidgets);
      expect(button('Mark as resolved'), findsOneWidget);
    });

    testWidgets('a failed start keeps the note and offers Retry (G-4)', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(toStartA),
        repository: FlakyWriteComplaintRepository(initial: workSeed()),
      );
      await tester.enterText(noteField('Note (optional)'), 'Back at noon');
      await tester.pump();
      await tapButton(tester, 'Start work');

      expect(find.text("Couldn't start the work"), findsOneWidget);
      expect(
        find.textContaining('Nothing you entered was lost'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(noteField('Note (optional)')).controller!.text,
        'Back at noon',
      );
      expect(
        (await stored(container, toStartA)).status,
        ComplaintStatus.assigned,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't start the work"), findsNothing);
      expect(
        (await stored(container, toStartA)).status,
        ComplaintStatus.inProgress,
      );
    });

    testWidgets('while starting the button shows progress and a second tap '
        'is ignored (G-3)', (tester) async {
      final SlowWriteComplaintRepository slow = SlowWriteComplaintRepository(
        initial: workSeed(),
      );
      await openAt(tester, AppRoutes.workItem(toStartA), repository: slow);

      await tester.tap(button('Start work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<AppButton>(button('Start work')).loading, isTrue);

      await tester.tap(button('Start work'), warnIfMissed: false);
      await tester.pump();
      expect(slow.writes, 1);

      slow.release();
      await tester.pumpAndSettle();
      expect(button('Mark as resolved'), findsOneWidget);
      expect(slow.writes, 1);
    });

    testWidgets('an unknown job and another department\'s job show E-404, '
        'never revealing which', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem('CF-2026-99999'),
      );
      expect(find.text("We couldn't find that complaint"), findsOneWidget);
      final String unknown = allRenderedText(tester);

      await openRoute(tester, container, AppRoutes.workItem(plumberJob));
      expect(find.text("We couldn't find that complaint"), findsOneWidget);
      expect(button('Start work'), findsNothing);
      expect(allRenderedText(tester), unknown);
    });

    testWidgets('a failed load shows an error with Retry, and loading a '
        'skeleton', (tester) async {
      await openAt(
        tester,
        AppRoutes.workItem(toStartA),
        repository: FlakyComplaintRepository(initial: workSeed()),
      );
      expect(find.text("Couldn't load this complaint"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(button('Start work'), findsOneWidget);
    });

    testWidgets('while loading it shows a skeleton', (tester) async {
      final ProviderContainer container = await pumpCampusFix(
        tester,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(
            StalledComplaintRepository(),
          ),
        ],
      );
      await signInAs(tester, UserRole.maintenance);
      container.read(appRouterProvider).go(AppRoutes.workItem(toStartA));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ComplaintDetailsSkeleton), findsOneWidget);
      expect(button('Start work'), findsNothing);
    });

    testWidgets('shows no identity', (tester) async {
      await openAt(tester, AppRoutes.workItem(reworkJob));
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  });

  group('M-15 After-Repair Upload', () {
    testWidgets('Mark resolved is disabled without a photo or without a '
        'note, enabled with both (AC-37)', (tester) async {
      await openAt(tester, AppRoutes.workResolve(inProgressJob));

      expect(find.text('After-repair photos'), findsOneWidget);
      expect(find.text('Before repair'), findsOneWidget);
      expect(noteField('Resolution note'), findsOneWidget);
      expect(find.textContaining('Visible to people involved'), findsOneWidget);
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.textContaining('Add after-repair photo'), findsOneWidget);
      expect(isEnabled(tester, 'Mark resolved'), isFalse);

      // A note alone is not enough ...
      await typeResolutionNote(tester, 'Replaced the fitting');
      expect(find.text('20/500'), findsOneWidget, reason: 'live counter');
      expect(isEnabled(tester, 'Mark resolved'), isFalse);

      // ... and neither is a photo alone.
      await typeResolutionNote(tester, '');
      await addAfterPhoto(tester);
      expect(find.text('1 of 5'), findsOneWidget);
      expect(isEnabled(tester, 'Mark resolved'), isFalse);

      // A blank (whitespace) note does not count.
      await typeResolutionNote(tester, '   ');
      expect(isEnabled(tester, 'Mark resolved'), isFalse);

      await typeResolutionNote(tester, 'Replaced the fitting');
      expect(isEnabled(tester, 'Mark resolved'), isTrue);
    });

    testWidgets('at most five photos', (tester) async {
      await openAt(tester, AppRoutes.workResolve(inProgressJob));
      for (int i = 0; i < ResolveLimits.maxPhotos; i++) {
        await addAfterPhoto(tester);
      }
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('Maximum 5 photos'), findsOneWidget);
      expect(find.text('Add photo'), findsNothing);
    });

    testWidgets('confirm, then the job is resolved with the note, the photos '
        'and one event; back on the work list (AC-39)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve(inProgressJob),
      );
      final Complaint before = await stored(container, inProgressJob);

      await addAfterPhoto(tester);
      await addAfterPhoto(tester);
      await typeResolutionNote(tester, '  Replaced the fitting.  ');
      await tapButton(tester, 'Mark resolved');

      // The confirmation names the complaint and what happens next.
      expect(find.text('Mark $inProgressJob as resolved?'), findsOneWidget);
      expect(find.text('A verifier will review.'), findsOneWidget);
      // Nothing is sent before the user confirms.
      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.inProgress,
      );

      await tester.tap(dialogButton('Mark resolved'));
      await tester.pumpAndSettle();

      final Complaint after = await stored(container, inProgressJob);
      expect(after.status, ComplaintStatus.resolved);
      expect(after.resolutionNote, 'Replaced the fitting.');
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.note, 'Replaced the fitting.');
      expect(after.timeline.last.actorRole, UserRole.maintenance);
      expect(after.afterPhotos.length, before.afterPhotos.length + 2);

      expect(pathOf(container), AppRoutes.work);
      expect(find.text('Assigned work'), findsOneWidget);
      expect(find.text('Sent for verification'), findsOneWidget);
      expect(find.text('In progress (0)'), findsOneWidget);
      expect(shownIds(tester), isNot(contains(inProgressJob)));
    });

    testWidgets('declining the confirmation sends nothing', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve(inProgressJob),
      );
      await addAfterPhoto(tester);
      await typeResolutionNote(tester, 'Done');
      await tapButton(tester, 'Mark resolved');
      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.inProgress,
      );
      expect(pathOf(container), AppRoutes.workResolve(inProgressJob));
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('a failed send keeps the photos and the note and offers '
        'Retry (G-4)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve(inProgressJob),
        repository: FlakyWriteComplaintRepository(initial: workSeed()),
      );
      await addAfterPhoto(tester);
      await addAfterPhoto(tester);
      await typeResolutionNote(tester, 'Replaced the fitting');
      await tapButton(tester, 'Mark resolved');
      await tester.tap(dialogButton('Mark resolved'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't mark as resolved"), findsOneWidget);
      expect(find.textContaining('photos and note were kept'), findsOneWidget);
      expect(find.text('2 of 5'), findsOneWidget);
      expect(
        tester.widget<TextField>(noteField('Resolution note')).controller!.text,
        'Replaced the fitting',
      );
      expect(pathOf(container), AppRoutes.workResolve(inProgressJob));
      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.inProgress,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.resolved,
      );
      expect(pathOf(container), AppRoutes.work);
    });

    testWidgets('while sending: progress, locked form, no double submit '
        '(G-3)', (tester) async {
      final SlowWriteComplaintRepository slow = SlowWriteComplaintRepository(
        initial: workSeed(),
      );
      await openAt(
        tester,
        AppRoutes.workResolve(inProgressJob),
        repository: slow,
      );
      await addAfterPhoto(tester);
      await typeResolutionNote(tester, 'Done');
      await tapButton(tester, 'Mark resolved');
      await tester.tap(dialogButton('Mark resolved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.widget<AppButton>(button('Mark resolved')).loading, isTrue);
      expect(isEnabled(tester, 'Cancel'), isFalse);
      expect(
        tester.widget<TextField>(noteField('Resolution note')).enabled,
        isFalse,
      );
      expect(slow.writes, 1);

      slow.release();
      await tester.pumpAndSettle();
      expect(slow.writes, 1);
    });

    testWidgets('Cancel asks to discard when something was entered '
        '(G-9)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(inProgressJob),
      );
      await tapButton(tester, 'Mark as resolved');
      expect(pathOf(container), AppRoutes.workResolve(inProgressJob));

      await addAfterPhoto(tester);
      await typeResolutionNote(tester, 'Half done');
      await tapButton(tester, 'Cancel');
      expect(find.text('Discard changes?'), findsOneWidget);

      // Keep editing: still here, nothing lost.
      await tester.tap(dialogButton('Keep editing'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.workResolve(inProgressJob));
      expect(find.text('1 of 5'), findsOneWidget);

      // Discard: back on the work detail, and a later visit starts empty.
      await tapButton(tester, 'Cancel');
      await tester.tap(dialogButton('Discard'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.workItem(inProgressJob));
      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.inProgress,
      );

      await tapButton(tester, 'Mark as resolved');
      expect(find.text('0 of 5'), findsOneWidget);
    });

    testWidgets('Cancel leaves straight away when nothing was entered', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workItem(inProgressJob),
      );
      await tapButton(tester, 'Mark as resolved');
      await tapButton(tester, 'Cancel');

      expect(find.text('Discard changes?'), findsNothing);
      expect(pathOf(container), AppRoutes.workItem(inProgressJob));
    });

    testWidgets('after a reject the job can be resolved again with new '
        'photos (AC-38)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve(reworkJob),
      );
      expect(find.text('Rework needed'), findsOneWidget);

      await addAfterPhoto(tester);
      await typeResolutionNote(tester, 'Re-wired the junction box');
      await tapButton(tester, 'Mark resolved');
      await tester.tap(dialogButton('Mark resolved'));
      await tester.pumpAndSettle();

      expect(
        (await stored(container, reworkJob)).status,
        ComplaintStatus.resolved,
      );
      expect(pathOf(container), AppRoutes.work);
    });

    testWidgets('a job that is not in progress, or a colleague\'s, cannot '
        'be resolved here', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve(toStartA),
      );
      expect(find.text("This job isn't in progress"), findsOneWidget);
      expect(find.text('Back to my work'), findsOneWidget);
      expect(button('Mark resolved'), findsNothing);

      await openRoute(
        tester,
        container,
        AppRoutes.workResolve(colleagueInProgress),
      );
      expect(find.text('Already claimed by a colleague'), findsOneWidget);
      expect(button('Mark resolved'), findsNothing);

      await tapButton(tester, 'Back to my work');
      expect(pathOf(container), AppRoutes.work);
    });

    testWidgets('an unknown job and another department\'s job show E-404', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.workResolve('CF-2026-99999'),
      );
      expect(find.text("We couldn't find that complaint"), findsOneWidget);

      await openRoute(tester, container, AppRoutes.workResolve(plumberJob));
      expect(find.text("We couldn't find that complaint"), findsOneWidget);
    });

    testWidgets('shows no identity', (tester) async {
      await openAt(tester, AppRoutes.workResolve(reworkJob));
      await addAfterPhoto(tester);
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  });

  group('access', () {
    testWidgets('the work screens are closed to other roles (E-403)', (
      tester,
    ) async {
      final ProviderContainer container = await pumpCampusFix(tester);
      await signInAs(tester, UserRole.reporter);
      for (final String path in <String>[
        AppRoutes.work,
        AppRoutes.workItem(toStartA),
        AppRoutes.workResolve(inProgressJob),
      ]) {
        await openRoute(tester, container, path);
        expect(find.text("You don't have access to this page"), findsOneWidget);
      }
    });
  });
}
