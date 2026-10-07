import 'package:campusfix_admin/app.dart' show noAutoRetry;
import 'package:campusfix_admin/features/complaint_detail/assignment_panel.dart';
import 'package:campusfix_admin/features/complaint_detail/complaint_detail_controller.dart';
import 'package:campusfix_admin/features/complaint_detail/detail_widgets.dart';
import 'package:campusfix_admin/features/complaint_detail/identity_panel.dart';
import 'package:campusfix_admin/features/complaint_detail/manage_bar.dart';
import 'package:campusfix_admin/features/complaint_detail/priority_panel.dart';
import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_admin/providers/repositories.dart'
    show complaintRepositoryProvider;
import 'package:campusfix_admin/router/app_router.dart';
import 'package:campusfix_admin/router/routes.dart';
import 'package:campusfix_admin/shell/admin_top_bar.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/detail_helpers.dart';
import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/rendered_text.dart';

void main() {
  group('AC-51 reporter identity reveal (admin)', () {
    final Complaint c = seed(kResolvedIt);

    testWidgets('the panel is collapsed on load and the page text holds no '
        'identity until Reveal', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);

      expect(find.byType(IdentityPanel), findsOneWidget);
      expect(find.text('Reveal reporter identity'), findsOneWidget);
      expect(find.text(kIdentityReminder), findsOneWidget);
      // Neither this reporter nor any other leaks into the page (the staff
      // names an admin may see are another matter).
      expect(leaksIn(detailText(tester), allReporterSentinels()), isEmpty);
      // The identity is not even built into the tree while collapsed.
      expect(
        find.descendant(
          of: find.byType(IdentityPanel),
          matching: find.text(c.reporter.fullName, skipOffstage: false),
        ),
        findsNothing,
      );
    });

    testWidgets('Reveal shows the full name, ID number, e-mail and phone '
        'of this reporter only', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);

      await tapVisible(tester, buttonIn('Reveal reporter identity'));

      final String text = detailText(tester);
      for (final String s in <String>[
        c.reporter.fullName,
        c.reporter.idNumber,
        c.reporter.email,
        c.reporter.phone!,
      ]) {
        expect(text, contains(s));
      }
      expect(find.text('Reveal reporter identity'), findsNothing);
      // Nobody else's identity comes with it.
      final List<String> others = <String>[
        for (final Complaint o in testSeed.complaints)
          if (o.reporter.userId != c.reporter.userId) ...reporterSentinels(o),
      ];
      expect(
        leaksIn(
          text,
          others,
        ).where((String s) => !reporterSentinels(c).contains(s)).toList(),
        isEmpty,
      );
    });

    testWidgets('Hide collapses it again', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);
      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(detailText(tester), contains(c.reporter.fullName));

      await tapVisible(tester, buttonIn('Hide'));

      expect(detailText(tester), isNot(contains(c.reporter.fullName)));
      expect(find.text('Reveal reporter identity'), findsOneWidget);
    });

    testWidgets('it re-collapses on navigation (LK-8)', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
      );
      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(detailText(tester), contains(c.reporter.idNumber));

      // Away and back.
      await openRoute(tester, container, AppRoutes.complaints);
      await openRoute(tester, container, AppRoutes.complaint(kResolvedIt));

      expect(find.text('Reveal reporter identity'), findsOneWidget);
      expect(leaksIn(detailText(tester), allReporterSentinels()), isEmpty);
    });

    testWidgets('another complaint opened from the same screen starts '
        'collapsed', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
      );
      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(detailText(tester), contains(c.reporter.fullName));

      final Complaint other = seed(kInProgressElectrical);
      await openRoute(tester, container, AppRoutes.complaint(other.id));

      expect(find.text('Reveal reporter identity'), findsOneWidget);
      expect(leaksIn(detailText(tester), reporterSentinels(other)), isEmpty);
      expect(
        leaksIn(detailText(tester), <String>[c.reporter.fullName]),
        isEmpty,
      );
    });

    testWidgets('it re-collapses on sign-out: nothing of it survives, and '
        'the next session starts collapsed', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
      );
      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(detailText(tester), contains(c.reporter.email));

      await tester.tap(find.text('Sign out').first);
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider), isNull);
      expect(find.byType(IdentityPanel), findsNothing);
      expect(
        leaksIn(allRenderedText(tester), reporterSentinels(c)),
        isEmpty,
        reason: 'the Login page shows nothing of the reporter',
      );

      await signInAs(tester, UserRole.admin);
      await openRoute(tester, container, AppRoutes.complaint(kResolvedIt));
      expect(find.text('Reveal reporter identity'), findsOneWidget);
      expect(leaksIn(detailText(tester), reporterSentinels(c)), isEmpty);
    });

    testWidgets('the identity is never in the URL or the page title', (
      tester,
    ) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
      );
      await tapVisible(tester, buttonIn('Reveal reporter identity'));

      final Uri uri = container.read(appRouterProvider).state.uri;
      expect(uri.toString(), AppRoutes.complaint(kResolvedIt));
      expect(uri.query, isEmpty);
      expect(leaksIn(uri.toString(), reporterSentinels(c)), isEmpty);

      final String titles = <String>[
        for (final Title t in tester.widgetList<Title>(find.byType(Title)))
          t.title,
      ].join(' ');
      expect(titles, 'CampusFix Admin');
      // The top bar's page title is the fixed "Complaint details".
      expect(
        find.descendant(
          of: find.byType(AdminShellTopBar),
          matching: find.text('Complaint details'),
        ),
        findsOneWidget,
      );
      expect(
        leaksIn(
          allRenderedText(tester, within: find.byType(AdminShellTopBar)),
          reporterSentinels(c),
        ),
        isEmpty,
      );
    });

    testWidgets('there is no copy or export of the identity', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);
      await tapVisible(tester, buttonIn('Reveal reporter identity'));

      final Finder panel = find.byType(IdentityPanel);
      expect(
        find.descendant(of: panel, matching: find.byType(SelectableText)),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.byType(SelectionArea)),
        findsNothing,
      );
      final List<String> labels = <String>[
        for (final AppButton b in tester.widgetList<AppButton>(
          find.descendant(of: panel, matching: find.byType(AppButton)),
        ))
          b.label,
      ];
      expect(labels, <String>['Hide']);
      expect(
        find.descendant(of: panel, matching: find.byType(IconButton)),
        findsNothing,
      );
    });

    testWidgets('a reporter without a phone shows "Not provided"', (
      tester,
    ) async {
      final Complaint noPhone = testSeed.complaints.firstWhere(
        (x) => x.reporter.phone == null,
      );
      await openDetail(tester, UserRole.admin, noPhone.id);
      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(detailText(tester), contains('Not provided'));
      expect(detailText(tester), contains(noPhone.reporter.fullName));
    });

    testWidgets('the reporter\'s own timeline event shows the role only, '
        'never the name, even after the reveal of nothing', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);
      final List<TimelineItem> items = tester
          .widgetList<TimelineItem>(find.byType(TimelineItem))
          .toList();
      expect(items.first.actorRole, UserRole.reporter);
      expect(items.first.adminActorLine, isNull);
      for (final TimelineItem i in items.skip(1)) {
        expect(i.adminActorLine, isNotNull, reason: i.status.name);
      }
    });
  });

  group('AC-52 verifier: public data only', () {
    testWidgets('no identity panel at all', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);

      expect(find.byType(IdentityPanel), findsNothing);
      final String text = detailText(tester);
      expect(text, isNot(contains('Reporter identity')));
      expect(text, isNot(contains('Reveal reporter identity')));
      expect(text, isNot(contains(kIdentityReminder)));
      expect(find.byType(AdminOnlyTag), findsNothing);
    });

    testWidgets('no assignee, assigner or actor names; the department label '
        'only', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);

      final String text = detailText(tester);
      expect(leaksIn(text, allStaffSentinels()), isEmpty);
      expect(leaksIn(text, allReporterSentinels()), isEmpty);
      expect(find.byType(AssignmentPanel), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('IT Team'), findsOneWidget);
      for (final String admin in <String>[
        'Assignee',
        'Assigned by',
        'Assigned at',
        'Routing',
        'Manual',
      ]) {
        expect(find.text(admin), findsNothing, reason: admin);
      }
    });

    testWidgets('no priority-input panel and no override marker', (
      tester,
    ) async {
      await openDetail(tester, UserRole.verifier, kAssignedOverridden);

      expect(find.byType(PriorityPanel), findsNothing);
      for (final String admin in <String>[
        'Computed priority',
        'Effective priority',
        'Severity',
        'People affected',
        'Safety flag',
        'Aging',
        'Set priority override',
        'Change priority override',
        'Flag as safety issue',
      ]) {
        expect(find.text(admin), findsNothing, reason: admin);
      }
      // The effective priority is shown, without the Overridden marker.
      expect(find.byType(OverriddenMarker), findsNothing);
      expect(find.text('High'), findsWidgets);
    });

    testWidgets('the timeline is the public form: role, time and note, no '
        'actor identity', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);

      expect(find.byType(ComplaintTimeline), findsOneWidget);
      final List<TimelineItem> items = tester
          .widgetList<TimelineItem>(find.byType(TimelineItem))
          .toList();
      expect(items, hasLength(seed(kResolvedIt).timeline.length));
      expect(items.every((i) => i.adminActorLine == null), isTrue);
      expect(find.byType(RolePill), findsWidgets);
      expect(find.text('Auto-routed to IT Team'), findsOneWidget);
      expect(
        find.text(seed(kResolvedIt).resolutionNote!),
        findsWidgets,
        reason: 'the note of the Resolved event is public',
      );
    });

    testWidgets('no Close control, on a verified complaint either', (
      tester,
    ) async {
      await openDetail(tester, UserRole.verifier, kVerifiedCivil);

      expect(buttonIn('Close'), findsNothing);
      expect(find.text('Close'), findsNothing);
      expect(barLabels(tester), isEmpty, reason: 'nothing to do');
      expect(
        find.text(
          'There is nothing for you to do on this complaint right now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an admin does get Close on the same complaint', (
      tester,
    ) async {
      await openDetail(tester, UserRole.admin, kVerifiedCivil);
      expect(barLabels(tester), <String>['Close']);
    });
  });
}
