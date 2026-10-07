import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:campusfix_mobile/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// The primary bottom-bar button labelled [label].
Finder button(String label) => find.widgetWithText(AppButton, label);

bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(button(label)).onPressed != null;

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(button(label));
  await tester.pumpAndSettle();
}

/// Opens a select (by its hint / current text) and picks [option].
Future<void> pick(WidgetTester tester, String hint, String option) async {
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

/// Scrolls the step's list until [target] is built and on screen.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> addPhoto(WidgetTester tester, {bool first = false}) async {
  await tester.tap(find.text(first ? 'Add a photo' : 'Add photo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Take a photo (sample)'));
  await tester.pumpAndSettle();
}

Finder stepLabel(int step, String name) => find.text('Step $step of 5 · $name');

/// Signs in as the demo reporter and opens the report flow from Home.
Future<ProviderContainer> startReport(WidgetTester tester) async {
  final ProviderContainer container = await pumpCampusFix(tester);
  await signInAs(tester, UserRole.reporter);
  await tester.tap(find.text('Report a Problem'));
  await tester.pumpAndSettle();
  return container;
}

/// Step 1 to 3 with [category] and the Academic Block A / 2 / Lab location.
Future<void> completeCategoryLocationPhotos(
  WidgetTester tester, {
  String category = 'Electrical',
  int photos = 1,
}) async {
  await tester.tap(find.text(category));
  await tester.pumpAndSettle();
  await tapButton(tester, 'Next');

  expect(stepLabel(2, 'Location'), findsOneWidget);
  await pick(tester, 'Select a building', 'Academic Block A');
  await pick(tester, 'Select a floor', '2');
  await tester.enterText(find.byType(TextField), 'Electronics Lab 204');
  await tester.pumpAndSettle();
  await tapButton(tester, 'Next');

  expect(stepLabel(3, 'Photos'), findsOneWidget);
  for (int i = 0; i < photos; i++) {
    await addPhoto(tester, first: i == 0);
  }
  await tapButton(tester, 'Next');
}

