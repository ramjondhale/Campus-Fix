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

  group('what the screen shows', () {
    testWidgets('admin header: ID, status, effective priority with the '
        'Overridden marker, category, location, dates', (tester) async {
      await openDetail(tester, UserRole.admin, kAssignedOverridden);
      final Complaint c = seed(kAssignedOverridden);

      expect(find.byType(ComplaintIdText), findsOneWidget);
      expect(find.text(c.id), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        ComplaintStatus.assigned,
      );
      // The effective priority (the override) with the marker ...
      final PriorityTag header = tester
          .widgetList<PriorityTag>(find.byType(PriorityTag))
          .first;
      expect(header.priority, Priority.high);
      expect(header.overridden, isTrue);
      // ... in the header and beside the effective priority of the panel.
      expect(find.byType(OverriddenMarker), findsNWidgets(2));
      expect(find.byType(CategoryChip), findsOneWidget);
      expect(find.textContaining(c.building), findsWidgets);
      expect(find.textContaining('Created '), findsOneWidget);
      expect(find.textContaining('Updated '), findsOneWidget);
      expect(find.textContaining('Waiting '), findsOneWidget);
    });

    testWidgets('a resolved complaint shows no Waiting figure', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);
      expect(find.textContaining('Waiting '), findsNothing);
    });

    testWidgets('the Priority panel: computed, override, inputs and aging '
        '(admin only)', (tester) async {
      await openDetail(tester, UserRole.admin, kAssignedOverridden);
      final Complaint c = seed(kAssignedOverridden);

      expect(find.byType(PriorityPanel), findsOneWidget);
      final String text = detailText(tester);
      for (final String s in <String>[
        'Effective priority',
        'Computed priority',
        'Override',
        c.severity.label,
        c.peopleAffected.label,
        'Not flagged',
        'Aging',
      ]) {
        expect(text, contains(s), reason: s);
      }
      // Computed (medium) and effective (high) differ, both are shown.
      final List<Priority> tags = <Priority>[
        for (final PriorityTag t in tester.widgetList<PriorityTag>(
          find.descendant(
            of: find.byType(PriorityPanel),
            matching: find.byType(PriorityTag),
          ),
        ))
          t.priority,
      ];
      expect(tags, <Priority>[Priority.high, Priority.medium, Priority.high]);
    });

    testWidgets('the admin Assignment panel: department, assignee name and '
        'ID, who and when, Auto / Manual', (tester) async {
      await openDetail(tester, UserRole.admin, kInProgressManual);
      final Complaint c = seed(kInProgressManual);
      expect(c.assignment!.isManual, isTrue);

      final String text = detailText(tester);
      expect(text, contains(c.assignment!.department.label));
      expect(text, contains('Nitin Bhosale · MNT-CIV-02'));
      expect(text, contains('Sandeep Kapoor · ADM-01'));
      expect(text, contains(formatAbsoluteTime(c.assignment!.assignedAt)));
      expect(find.text('Manual'), findsOneWidget);

      // An auto-routed one says Auto.
      await openDetail(tester, UserRole.admin, kResolvedIt);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Manual'), findsNothing);
    });

    testWidgets('an unassigned complaint says so', (tester) async {
      await openDetail(tester, UserRole.admin, kReportedPlumbing);
      expect(find.text('Not assigned yet'), findsOneWidget);
      expect(find.text('Assignee'), findsNothing);
    });

    testWidgets('the admin timeline names the actor (name, ID) and the '
        'role, plus the note', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);

      final List<TimelineItem> items = tester
          .widgetList<TimelineItem>(find.byType(TimelineItem))
          .toList();
      expect(items, hasLength(seed(kResolvedIt).timeline.length));
      expect(items.map((i) => i.adminActorLine).toList(), <String?>[
        null, // the reporter: role only
        'Kiran Joshi · VER-01',
        'Kiran Joshi · VER-01',
        'Nikhil Sawant · MNT-IT-02',
        'Nikhil Sawant · MNT-IT-02',
      ]);
      expect(items.map((i) => i.actorRole).toList(), <UserRole>[
        UserRole.reporter,
        UserRole.verifier,
        UserRole.verifier,
        UserRole.maintenance,
        UserRole.maintenance,
      ]);
      expect(find.text('Auto-routed to IT Team'), findsOneWidget);
    });

    testWidgets('a rework (T7) is marked on the timeline', (tester) async {
      await openDetail(tester, UserRole.admin, 'CF-2026-00017');
      expect(
        tester
            .widgetList<TimelineItem>(find.byType(TimelineItem))
            .where((i) => i.isRework),
        hasLength(1),
      );
      expect(find.text('Rework'), findsOneWidget);
    });

    testWidgets('description, photos, the Before / After comparator and the '
        'resolution note', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);
      final Complaint c = seed(kResolvedIt);

      expect(find.text(c.description), findsOneWidget);
      expect(find.byType(BeforeAfter), findsOneWidget);
      expect(
        find.byType(PhotoThumbnail),
        findsNWidgets(c.beforePhotos.length + c.afterPhotos.length),
      );
      expect(find.text('Resolution note'), findsOneWidget);
      expect(find.text(c.resolutionNote!), findsWidgets);

      // No after photos yet: no comparator, no resolution note.
      await openDetail(tester, UserRole.verifier, kReportedPlumbing);
      expect(find.byType(BeforeAfter), findsNothing);
      expect(find.text('Resolution note'), findsNothing);
    });

    testWidgets('a photo opens large and closes again', (tester) async {
      await openDetail(tester, UserRole.admin, kReportedPlumbing);
      await tapVisible(tester, find.byType(PhotoThumbnail).first);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Close photo'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });

  group('AC-53 manage actions: shown by status and role', () {
    // status -> (complaint, admin labels, verifier labels)
    final Map<ComplaintStatus, (String, List<String>, List<String>)> table =
        <ComplaintStatus, (String, List<String>, List<String>)>{
          ComplaintStatus.reported: (
            kReportedPlumbing,
            <String>['Review & Route'],
            <String>['Review & Route'],
          ),
          ComplaintStatus.reviewed: (
            kReviewedSafety,
            <String>['Assign'],
            <String>[],
          ),
          ComplaintStatus.assigned: (
            kAssignedCarpenter,
            <String>['Start work on behalf', 'Reassign'],
            <String>[],
          ),
          ComplaintStatus.inProgress: (
            kInProgressElectrical,
            <String>['Reassign', 'Resolve on behalf'],
            <String>[],
          ),
          ComplaintStatus.resolved: (
            kResolvedIt,
            <String>['Verify', 'Reject — needs rework'],
            <String>['Verify', 'Reject — needs rework'],
          ),
          ComplaintStatus.verified: (
            kVerifiedCivil,
            <String>['Close'],
            <String>[],
          ),
          ComplaintStatus.closed: (kClosedFurniture, <String>[], <String>[]),
        };

    for (final ComplaintStatus status in ComplaintStatus.values) {
      testWidgets('${status.label}: what an admin and a verifier are offered', (
        tester,
      ) async {
        final (String id, List<String> admin, List<String> verifier) =
            table[status]!;
        await openDetail(tester, UserRole.admin, id);
        expect(barLabels(tester), admin, reason: 'admin, ${status.label}');
        await openDetail(tester, UserRole.verifier, id);
        expect(
          barLabels(tester),
          verifier,
          reason: 'verifier, ${status.label}',
        );
      });
    }

    testWidgets('a closed complaint is read-only: a banner, no action and '
        'no priority edit (INV-4)', (tester) async {
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        await openDetail(tester, role, kClosedFurniture);
        expect(find.text('This complaint is closed'), findsOneWidget);
        expect(barLabels(tester), isEmpty);
        expect(buttonIn('Set priority override'), findsNothing);
        expect(buttonIn('Flag as safety issue'), findsNothing);
        expect(find.byType(AppDialog), findsNothing);
      }
    });

    testWidgets('a verifier on a reviewed, unrouted complaint is told an '
        'admin assigns it (AC-55)', (tester) async {
      await openDetail(tester, UserRole.verifier, kReviewedSafety);
      expect(buttonIn('Assign'), findsNothing);
      expect(find.textContaining('An admin assigns it'), findsOneWidget);
    });

    testWidgets('Verify is disabled with the rule\'s reason when the repair '
        'evidence is missing; Reject stays open', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await writeComplaint(
        tester,
        container,
        seed(kResolvedIt).copyWith(
          afterPhotos: const <Attachment>[],
          clearResolutionNote: true,
        ),
      );

      expect(isEnabled(tester, barButton('Verify')), isFalse);
      expect(isEnabled(tester, barButton('Reject — needs rework')), isTrue);
      expect(
        find.text(
          'Add at least one after-repair photo. Add a resolution note.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the safety flag is disabled with the reason once resolved '
        'and on a Safety complaint', (tester) async {
      await openDetail(tester, UserRole.admin, kResolvedIt);
      expect(isEnabled(tester, buttonIn('Flag as safety issue')), isFalse);
      expect(
        find.text('The safety flag cannot change once the repair is done.'),
        findsOneWidget,
      );
      expect(isEnabled(tester, buttonIn('Set priority override')), isTrue);

      await openDetail(tester, UserRole.admin, 'CF-2026-00021');
      expect(isEnabled(tester, buttonIn('Remove safety flag')), isFalse);
      expect(
        find.text('A Safety complaint is always flagged.'),
        findsOneWidget,
      );
    });

    testWidgets('Reject needs a reason: the button stays disabled until '
        'there is one', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);
      await tapVisible(tester, barButton('Reject — needs rework'));

      expect(find.byType(AppDialog), findsOneWidget);
      expect(isEnabled(tester, dialogButton('Reject')), isFalse);

      await tester.enterText(find.byType(EditableText).last, '   ');
      await tester.pump();
      expect(isEnabled(tester, dialogButton('Reject')), isFalse);

      await tester.enterText(find.byType(EditableText).last, 'Still leaking');
      await tester.pump();
      expect(isEnabled(tester, dialogButton('Reject')), isTrue);
    });

    testWidgets('Cancel closes the dialog and changes nothing', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await tapVisible(tester, barButton('Verify'));
      expect(find.byType(AppDialog), findsOneWidget);

      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(
        (await storedComplaint(tester, container, kResolvedIt)).status,
        ComplaintStatus.resolved,
      );
    });
  });
}
