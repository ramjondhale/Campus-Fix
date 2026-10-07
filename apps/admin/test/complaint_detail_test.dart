import 'package:campusfix_admin/features/complaint_detail/assignment_panel.dart';
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

  group('actions end to end: dialog, service, screen', () {
    testWidgets('Verify (verifier): confirm, then the screen shows Verified '
        'and the verifier has nothing left to do', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await tapVisible(tester, barButton('Verify'));
      expect(find.text('Verify the repair of $kResolvedIt?'), findsOneWidget);

      await tester.tap(dialogButton('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Repair verified'), findsOneWidget, reason: 'toast');
      expect(shownStatus(tester), ComplaintStatus.verified);
      expect(barLabels(tester), isEmpty, reason: 'a verifier cannot close');
      final Complaint c = await storedComplaint(tester, container, kResolvedIt);
      expect(c.status, ComplaintStatus.verified);
      expect(c.timeline.last.actorRole, UserRole.verifier);
    });

    testWidgets('Reject (verifier): the reason goes to the timeline and the '
        'complaint returns to In Progress', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await tapVisible(tester, barButton('Reject — needs rework'));
      await tester.enterText(dialogFields.last, 'The cable is still loose.');
      await tester.pump();
      await tester.tap(dialogButton('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Sent back for rework'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.inProgress);
      expect(find.text('The cable is still loose.'), findsOneWidget);
      expect(find.text('Rework'), findsOneWidget);
      expect(
        (await storedComplaint(tester, container, kResolvedIt)).status,
        ComplaintStatus.inProgress,
      );
      // The verifier's timeline still has no actor identity.
      expect(leaksIn(detailText(tester), allStaffSentinels()), isEmpty);
    });

    testWidgets('Close (admin): the complaint closes and becomes read-only', (
      tester,
    ) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kVerifiedCivil,
      );
      await tapVisible(tester, barButton('Close'));
      expect(find.text('Close $kVerifiedCivil?'), findsOneWidget);
      await tester.tap(dialogButton('Close complaint'));
      await tester.pumpAndSettle();

      expect(find.text('Complaint closed'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.closed);
      expect(find.text('This complaint is closed'), findsOneWidget);
      expect(barLabels(tester), isEmpty);
      expect(buttonIn('Set priority override'), findsNothing);
      expect(
        (await storedComplaint(tester, container, kVerifiedCivil)).status,
        ComplaintStatus.closed,
      );
    });

    testWidgets('Review & Route (admin): pre-set to the category\'s route, '
        'an auto assignment', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReportedPlumbing,
      );
      await tapVisible(tester, barButton('Review & Route'));
      // The department choice is pre-set to the route of Plumbing.
      expect(chipChosen(tester, 'Plumber'), isTrue);
      expect(chipChosen(tester, 'Anyone in the department'), isTrue);
      expect(chosenChips(tester), 2);

      await tester.tap(dialogButton('Review and route'));
      await tester.pumpAndSettle();

      expect(shownStatus(tester), ComplaintStatus.assigned);
      expect(find.text('Auto'), findsOneWidget);
      final Complaint c = await storedComplaint(
        tester,
        container,
        kReportedPlumbing,
      );
      expect(c.assignment!.department, Department.plumber);
      expect(c.assignment!.isManual, isFalse);
      // T1 and T2, both by the admin, both named on the admin timeline.
      expect(c.timeline.map((e) => e.status).toList().sublist(1), <Object>[
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
      ]);
      expect(find.text('Sandeep Kapoor · ADM-01'), findsNWidgets(3));
    });

    testWidgets('Review & Route (admin): another department makes it a '
        'manual assignment', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReportedPlumbing,
      );
      await tapVisible(tester, barButton('Review & Route'));
      await chooseChip(tester, 'Civil Maintenance');
      expect(
        find.textContaining('makes this a manual assignment'),
        findsOneWidget,
      );
      await tester.tap(dialogButton('Review and route'));
      await tester.pumpAndSettle();

      expect(find.text('Manual'), findsOneWidget);
      final Complaint c = await storedComplaint(
        tester,
        container,
        kReportedPlumbing,
      );
      expect(c.assignment!.department, Department.civilMaintenance);
      expect(c.assignment!.isManual, isTrue);
    });

    testWidgets('Review & Route (admin) on Other: nothing pre-set; without a '
        'department it ends at Reviewed', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReportedOther,
      );
      await tapVisible(tester, barButton('Review & Route'));
      // Nothing is pre-set for Other: no department chosen.
      expect(chosenChips(tester), 0);
      expect(
        dialogText(tester),
        contains('This category has no default department.'),
      );

      await tester.tap(dialogButton('Review and route'));
      await tester.pumpAndSettle();

      expect(shownStatus(tester), ComplaintStatus.reviewed);
      expect(find.text('Not assigned yet'), findsOneWidget);
      expect(barLabels(tester), <String>['Assign'], reason: 'admin assigns');
      expect(
        (await storedComplaint(tester, container, kReportedOther)).assignment,
        isNull,
      );
    });

    testWidgets('Review & Route (verifier) on Other is confirm-only and '
        'ends at Reviewed; a verifier cannot assign (AC-55)', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kReportedOther,
      );
      await tapVisible(tester, barButton('Review & Route'));
      // Confirm-only: no department, no staff, no note field.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(AppFilterChip),
        ),
        findsNothing,
      );
      expect(dialogFields, findsNothing);
      expect(
        dialogText(tester),
        contains('This category has no default department'),
      );

      await tester.tap(dialogButton('Review and route'));
      await tester.pumpAndSettle();

      expect(shownStatus(tester), ComplaintStatus.reviewed);
      expect(buttonIn('Assign'), findsNothing);
      expect(find.textContaining('An admin assigns it'), findsOneWidget);
      expect(
        (await storedComplaint(tester, container, kReportedOther)).assignment,
        isNull,
      );
    });

    testWidgets('Assign (admin) a Safety complaint: department and staff '
        'member, a manual assignment (AC-55)', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReviewedSafety,
      );
      await tapVisible(tester, barButton('Assign'));
      // Nothing pre-selected: the button waits for a department, and the
      // staff choice for the department.
      expect(chosenChips(tester), 0);
      expect(dialogText(tester), contains('Choose a department first.'));
      expect(isEnabled(tester, dialogButton('Assign')), isFalse);

      await chooseChip(tester, 'Electrician');
      expect(isEnabled(tester, dialogButton('Assign')), isTrue);
      // The staff of that department only.
      expect(dialogChip('Suresh Patil · MNT-ELE-01'), findsOneWidget);
      expect(dialogChip('Ganesh Jadhav · MNT-ELE-02'), findsOneWidget);
      expect(dialogChip('Mahesh Gaikwad · MNT-PLU-01'), findsNothing);
      await chooseChip(tester, 'Suresh Patil · MNT-ELE-01');
      await tester.tap(dialogButton('Assign'));
      await tester.pumpAndSettle();

      expect(find.text('Complaint assigned'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.assigned);
      expect(find.text('Suresh Patil · MNT-ELE-01'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      final Complaint c = await storedComplaint(
        tester,
        container,
        kReviewedSafety,
      );
      expect(c.assignment!.assigneeId, 'u-mnt-ele-01');
    });

    testWidgets('Reassign (admin): the reason is required; an unchanged '
        'assignment is blocked inline, a real change goes through', (
      tester,
    ) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kAssignedCarpenter,
      );
      await tapVisible(tester, barButton('Reassign'));
      expect(isEnabled(tester, dialogButton('Reassign')), isFalse);

      // The same department and nobody in particular: no change.
      await chooseChip(tester, 'Carpenter');
      expect(isEnabled(tester, dialogButton('Reassign')), isFalse);
      await tester.enterText(dialogFields.last, 'Try again');
      await tester.pump();
      expect(isEnabled(tester, dialogButton('Reassign')), isTrue);
      await tester.tap(dialogButton('Reassign'));
      await tester.pumpAndSettle();

      // Blocked: the dialog stays, the rule's message is shown inline.
      expect(find.byType(AppDialog), findsOneWidget);
      expect(
        dialogText(tester),
        contains('Choose a different department or assignee.'),
      );
      expect(
        (await storedComplaint(
          tester,
          container,
          kAssignedCarpenter,
        )).assignment!.department,
        Department.carpenter,
      );

      await chooseChip(tester, 'Civil Maintenance');
      await tester.tap(dialogButton('Reassign'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Complaint reassigned'), findsOneWidget);
      expect(find.text('Civil Maintenance'), findsWidgets);
      final Complaint c = await storedComplaint(
        tester,
        container,
        kAssignedCarpenter,
      );
      expect(c.assignment!.department, Department.civilMaintenance);
      expect(c.timeline.last.note, contains('Try again'));
    });

    testWidgets('Start work on behalf (admin)', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kAssignedCarpenter,
      );
      await tapVisible(tester, barButton('Start work on behalf'));
      await tester.tap(dialogButton('Start work'));
      await tester.pumpAndSettle();

      expect(find.text('Work started'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.inProgress);
      expect(
        (await storedComplaint(tester, container, kAssignedCarpenter)).status,
        ComplaintStatus.inProgress,
      );
    });

    testWidgets('Resolve on behalf (admin): after-photos and a note, the '
        'same form as M-15', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kInProgressElectrical,
      );
      await tapVisible(tester, barButton('Resolve on behalf'));

      expect(find.byType(PhotoUploader), findsOneWidget);
      expect(isEnabled(tester, dialogButton('Mark resolved')), isFalse);
      expect(
        dialogText(tester),
        contains('Add after-repair photo: at least 1 is required.'),
      );

      await tester.tap(find.text('Add a photo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo (sample)'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5'), findsOneWidget);
      expect(isEnabled(tester, dialogButton('Mark resolved')), isFalse);

      await tester.enterText(dialogFields.last, 'Replaced the breaker.');
      await tester.pump();
      expect(isEnabled(tester, dialogButton('Mark resolved')), isTrue);
      await tester.tap(dialogButton('Mark resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Marked as resolved'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.resolved);
      expect(find.text('Replaced the breaker.'), findsWidgets);
      final Complaint c = await storedComplaint(
        tester,
        container,
        kInProgressElectrical,
      );
      expect(c.afterPhotos, hasLength(1));
      expect(c.afterPhotos.single.kind, AttachmentKind.afterPhoto);
      // The next step is the verifier's, offered to the admin too.
      expect(barLabels(tester), <String>['Verify', 'Reject — needs rework']);
    });

    testWidgets('in flight: the buttons wait, and there is no double '
        'submit', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
        latency: const Duration(milliseconds: 50),
      );
      await tapVisible(tester, barButton('Verify'));

      await tester.tap(dialogButton('Verify'));
      await tester.pump();
      // Sending: the button shows its spinner, Cancel and the bar wait.
      expect(tester.widget<AppButton>(dialogButton('Verify')).loading, isTrue);
      expect(isEnabled(tester, dialogButton('Cancel')), isFalse);
      expect(isEnabled(tester, barButton('Reject — needs rework')), isFalse);
      // A second tap on the spinning button is ignored.
      await tester.tap(dialogButton('Verify'), warnIfMissed: false);
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      final Complaint c = await storedComplaint(tester, container, kResolvedIt);
      expect(
        c.timeline.where((e) => e.status == ComplaintStatus.verified),
        hasLength(1),
      );
    });

    testWidgets('stale: another admin changed the complaint while the dialog '
        'was open (P8)', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await tapVisible(tester, barButton('Verify'));
      // Somebody else verifies it first.
      await writeComplaint(
        tester,
        container,
        seed(kResolvedIt).copyWith(status: ComplaintStatus.verified),
      );

      await tester.tap(dialogButton('Verify'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(dialogText(tester), contains('This complaint changed'));
      expect(find.text('Refresh'), findsOneWidget);
      // Nothing was applied by this attempt.
      expect(
        (await storedComplaint(tester, container, kResolvedIt)).timeline.length,
        seed(kResolvedIt).timeline.length,
      );

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(shownStatus(tester), ComplaintStatus.verified);
    });

    testWidgets('a failed write keeps the dialog and its input and offers '
        'the same button again', (tester) async {
      await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWith(
            (ref) =>
                FailingWritesComplaintRepository(initial: testSeed.complaints),
          ),
        ],
      );
      await tapVisible(tester, barButton('Reject — needs rework'));
      await tester.enterText(dialogFields.last, 'Needs another look');
      await tester.pump();
      await tester.tap(dialogButton('Reject'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(dialogText(tester), contains("Couldn't complete this action"));
      expect(dialogText(tester), contains("We couldn't send the job back."));
      expect(isEnabled(tester, dialogButton('Reject')), isTrue);
      expect(find.text('Needs another look'), findsOneWidget);
      expect(shownStatus(tester), ComplaintStatus.resolved);
    });
  });

  group('AC-54 priority override and safety flag (admin)', () {
    testWidgets('setting an override changes the effective priority on this '
        'screen, not the computed one; clearing restores it', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReportedPlumbing,
      );
      // The public feeds are only live while something listens (the list
      // under the detail is paused): listen like A-02 / A-03 would.
      final ProviderSubscription<AsyncValue<List<PublicComplaintView>>> feed =
          container.listen(allComplaintsProvider, (_, _) {});
      addTearDown(feed.close);
      final Complaint before = seed(kReportedPlumbing);
      expect(before.priority, Priority.medium);
      expect(headerPriority(tester), (
        priority: Priority.medium,
        overridden: false,
      ));
      expect(find.byType(OverriddenMarker), findsNothing);

      await tapVisible(tester, buttonIn('Set priority override'));
      // Unchanged: nothing to apply yet.
      expect(isEnabled(tester, dialogButton('Clear override')), isFalse);
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Critical'),
        ),
      );
      await tester.pumpAndSettle();
      // The dialog previews the resulting priority.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(PriorityTag),
        ),
        findsOneWidget,
      );
      await tester.tap(dialogButton('Set override'));
      await tester.pumpAndSettle();

      expect(find.text('Priority updated'), findsOneWidget);
      expect(headerPriority(tester), (
        priority: Priority.critical,
        overridden: true,
      ));
      expect(find.byType(OverriddenMarker), findsNWidgets(2));
      // The panel still shows the computed priority, unchanged.
      final List<Priority> panel = <Priority>[
        for (final PriorityTag t in tester.widgetList<PriorityTag>(
          find.descendant(
            of: find.byType(PriorityPanel),
            matching: find.byType(PriorityTag),
          ),
        ))
          t.priority,
      ];
      expect(panel, <Priority>[
        Priority.critical, // effective
        Priority.medium, // computed
        Priority.critical, // override
      ]);
      final Complaint stored = await storedComplaint(
        tester,
        container,
        kReportedPlumbing,
      );
      expect(stored.priority, before.priority);
      expect(stored.priorityOverride, Priority.critical);
      // ... and the public feeds (A-02 / A-03 / M-11) carry it.
      final List<PublicComplaintView> all = container
          .read(allComplaintsProvider)
          .requireValue;
      expect(
        all.firstWhere((v) => v.id == kReportedPlumbing).effectivePriority,
        Priority.critical,
      );

      // Clear it again.
      await tapVisible(tester, buttonIn('Change priority override'));
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('No override'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Clear override'));
      await tester.pumpAndSettle();

      expect(headerPriority(tester), (
        priority: Priority.medium,
        overridden: false,
      ));
      expect(find.byType(OverriddenMarker), findsNothing);
      final Complaint cleared = await storedComplaint(
        tester,
        container,
        kReportedPlumbing,
      );
      expect(cleared.priorityOverride, isNull);
      expect(cleared.priority, before.priority);
    });

    testWidgets('an existing override shows the marker, and clearing it '
        'restores the computed priority', (tester) async {
      await openDetail(tester, UserRole.admin, kAssignedOverridden);
      expect(headerPriority(tester), (
        priority: Priority.high,
        overridden: true,
      ));

      await tapVisible(tester, buttonIn('Change priority override'));
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('No override'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('Clear override'));
      await tester.pumpAndSettle();

      expect(headerPriority(tester), (
        priority: Priority.medium,
        overridden: false,
      ));
    });

    testWidgets('the safety flag recomputes the priority, and comes off '
        'again', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kReportedPlumbing,
      );
      await tapVisible(tester, buttonIn('Flag as safety issue'));
      await tester.tap(dialogButton('Flag as safety issue'));
      await tester.pumpAndSettle();

      expect(find.text('Safety flag updated'), findsOneWidget);
      expect(find.text('Flagged'), findsOneWidget);
      expect(
        headerPriority(tester).priority.weight,
        greaterThanOrEqualTo(Priority.high.weight),
      );
      expect(
        (await storedComplaint(
          tester,
          container,
          kReportedPlumbing,
        )).safetyFlag,
        isTrue,
      );

      await tapVisible(tester, buttonIn('Remove safety flag'));
      await tester.tap(dialogButton('Remove flag'));
      await tester.pumpAndSettle();
      expect(find.text('Not flagged'), findsOneWidget);
      expect(headerPriority(tester).priority, Priority.medium);
    });
  });

  group('states (G-3, G-4, G-6)', () {
    testWidgets('loading: a skeleton for both roles', (tester) async {
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        await openDetail(
          tester,
          role,
          kResolvedIt,
          overrides: <Override>[
            complaintRepositoryProvider.overrideWithValue(
              StalledComplaintRepository(),
            ),
          ],
        );
        expect(find.byType(DetailSkeleton), findsOneWidget, reason: role.name);
        expect(find.byType(ManageBar), findsNothing);
        expect(find.text('Reveal reporter identity'), findsNothing);
      }
    });

    testWidgets('error with Retry (admin), then the screen', (tester) async {
      // The dashboard behind the sign-in takes the first failed read, the
      // detail the second.
      final FlakyComplaintRepository repo = FlakyComplaintRepository(
        initial: testSeed.complaints,
        failures: 2,
      );
      await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.text("Couldn't load this complaint"), findsOneWidget);
      expect(find.byType(ManageBar), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load this complaint"), findsNothing);
      expect(find.text(kResolvedIt), findsOneWidget);
      expect(find.text('Reveal reporter identity'), findsOneWidget);
    });

    testWidgets('error with Retry (verifier), then the screen', (tester) async {
      final FlakyComplaintRepository repo = FlakyComplaintRepository(
        initial: testSeed.complaints,
        failures: 1,
      );
      await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.text("Couldn't load this complaint"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text(kResolvedIt), findsOneWidget);
      expect(barLabels(tester), <String>['Verify', 'Reject — needs rework']);
    });

    testWidgets('E-404 for an unknown ID, the same for both roles, with Go '
        'home', (tester) async {
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        final ProviderContainer container = await openDetail(
          tester,
          role,
          'CF-2026-99999',
        );
        expect(find.text("We couldn't find that complaint"), findsOneWidget);
        expect(find.byType(ManageBar), findsNothing);
        expect(find.byType(IdentityPanel), findsNothing);

        await tester.tap(find.text('Go home'));
        await tester.pumpAndSettle();
        expect(
          container.read(appRouterProvider).state.uri.path,
          AppRoutes.dashboard,
        );
      }
    });

    testWidgets('a complaint that turns closed while open becomes '
        'read-only live', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        kVerifiedCivil,
      );
      expect(barLabels(tester), <String>['Close']);
      await writeComplaint(
        tester,
        container,
        seed(kVerifiedCivil).copyWith(status: ComplaintStatus.closed),
      );
      expect(find.text('This complaint is closed'), findsOneWidget);
      expect(barLabels(tester), isEmpty);
    });
  });

  group('navigation (A-03 <-> A-04)', () {
    testWidgets('Back returns to the list with its filters', (tester) async {
      final ProviderContainer container = await pumpAdmin(tester);
      await signInAs(tester, UserRole.admin);
      const String url =
          '/complaints?unresolved=1&priority=critical,high&created=all';
      await openRoute(tester, container, url);

      await tester.tap(find.text('CF-2026-00027'));
      await tester.pumpAndSettle();
      expect(
        container.read(appRouterProvider).state.uri.toString(),
        AppRoutes.complaint('CF-2026-00027'),
        reason: 'the detail URL carries the ID only',
      );

      await tester.tap(buttonIn('Back to complaints'));
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider).state.uri.toString(), url);
    });

    testWidgets('a direct link has a list to go back to', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        kResolvedIt,
      );
      await tester.tap(buttonIn('Back to complaints'));
      await tester.pumpAndSettle();
      expect(
        container.read(appRouterProvider).state.uri.path,
        AppRoutes.complaints,
      );
    });
  });

  group('privacy sweeps (R5, PV-4, PV-5)', () {
    testWidgets('verifier: no reporter and no staff identity on any '
        'complaint', (tester) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.verifier,
        testSeed.complaints.first.id,
      );
      for (final Complaint c in testSeed.complaints) {
        await openRoute(tester, container, AppRoutes.complaint(c.id));
        expect(find.text(c.id), findsOneWidget, reason: c.id);
        final String text = detailText(tester);
        expect(leaksIn(text, allReporterSentinels()), isEmpty, reason: c.id);
        expect(leaksIn(text, allStaffSentinels()), isEmpty, reason: c.id);
        expect(find.byType(IdentityPanel), findsNothing);
      }
    });

    testWidgets('admin: no reporter identity on any complaint until Reveal', (
      tester,
    ) async {
      final ProviderContainer container = await openDetail(
        tester,
        UserRole.admin,
        testSeed.complaints.first.id,
      );
      for (final Complaint c in testSeed.complaints) {
        await openRoute(tester, container, AppRoutes.complaint(c.id));
        expect(find.text(c.id), findsOneWidget, reason: c.id);
        expect(
          leaksIn(detailText(tester), allReporterSentinels()),
          isEmpty,
          reason: c.id,
        );
        expect(find.text('Reveal reporter identity'), findsOneWidget);
      }
    });

    testWidgets('the dialogs hold no identity either', (tester) async {
      await openDetail(tester, UserRole.verifier, kResolvedIt);
      await tapVisible(tester, barButton('Reject — needs rework'));
      expect(leaksIn(dialogText(tester), allReporterSentinels()), isEmpty);
      expect(leaksIn(dialogText(tester), allStaffSentinels()), isEmpty);
    });
  });

  group('responsive layout', () {
    for (final Size size in const <Size>[
      Size(1440, 900),
      Size(1100, 800),
      Size(800, 900),
      Size(480, 900),
    ]) {
      testWidgets('lays out without overflow at ${size.width.toInt()} px', (
        tester,
      ) async {
        for (final UserRole role in <UserRole>[
          UserRole.admin,
          UserRole.verifier,
        ]) {
          final ProviderContainer container = await openDetail(
            tester,
            role,
            kResolvedIt,
            size: size,
          );
          expect(tester.takeException(), isNull, reason: role.name);
          await tapVisible(tester, find.widgetWithText(AppButton, 'Verify'));
          expect(tester.takeException(), isNull, reason: 'dialog');
          await tester.tap(dialogButton('Cancel'));
          await tester.pumpAndSettle();
          if (role == UserRole.admin) {
            await openRoute(
              tester,
              container,
              AppRoutes.complaint(kInProgressManual),
            );
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  });
}
