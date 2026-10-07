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

Iterable<Complaint> ownSeedComplaints() {
  final String me = demoAccount(UserRole.reporter).user.id;
  return testSeed.complaints.where((c) => c.reporter.userId == me);
}

Complaint ownWhere(bool Function(Complaint c) test) =>
    ownSeedComplaints().firstWhere(test);

Future<ProviderContainer> signedInAsReporter(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: overrides,
  );
  await signInAs(tester, UserRole.reporter);
  useTallView(tester);
  return container;
}

/// A hand-built public view, for states the seed does not offer.
PublicComplaintView viewWith({
  required ComplaintStatus status,
  List<PublicStatusEvent> timeline = const <PublicStatusEvent>[],
  List<Attachment> afterPhotos = const <Attachment>[],
  String? resolutionNote,
  Department? department,
}) {
  final DateTime t = DateTime(2026, 10, 1, 9);
  return PublicComplaintView(
    id: 'CF-2026-07777',
    category: ProblemCategory.electrical,
    building: 'Academic Block A',
    floor: '2',
    room: 'Lab 204',
    description: 'The ceiling light flickers.',
    beforePhotos: <Attachment>[
      Attachment(
        id: 'a1',
        kind: AttachmentKind.beforePhoto,
        ref: 'before-1',
        createdAt: t,
      ),
    ],
    afterPhotos: afterPhotos,
    effectivePriority: Priority.high,
    status: status,
    assignedDepartment: department,
    resolutionNote: resolutionNote,
    timeline: timeline,
    createdAt: t,
    updatedAt: t.add(const Duration(hours: 5)),
  );
}

