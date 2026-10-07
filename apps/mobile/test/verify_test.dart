import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/features/complaint_details/complaint_details_view.dart';
import 'package:campusfix_mobile/features/verify/verify_widgets.dart';
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
import 'support/verify_fixtures.dart';

/// Opens the verification queue from the verifier's Home.
Future<ProviderContainer> openQueue(
  WidgetTester tester, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await signedInAsVerifier(
    tester,
    repository: repository,
  );
  await tester.tap(find.text('Open verification queue'));
  await tester.pumpAndSettle();
  return container;
}

/// Buttons that would close a complaint: there are none on mobile (T6 is an
/// admin-only action on the web console).
final Finder closeButtons = find.byWidgetPredicate(
  (Widget w) => w is AppButton && w.label.toLowerCase().contains('close'),
  description: 'a Close button',
);

void main() {
  group('M-16 Verification Queue', () {
    testWidgets('lists exactly the resolved complaints, most urgent then '
        'longest waiting first, and the count equals Home (AC-40, AC-41)', (
      tester,
    ) async {
      final ProviderContainer container = await signedInAsVerifier(tester);

      // Home first: "Awaiting verification" with the count.
      final MetricCard home = tester.widget<MetricCard>(
        find.byType(MetricCard),
      );
      expect(home.label, 'Awaiting verification');
      expect(home.value, '${resolvedIds.length}');

      await tester.tap(find.text('Open verification queue'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.verify);
      expect(find.text('Verification queue'), findsOneWidget);

      final List<String> ids = shownIds(tester);
      expect(ids, queueOrder(testSeed.complaints));
      expect(ids.toSet(), resolvedIds.toSet(), reason: 'only resolved');
      expect(ids, hasLength(int.parse(home.value)), reason: 'AC-41');
      expect(find.text('${ids.length} awaiting verification'), findsOneWidget);
      // The queue's first card is the critical one.
      expect(ids.first, criticalElectrical);
      expect(ids.last, lowFurniture);

      // Each id really is `resolved` in the store, and nothing else is shown.
      for (final String id in ids) {
        expect((await stored(container, id)).status, ComplaintStatus.resolved);
      }
      for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
        find.byType(ComplaintCard),
      )) {
        expect(c.variant, ComplaintCardVariant.verify);
        expect(c.complaint.status, ComplaintStatus.resolved);
      }
      expect(find.byType(PriorityTag), findsNWidgets(ids.length));
      expect(find.textContaining('Resolved '), findsWidgets);
    });

    testWidgets('tapping a card opens the verify detail (M-17), back lands on '
        'the queue', (tester) async {
      final ProviderContainer container = await openQueue(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ComplaintCard && w.complaint.id == highIt,
        ),
      );
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.verifyItem(highIt));
      expect(find.text('Verify repair'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(pathOf(container), AppRoutes.verify);
      expect(find.text('Verification queue'), findsOneWidget);
    });

    testWidgets('nothing resolved: "Nothing awaiting verification"', (
      tester,
    ) async {
      await openQueue(tester, repository: MockComplaintRepository());

      expect(find.text('Nothing awaiting verification'), findsOneWidget);
      expect(find.byType(ComplaintCard), findsNothing);
    });

    testWidgets('only non-resolved complaints: the queue is empty, not '
        'misleading', (tester) async {
      await openQueue(
        tester,
        repository: MockComplaintRepository(
          initial: <Complaint>[
            for (final Complaint c in testSeed.complaints)
              if (c.status != ComplaintStatus.resolved) c,
          ],
        ),
      );
      expect(find.text('Nothing awaiting verification'), findsOneWidget);
    });

    testWidgets('a failed load shows an error with Retry', (tester) async {
      await openQueue(
        tester,
        repository: FlakyComplaintRepository(initial: testSeed.complaints),
      );

      expect(find.text("Couldn't load the verification queue"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load the verification queue"), findsNothing);
      expect(shownIds(tester), hasLength(resolvedIds.length));
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
      await signInAs(tester, UserRole.verifier);
      container.read(appRouterProvider).go(AppRoutes.verify);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ComplaintCardSkeleton), findsWidgets);
      expect(find.byType(ComplaintCard), findsNothing);
    });

    testWidgets('pull-to-refresh re-reads the queue', (tester) async {
      final ProviderContainer container = await openQueue(tester);
      expect(shownIds(tester), hasLength(resolvedIds.length));

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(pathOf(container), AppRoutes.verify);
      expect(shownIds(tester), hasLength(resolvedIds.length));
    });

    testWidgets('a newly resolved complaint appears without a refresh, and a '
        'verified one leaves', (tester) async {
      final ProviderContainer container = await openQueue(tester);
      expect(shownIds(tester), hasLength(resolvedIds.length));

      final Complaint another = (await stored(
        container,
        highIt,
      )).copyWith(id: 'CF-2026-09001');
      await container.read(complaintRepositoryProvider).submit(another);
      await tester.pumpAndSettle();
      expect(shownIds(tester), contains('CF-2026-09001'));
      expect(shownIds(tester), hasLength(resolvedIds.length + 1));

      final Complaint gone = (await stored(
        container,
        lowFurniture,
      )).copyWith(status: ComplaintStatus.verified);
      await container.read(complaintRepositoryProvider).update(gone);
      await tester.pumpAndSettle();
      expect(shownIds(tester), isNot(contains(lowFurniture)));
    });

    testWidgets('shows no identity', (tester) async {
      await openQueue(tester);
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  });

  group('M-17 Verify detail', () {
    testWidgets('a resolved job shows the evidence and offers Verify and '
        'Reject, and no Close', (tester) async {
      await openAt(tester, AppRoutes.verifyItem(criticalElectrical));

      final Complaint c = testSeed.complaints.firstWhere(
        (c) => c.id == criticalElectrical,
      );
      expect(find.byType(ComplaintDetailsView), findsOneWidget);
      expect(find.text('Verify repair'), findsOneWidget);
      expect(find.text(criticalElectrical), findsWidgets);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.resolved,
      );
      expect(find.byType(PriorityTag), findsOneWidget);
      // The point of the screen: before vs after, and the resolution note.
      expect(find.byType(BeforeAfter), findsOneWidget);
      expect(find.text('Resolution note'), findsOneWidget);
      expect(find.text(c.resolutionNote!), findsWidgets);
      expect(find.text('Timeline'), findsOneWidget);

      expect(button('Verify'), findsOneWidget);
      expect(button('Reject'), findsOneWidget);
      expect(closeButtons, findsNothing, reason: 'closing is admin-only');
      expect(find.textContaining('Verify & close'), findsNothing);
      expect(isEnabled(tester, 'Verify'), isTrue);
      expect(find.text('Note'), findsOneWidget);
      expect(find.textContaining('Visible to people involved'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);
    });

    testWidgets('Reject needs a reason: disabled without one (a blank one '
        'does not count), enabled with one (AC-43)', (tester) async {
      await openAt(tester, AppRoutes.verifyItem(criticalElectrical));

      expect(isEnabled(tester, 'Reject'), isFalse);
      expect(isEnabled(tester, 'Verify'), isTrue, reason: 'note is optional');

      await typeNote(tester, '   ');
      expect(isEnabled(tester, 'Reject'), isFalse);

      await typeNote(tester, 'Still sparking');
      expect(find.text('14/500'), findsOneWidget, reason: 'live counter');
      expect(isEnabled(tester, 'Reject'), isTrue);

      await typeNote(tester, '');
      expect(isEnabled(tester, 'Reject'), isFalse);
    });

    testWidgets('Verify: confirm, then the job is `verified` (not closed) '
        'with one verifier event; back on the queue without it', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(criticalElectrical),
      );
      final Complaint before = await stored(container, criticalElectrical);

      await typeNote(tester, '  Checked on site.  ');
      await tapButton(tester, 'Verify');

      // The confirmation names the complaint; nothing is sent before it.
      expect(
        find.text('Mark $criticalElectrical as verified?'),
        findsOneWidget,
      );
      expect(
        (await stored(container, criticalElectrical)).status,
        ComplaintStatus.resolved,
      );

      await tester.tap(dialogButton('Verify'));
      await tester.pumpAndSettle();

      final Complaint after = await stored(container, criticalElectrical);
      expect(after.status, ComplaintStatus.verified);
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.status, ComplaintStatus.verified);
      expect(after.timeline.last.actorRole, UserRole.verifier);
      expect(after.timeline.last.note, 'Checked on site.');

      expect(pathOf(container), AppRoutes.verify);
      expect(find.text('Verification queue'), findsOneWidget);
      expect(find.text('Repair verified'), findsOneWidget); // toast
      expect(shownIds(tester), isNot(contains(criticalElectrical)));
      expect(shownIds(tester), hasLength(resolvedIds.length - 1));
      expect(
        find.text("We couldn't find that complaint"),
        findsNothing,
        reason: 'no E-404 flash on the way out',
      );
    });

    testWidgets('Verify without a note is allowed', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(highIt),
      );
      await tapButton(tester, 'Verify');
      await tester.tap(dialogButton('Verify'));
      await tester.pumpAndSettle();

      final Complaint after = await stored(container, highIt);
      expect(after.status, ComplaintStatus.verified);
      expect(after.timeline.last.note, isNull);
    });

    testWidgets('Reject: confirm, then the job goes back to `inProgress` with '
        'the reason and one verifier event (AC-44)', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(criticalElectrical),
      );
      final Complaint before = await stored(container, criticalElectrical);

      await typeNote(tester, '  Still sparking.  ');
      await tapButton(tester, 'Reject');

      expect(find.text('Reject $criticalElectrical?'), findsOneWidget);
      expect(
        (await stored(container, criticalElectrical)).status,
        ComplaintStatus.resolved,
        reason: 'nothing is sent before the user confirms',
      );

      await tester.tap(dialogButton('Reject'));
      await tester.pumpAndSettle();

      final Complaint after = await stored(container, criticalElectrical);
      expect(after.status, ComplaintStatus.inProgress);
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.status, ComplaintStatus.inProgress);
      expect(after.timeline.last.actorRole, UserRole.verifier);
      expect(after.timeline.last.note, 'Still sparking.');

      expect(pathOf(container), AppRoutes.verify);
      expect(find.text('Sent back for rework'), findsOneWidget); // toast
      expect(shownIds(tester), isNot(contains(criticalElectrical)));
    });

    testWidgets('declining a confirmation sends nothing and keeps the note', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(criticalElectrical),
      );
      await typeNote(tester, 'Needs another look');

      await tapButton(tester, 'Reject');
      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Verify');
      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (await stored(container, criticalElectrical)).status,
        ComplaintStatus.resolved,
      );
      expect(pathOf(container), AppRoutes.verifyItem(criticalElectrical));
      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'Needs another look',
      );
    });

    testWidgets('a failed verify keeps the note and offers Retry (G-4)', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(highIt),
        repository: FlakyWriteComplaintRepository(initial: testSeed.complaints),
      );
      await typeNote(tester, 'Looks fine');
      await tapButton(tester, 'Verify');
      await tester.tap(dialogButton('Verify'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't verify the repair"), findsOneWidget);
      expect(
        find.textContaining('Nothing you entered was lost'),
        findsOneWidget,
      );
      expect(pathOf(container), AppRoutes.verifyItem(highIt));
      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'Looks fine',
      );
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.resolved,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.verified,
      );
      expect(
        (await stored(container, highIt)).timeline.last.note,
        'Looks fine',
      );
      expect(pathOf(container), AppRoutes.verify);
    });

    testWidgets('a failed reject keeps the reason and offers Retry (G-4)', (
      tester,
    ) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(highIt),
        repository: FlakyWriteComplaintRepository(initial: testSeed.complaints),
      );
      await typeNote(tester, 'Leak is back');
      await tapButton(tester, 'Reject');
      await tester.tap(dialogButton('Reject'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't send the job back"), findsOneWidget);
      expect(find.textContaining('Your reason was kept'), findsOneWidget);
      expect(
        tester.widget<TextField>(noteField).controller!.text,
        'Leak is back',
      );
      expect(isEnabled(tester, 'Reject'), isTrue);
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.resolved,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      final Complaint after = await stored(container, highIt);
      expect(after.status, ComplaintStatus.inProgress);
      expect(after.timeline.last.note, 'Leak is back');
      expect(pathOf(container), AppRoutes.verify);
    });

    testWidgets('while sending: progress, locked form, no double submit '
        '(G-3)', (tester) async {
      final SlowWriteComplaintRepository slow = SlowWriteComplaintRepository(
        initial: testSeed.complaints,
      );
      await openAt(tester, AppRoutes.verifyItem(highIt), repository: slow);

      await tapButton(tester, 'Verify');
      await tester.tap(dialogButton('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.widget<AppButton>(button('Verify')).loading, isTrue);
      expect(isEnabled(tester, 'Verify'), isFalse);
      expect(isEnabled(tester, 'Reject'), isFalse);
      expect(tester.widget<TextField>(noteField).enabled, isFalse);
      expect(slow.writes, 1);

      await tester.tap(button('Verify'), warnIfMissed: false);
      await tester.tap(button('Reject'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(AppDialog), findsNothing);
      expect(slow.writes, 1);

      slow.release();
      await tester.pumpAndSettle();
      expect(slow.writes, 1);
      expect(find.text('Verification queue'), findsOneWidget);
    });

    testWidgets('missing repair evidence: Verify is disabled with the P1 / P2 '
        'message, Reject still works', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem(lowFurniture),
        repository: MockComplaintRepository(initial: noEvidenceSeed()),
      );

      expect(find.text("Can't verify this repair"), findsOneWidget);
      expect(
        find.textContaining('Add at least one after-repair photo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Add a resolution note.'), findsOneWidget);
      expect(isEnabled(tester, 'Verify'), isFalse);

      await typeNote(tester, 'No proof of repair');
      expect(isEnabled(tester, 'Reject'), isTrue);
      await tapButton(tester, 'Reject');
      await tester.tap(dialogButton('Reject'));
      await tester.pumpAndSettle();
      expect(
        (await stored(container, lowFurniture)).status,
        ComplaintStatus.inProgress,
      );
    });

    testWidgets('an unknown id and a complaint that is not awaiting '
        'verification show E-404, with no actions', (tester) async {
      final ProviderContainer container = await openAt(
        tester,
        AppRoutes.verifyItem('CF-2026-99999'),
      );
      expect(find.text("We couldn't find that complaint"), findsOneWidget);
      final String unknown = allRenderedText(tester);

      for (final String id in <String>[verifiedJob, closedJob, inProgressJob]) {
        await openRoute(tester, container, AppRoutes.verifyItem(id));
        expect(find.text("We couldn't find that complaint"), findsOneWidget);
        expect(button('Verify'), findsNothing, reason: id);
        expect(button('Reject'), findsNothing, reason: id);
        expect(closeButtons, findsNothing, reason: id);
        expect(allRenderedText(tester), unknown, reason: id);
      }
    });

    testWidgets('a failed load shows an error with Retry', (tester) async {
      await openAt(
        tester,
        AppRoutes.verifyItem(highIt),
        repository: FlakyComplaintRepository(initial: testSeed.complaints),
      );
      expect(find.text("Couldn't load this complaint"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(button('Verify'), findsOneWidget);
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
      await signInAs(tester, UserRole.verifier);
      container.read(appRouterProvider).go(AppRoutes.verifyItem(highIt));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ComplaintDetailsSkeleton), findsOneWidget);
      expect(button('Verify'), findsNothing);
    });

    testWidgets('shows no identity, with or without a note typed', (
      tester,
    ) async {
      await openAt(tester, AppRoutes.verifyItem(criticalElectrical));
      expect(identityLeaks(allRenderedText(tester)), isEmpty);

      await typeNote(tester, 'Checked on site');
      await tapButton(tester, 'Reject');
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  });

  group('verify failure banner', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      VerifyActionState state, {
      VoidCallback? onRetry,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VerifyFailureBanner(
            state: state,
            title: "Couldn't send the job back",
            onRetry: onRetry,
          ),
        ),
      ),
    );

    testWidgets('a rule block shows its messages and no Retry', (tester) async {
      await pumpBanner(
        tester,
        const VerifyActionState(
          status: VerifyActionStatus.failed,
          complaintId: highIt,
          kind: VerifyActionKind.reject,
          blocked: true,
          messages: <String>['Add a reason.'],
        ),
        onRetry: () {},
      );
      expect(find.text("Couldn't send the job back"), findsOneWidget);
      expect(find.text('Add a reason.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed write shows Retry', (tester) async {
      int retried = 0;
      await pumpBanner(
        tester,
        const VerifyActionState(
          status: VerifyActionStatus.failed,
          complaintId: highIt,
          kind: VerifyActionKind.reject,
          messages: <String>['Try again.'],
        ),
        onRetry: () => retried++,
      );
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });
  });
}