void main() {
  testWidgets('happy path: category to confirmation with an ID and priority '
      '(AC-21, AC-22)', (tester) async {
    final ProviderContainer container = await startReport(tester);

    // M-03: Next is disabled until a category is chosen (AC-07); all eight
    // labels are shown (AC-08).
    expect(stepLabel(1, 'Category'), findsOneWidget);
    expect(isEnabled(tester, 'Next'), isFalse);
    for (final ProblemCategory c in ProblemCategory.values) {
      expect(find.text(c.label), findsOneWidget, reason: c.name);
    }
    await completeCategoryLocationPhotos(tester);

    // M-06: description required; defaults moderate / individual / off.
    expect(stepLabel(4, 'Details'), findsOneWidget);
    expect(isEnabled(tester, 'Next'), isFalse);
    await tester.enterText(
      find.byType(TextField).first,
      'The ceiling light flickers and buzzes all day.',
    );
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Next'), isTrue);
    await tapButton(tester, 'Next');

    // M-07: read-only summary, privacy notice, Submit.
    expect(stepLabel(5, 'Review'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
    expect(
      find.text('Academic Block A · 2 · Electronics Lab 204'),
      findsOneWidget,
    );
    expect(find.text('Photos (1)'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Just me'), findsOneWidget);
    await scrollTo(tester, find.textContaining('never shown on the board'));
    expect(find.textContaining('never shown on the board'), findsOneWidget);

    await tapButton(tester, 'Submit');

    // M-08: the generated Complaint ID and the computed priority.
    expect(find.text('Report submitted'), findsOneWidget);
    final Finder idText = find.byType(ComplaintIdText);
    expect(idText, findsOneWidget);
    final String id = tester.widget<ComplaintIdText>(idText).id;
    expect(id, matches(RegExp(r'^CF-\d{4}-\d{5}$')));
    expect(
      tester.widget<PriorityTag>(find.byType(PriorityTag)).priority,
      computePriority(
        const PriorityInputs(
          category: ProblemCategory.electrical,
          safetyFlag: false,
          severity: Severity.moderate,
          peopleAffected: PeopleAffected.individual,
        ),
      ),
    );
    expect(find.text('What happens next'), findsOneWidget);
    expect(find.textContaining("You'll be notified"), findsOneWidget);
    expect(container.read(reportDraftProvider).hasInput, isFalse);

    // Back from the confirmation goes Home, not back into the flow (G-9).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(appRouterProvider).state.uri.path, AppRoutes.home);
  });

  testWidgets('the submitted complaint appears in My Complaints (AC-18)', (
    tester,
  ) async {
    final ProviderContainer container = await startReport(tester);
    await completeCategoryLocationPhotos(
      tester,
      category: 'Plumbing / Water / Washroom',
    );
    await tester.enterText(
      find.byType(TextField).first,
      'The tap in the washroom leaks constantly.',
    );
    await tester.pumpAndSettle();
    await tapButton(tester, 'Next');
    await tapButton(tester, 'Submit');

    final String id = tester
        .widget<ComplaintIdText>(find.byType(ComplaintIdText))
        .id;
    final List<PublicComplaintView> mine = container
        .read(myComplaintsProvider)
        .requireValue;
    final PublicComplaintView filed = mine.singleWhere((c) => c.id == id);
    expect(filed.category, ProblemCategory.plumbing);
    expect(filed.status, ComplaintStatus.reported);

    // Also visible on the campus board, without any identity.
    expect(
      container
          .read(boardComplaintsProvider)
          .requireValue
          .any((c) => c.id == id),
      isTrue,
    );

    // "View complaint" opens it under My Complaints.
    await tapButton(tester, 'View complaint');
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.complaint(id),
    );
  });

  testWidgets('photos: 1 to 5 required, the sixth cannot be added '
      '(AC-12, AC-13)', (tester) async {
    await startReport(tester);
    await tester.tap(find.text('Electrical'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Next');
    await pick(tester, 'Select a building', 'Academic Block A');
    await pick(tester, 'Select a floor', '2');
    await tester.enterText(find.byType(TextField), 'Lab 204');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Next');

    expect(stepLabel(3, 'Photos'), findsOneWidget);
    expect(isEnabled(tester, 'Next'), isFalse);
    expect(find.text('Add at least 1 photo to continue.'), findsOneWidget);

    await addPhoto(tester, first: true);
    expect(isEnabled(tester, 'Next'), isTrue);
    for (int i = 1; i < 5; i++) {
      await addPhoto(tester);
    }
    expect(find.text('5 of 5'), findsOneWidget);
    expect(find.text('Maximum 5 photos'), findsOneWidget);
    expect(find.text('Add photo'), findsNothing);
    expect(find.byType(ComplaintPhoto), findsNWidgets(5));
    expect(isEnabled(tester, 'Next'), isTrue);
  });

  testWidgets('description is required and needs 10 characters (AC-15)', (
    tester,
  ) async {
    await startReport(tester);
    await completeCategoryLocationPhotos(tester);

    expect(isEnabled(tester, 'Next'), isFalse);
    await tester.enterText(find.byType(TextField).first, 'too short');
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Next'), isFalse);
    await tester.enterText(find.byType(TextField).first, '  ten chars!  ');
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Next'), isTrue);
  });

  testWidgets('the safety category forces the flag on and locks it (AC-17)', (
    tester,
  ) async {
    final ProviderContainer container = await startReport(tester);
    await completeCategoryLocationPhotos(tester, category: 'Safety');

    expect(container.read(reportDraftProvider).safetyFlag, isTrue);
    final Finder toggle = find.byType(AppSwitch);
    await scrollTo(tester, toggle);
    expect(tester.widget<AppSwitch>(toggle).value, isTrue);
    expect(tester.widget<AppSwitch>(toggle).onChanged, isNull);
    expect(find.textContaining('Always on for the Safety'), findsOneWidget);

    await tester.tap(toggle, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(container.read(reportDraftProvider).safetyFlag, isTrue);
  });

  testWidgets('another category leaves the flag to the reporter', (
    tester,
  ) async {
    final ProviderContainer container = await startReport(tester);
    await completeCategoryLocationPhotos(tester);

    final Finder toggle = find.byType(AppSwitch);
    await scrollTo(tester, toggle);
    expect(tester.widget<AppSwitch>(toggle).value, isFalse);
    expect(tester.widget<AppSwitch>(toggle).onChanged, isNotNull);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(reportDraftProvider).safetyFlag, isTrue);
    expect(find.textContaining('minimum priority High'), findsOneWidget);
  });

  testWidgets('Edit from Review keeps the draft and returns (AC-20)', (
    tester,
  ) async {
    final ProviderContainer container = await startReport(tester);
    await completeCategoryLocationPhotos(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'The ceiling light flickers and buzzes.',
    );
    await tester.pumpAndSettle();
    await tapButton(tester, 'Next');
    expect(stepLabel(5, 'Review'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Edit Category'));
    await tester.pumpAndSettle();
    expect(stepLabel(1, 'Category'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Civil / Building'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Done');

    expect(stepLabel(5, 'Review'), findsOneWidget);
    expect(find.text('Civil / Building'), findsOneWidget);
    final ReportDraft draft = container.read(reportDraftProvider);
    expect(draft.category, ProblemCategory.civil);
    expect(draft.trimmedRoom, 'Electronics Lab 204');
    expect(draft.photos, hasLength(1));
  });

  testWidgets('Close asks to discard; Discard clears the draft and goes Home', (
    tester,
  ) async {
    final ProviderContainer container = await startReport(tester);

    // Nothing entered: Close leaves without asking.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard report?'), findsNothing);
    expect(container.read(appRouterProvider).state.uri.path, AppRoutes.home);

    // With input: Keep editing stays, Discard leaves.
    await tester.tap(find.text('Report a Problem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Furniture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard report?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(stepLabel(1, 'Category'), findsOneWidget);
    expect(
      container.read(reportDraftProvider).category,
      ProblemCategory.furniture,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(container.read(reportDraftProvider).hasInput, isFalse);
    expect(container.read(appRouterProvider).state.uri.path, AppRoutes.home);
  });

  testWidgets('My Complaints and Board offer Report a Problem to a reporter', (
    tester,
  ) async {
    await pumpCampusFix(tester);
    await signInAs(tester, UserRole.reporter);

    for (final String tab in <String>['My Complaints', 'Board']) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Report a Problem'), findsOneWidget, reason: tab);
      await tester.tap(find.text('Report a Problem'));
      await tester.pumpAndSettle();
      expect(stepLabel(1, 'Category'), findsOneWidget, reason: tab);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a maintenance worker has no Report a Problem on the Board', (
    tester,
  ) async {
    await pumpCampusFix(tester);
    await signInAs(tester, UserRole.maintenance);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Board'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Report a Problem'), findsNothing);
  });

  testWidgets('the report flow is closed to other roles (E-403)', (
    tester,
  ) async {
    final ProviderContainer container = await pumpCampusFix(tester);
    await signInAs(tester, UserRole.verifier);
    container.read(appRouterProvider).go(AppRoutes.reportCategory);
    await tester.pumpAndSettle();
    expect(find.text("You don't have access to this page"), findsOneWidget);
  });
}