Future<void> pumpView(WidgetTester tester, PublicComplaintView view) async {
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ComplaintDetailsView(complaint: view)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the full tracking page of a closed complaint '
      '(M-10, AC-25, AC-26, AC-27)', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    final Complaint c = ownWhere((c) => c.status == ComplaintStatus.closed);
    await openRoute(tester, container, AppRoutes.complaint(c.id));

    // Header.
    expect(find.text('Complaint details'), findsOneWidget);
    expect(find.text(c.id), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byType(PriorityTag), findsOneWidget);
    expect(find.text(c.category.label), findsOneWidget);
    expect(find.text('This complaint is closed.'), findsOneWidget);
    // Progress tracker: closed is step 7 of 7.
    expect(find.byType(StatusStepper), findsOneWidget);
    expect(find.text('Step 7 of 7'), findsOneWidget);
    // Location and description.
    expect(find.text('${c.building} · ${c.floor} · ${c.room}'), findsOneWidget);
    expect(find.text(c.description), findsOneWidget);

    // Before and after evidence appear because after photos exist.
    expect(c.afterPhotos, isNotEmpty);
    expect(find.byType(BeforeAfter), findsOneWidget);
    expect(find.text('After repair'), findsOneWidget);
    // Resolution note and assigned department.
    expect(find.text('Resolution note'), findsOneWidget);
    // Shown in its own card and again as the note of the resolved event.
    expect(find.text(c.resolutionNote!), findsNWidgets(2));
    expect(find.text('Assigned department'), findsOneWidget);
    expect(find.text(c.assignment!.department.label), findsOneWidget);

    // No status actions for a reporter (AC-27).
    for (final String action in <String>[
      'Start work',
      'Resolve',
      'Mark resolved',
      'Verify',
      'Verify & Close',
      'Reject',
      'Close',
      'Assign',
    ]) {
      expect(find.widgetWithText(AppButton, action), findsNothing);
    }
  });

  testWidgets('the timeline shows status, role, time and note in order and '
      'never who (AC-25)', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    final Complaint c = ownWhere((c) => c.status == ComplaintStatus.closed);
    await openRoute(tester, container, AppRoutes.complaint(c.id));

    final Finder timeline = find.byType(ComplaintTimeline);
    expect(timeline, findsOneWidget);
    final List<StatusEvent> events = <StatusEvent>[...c.timeline]
      ..sort((a, b) => a.at.compareTo(b.at));
    expect(
      find.descendant(of: timeline, matching: find.byType(TimelineItem)),
      findsNWidgets(events.length),
    );

    // One item per event, in chronological order, each with its role label.
    final List<TimelineItem> items = tester
        .widgetList<TimelineItem>(find.byType(TimelineItem))
        .toList();
    for (int i = 0; i < events.length; i++) {
      expect(items[i].status, events[i].status);
      expect(items[i].actorRole, events[i].actorRole);
      expect(items[i].note, events[i].note);
      expect(
        find.descendant(
          of: find.byWidget(items[i]),
          matching: find.byType(RolePill),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(items[i]),
          matching: find.text(events[i].actorRole.label),
        ),
        findsOneWidget,
      );
    }
    // Notes are shown as written.
    final List<String> notes = <String>[
      for (final StatusEvent e in events)
        if (e.note != null && e.note!.isNotEmpty) e.note!,
    ];
    expect(notes, isNotEmpty);
    for (final String note in notes) {
      expect(
        find.descendant(of: timeline, matching: find.text(note)),
        findsWidgets,
        reason: note,
      );
    }

    // No identity anywhere on the page, including semantics labels.
    expect(identityLeaks(allRenderedText(tester)), isEmpty);
  });

  testWidgets('after photos and the resolution note only appear once they '
      'exist (AC-26)', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    final Complaint c = ownWhere((c) => c.status == ComplaintStatus.reported);
    expect(c.afterPhotos, isEmpty);
    await openRoute(tester, container, AppRoutes.complaint(c.id));

    expect(find.text(c.id), findsOneWidget);
    expect(find.byType(BeforeAfter), findsNothing);
    expect(find.text('After repair'), findsNothing);
    expect(find.text('Resolution note'), findsNothing);
    expect(find.text('Assigned department'), findsNothing);
    expect(find.text('This complaint is closed.'), findsNothing);
    expect(find.text('Step 1 of 7'), findsOneWidget);
    // The creation event reads "Reporter" and nothing more about who.
    expect(find.byType(TimelineItem), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TimelineItem),
        matching: find.text('Reporter'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no seeded identity leaks on any of the reporter\'s own '
      'complaints', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    for (final Complaint c in ownSeedComplaints()) {
      await openRoute(tester, container, AppRoutes.complaint(c.id));
      expect(find.text(c.id), findsOneWidget, reason: c.id);
      expect(identityLeaks(allRenderedText(tester)), isEmpty, reason: c.id);
    }
  });

  testWidgets('a photo opens full screen and closes again', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    final Complaint c = ownWhere((c) => c.status == ComplaintStatus.reported);
    await openRoute(tester, container, AppRoutes.complaint(c.id));

    await tester.tap(find.byType(PhotoThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Complaint details'), findsOneWidget);
  });

  testWidgets('someone else\'s complaint is forwarded to its board item, '
      'an unknown ID is E-404', (tester) async {
    final ProviderContainer container = await signedInAsReporter(tester);
    final String me = demoAccount(UserRole.reporter).user.id;
    final Complaint other = testSeed.complaints.firstWhere(
      (c) => c.reporter.userId != me,
    );

    await openRoute(tester, container, AppRoutes.complaint(other.id));
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.boardItem(other.id),
    );
    expect(find.text('Board item'), findsOneWidget);
    expect(find.text(other.id), findsOneWidget);
    expect(find.text('Timeline'), findsNothing);

    await openRoute(tester, container, AppRoutes.complaint('CF-2026-99999'));
    expect(find.text("We couldn't find that complaint"), findsOneWidget);
    expect(find.byType(ComplaintTimeline), findsNothing);
  });

  testWidgets('a failed load shows an error with Retry', (tester) async {
    final ProviderContainer container = await signedInAsReporter(
      tester,
      overrides: <Override>[
        complaintRepositoryProvider.overrideWithValue(
          FlakyComplaintRepository(initial: testSeed.complaints),
        ),
      ],
    );
    final Complaint c = ownWhere((c) => true);
    await openRoute(tester, container, AppRoutes.complaint(c.id));

    expect(find.text("Couldn't load this complaint"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(c.id), findsOneWidget);
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
    await signInAs(tester, UserRole.reporter);
    container
        .read(appRouterProvider)
        .go(AppRoutes.complaint(testSeed.complaints.first.id));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(find.byType(ComplaintTimeline), findsNothing);
  });

  group('ComplaintDetailsView', () {
    final DateTime t = DateTime(2026, 10, 1, 9);
    PublicStatusEvent ev(
      ComplaintStatus s,
      UserRole r,
      int hours, [
      String? n,
    ]) => PublicStatusEvent(
      status: s,
      actorRole: r,
      at: t.add(Duration(hours: hours)),
      note: n,
    );

    testWidgets('marks a reworked complaint and keeps the notes', (
      tester,
    ) async {
      await pumpView(
        tester,
        viewWith(
          status: ComplaintStatus.inProgress,
          department: Department.electrician,
          timeline: <PublicStatusEvent>[
            ev(ComplaintStatus.reported, UserRole.reporter, 0),
            ev(ComplaintStatus.assigned, UserRole.verifier, 1, 'Auto-routed.'),
            ev(ComplaintStatus.inProgress, UserRole.maintenance, 2),
            ev(ComplaintStatus.resolved, UserRole.maintenance, 3, 'Replaced.'),
            ev(ComplaintStatus.inProgress, UserRole.verifier, 4, 'Still dim.'),
          ],
        ),
      );

      // Once in the tracker and once on the timeline entry itself.
      expect(find.text('Rework'), findsNWidgets(2));
      expect(find.text('Still dim.'), findsOneWidget);
      expect(find.text('Auto-routed.'), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      // Rework is not "resolved or later": the old note is not shown.
      expect(find.text('Resolution note'), findsNothing);
    });

    testWidgets('a resolved complaint shows the after photo comparison and '
        'the resolution note', (tester) async {
      await pumpView(
        tester,
        viewWith(
          status: ComplaintStatus.resolved,
          resolutionNote: 'Fitting replaced.',
          afterPhotos: <Attachment>[
            Attachment(
              id: 'a2',
              kind: AttachmentKind.afterPhoto,
              ref: 'after-1',
              createdAt: t,
            ),
          ],
          timeline: <PublicStatusEvent>[
            ev(ComplaintStatus.reported, UserRole.reporter, 0),
            ev(ComplaintStatus.resolved, UserRole.maintenance, 3),
          ],
        ),
      );

      expect(find.byType(BeforeAfter), findsOneWidget);
      expect(find.text('Resolution note'), findsOneWidget);
      expect(find.text('Fitting replaced.'), findsOneWidget);
      expect(find.text('Step 5 of 7'), findsOneWidget);
    });
  });
}
