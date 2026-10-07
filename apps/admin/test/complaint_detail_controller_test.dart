import 'package:campusfix_admin/features/complaint_detail/complaint_detail_controller.dart';
import 'package:campusfix_admin/providers/providers.dart';
// The barrel deliberately hides the raw complaint repository; tests reach it
// (to read what an action stored and to simulate failures) through its own
// library.
import 'package:campusfix_admin/providers/repositories.dart'
    show complaintRepositoryProvider;
import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/settled.dart';

// Seed complaints used below (deterministic seed, see SeedData):
const String reportedPlumbing = 'CF-2026-00025'; // reported, auto-routes
const String reportedOther = 'CF-2026-00029'; // reported, no route
const String reviewedSafety = 'CF-2026-00023'; // reviewed, unrouted
const String assignedCarpenter = 'CF-2026-00014'; // assigned, no assignee
const String inProgressElectrical = 'CF-2026-00011';
const String resolvedIt = 'CF-2026-00012';
const String verifiedCivil = 'CF-2026-00007';
const String closedFurniture = 'CF-2026-00001';

Future<ProviderContainer> signedIn(
  UserRole role, {
  List<Override> overrides = const <Override>[],
}) async {
  final ProviderContainer container = testContainer(overrides: overrides);
  final MockAccount account = demoAccount(role);
  await container
      .read(sessionProvider.notifier)
      .signIn(account.user.idNumber, account.password);
  return container;
}

Future<Complaint> stored(ProviderContainer c, String id) async =>
    (await c.read(complaintRepositoryProvider).byId(id))!;

DetailActionNotifier runner(ProviderContainer c, String id) {
  // Keep the auto-disposed runner alive for the whole test.
  c.listen(detailActionProvider(id), (_, _) {});
  return c.read(detailActionProvider(id).notifier);
}

Complaint seedComplaint(String id) =>
    testSeed.complaints.firstWhere((c) => c.id == id);

/// A public view in [status] with (by default) complete repair evidence.
PublicComplaintView viewIn(
  ComplaintStatus status, {
  bool evidence = true,
  ProblemCategory category = ProblemCategory.electrical,
  bool safetyFlag = false,
}) => PublicComplaintView(
  id: 'CF-T-001',
  category: category,
  building: 'Block A',
  floor: '1',
  room: '101',
  description: 'Synthetic complaint.',
  effectivePriority: Priority.medium,
  status: status,
  safetyFlag: safetyFlag,
  afterPhotos: evidence
      ? <Attachment>[
          Attachment(
            id: 'a1',
            kind: AttachmentKind.afterPhoto,
            ref: 'assets/samples/after_sample_1.jpg',
            createdAt: DateTime.utc(2026, 10),
          ),
        ]
      : const <Attachment>[],
  resolutionNote: evidence ? 'Fixed it.' : null,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 10),
);

List<ManageAction> actionsOf(List<ManageActionOption> o) => <ManageAction>[
  for (final ManageActionOption x in o) x.action,
];

/// A complaint store whose writes fail (to show the "couldn't" state).
class _FailingWrites extends MockComplaintRepository {
  _FailingWrites() : super(initial: testSeed.complaints);

  @override
  Future<Complaint> update(Complaint c) =>
      Future<Complaint>.error(StateError('simulated outage'));
}

void main() {
  group('manageActionsFor (AC-53: shown by status machine + role)', () {
    // The whole matrix: what each console role is offered in each status.
    const Map<ComplaintStatus, List<ManageAction>> admin =
        <ComplaintStatus, List<ManageAction>>{
          ComplaintStatus.reported: <ManageAction>[ManageAction.reviewAndRoute],
          ComplaintStatus.reviewed: <ManageAction>[ManageAction.assign],
          ComplaintStatus.assigned: <ManageAction>[
            ManageAction.startWork,
            ManageAction.reassign,
          ],
          ComplaintStatus.inProgress: <ManageAction>[
            ManageAction.reassign,
            ManageAction.resolve,
          ],
          ComplaintStatus.resolved: <ManageAction>[
            ManageAction.verify,
            ManageAction.reject,
          ],
          ComplaintStatus.verified: <ManageAction>[ManageAction.close],
          ComplaintStatus.closed: <ManageAction>[],
        };
    const Map<ComplaintStatus, List<ManageAction>> verifier =
        <ComplaintStatus, List<ManageAction>>{
          ComplaintStatus.reported: <ManageAction>[ManageAction.reviewAndRoute],
          ComplaintStatus.reviewed: <ManageAction>[],
          ComplaintStatus.assigned: <ManageAction>[],
          ComplaintStatus.inProgress: <ManageAction>[],
          ComplaintStatus.resolved: <ManageAction>[
            ManageAction.verify,
            ManageAction.reject,
          ],
          ComplaintStatus.verified: <ManageAction>[],
          ComplaintStatus.closed: <ManageAction>[],
        };

    test('an admin is offered the full flow, status by status', () {
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(
          actionsOf(manageActionsFor(viewIn(s), UserRole.admin)),
          admin[s],
          reason: s.name,
        );
      }
    });

    test('a verifier is offered Review, Verify and Reject only', () {
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(
          actionsOf(manageActionsFor(viewIn(s), UserRole.verifier)),
          verifier[s],
          reason: s.name,
        );
      }
    });

    test('every offered edge is legal in the status machine (L1)', () {
      const Map<ManageAction, ComplaintStatus> target =
          <ManageAction, ComplaintStatus>{
            ManageAction.reviewAndRoute: ComplaintStatus.reviewed,
            ManageAction.assign: ComplaintStatus.assigned,
            ManageAction.startWork: ComplaintStatus.inProgress,
            ManageAction.resolve: ComplaintStatus.resolved,
            ManageAction.verify: ComplaintStatus.verified,
            ManageAction.reject: ComplaintStatus.inProgress,
            ManageAction.close: ComplaintStatus.closed,
          };
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        for (final ComplaintStatus s in ComplaintStatus.values) {
          for (final ManageActionOption o in manageActionsFor(
            viewIn(s),
            role,
          )) {
            final ComplaintStatus? to = target[o.action];
            if (to == null) continue; // reassign: an annotation, not an edge
            expect(
              StatusMachine.canTransition(s, to, role),
              isTrue,
              reason: '${role.name} ${o.action.name} from ${s.name}',
            );
          }
        }
      }
    });

    test('Close, Assign, Reassign, Start and Resolve are admin only', () {
      for (final ManageAction a in <ManageAction>[
        ManageAction.assign,
        ManageAction.reassign,
        ManageAction.startWork,
        ManageAction.resolve,
        ManageAction.close,
        ManageAction.setPriorityOverride,
        ManageAction.toggleSafetyFlag,
      ]) {
        expect(mayTakeAction(a, UserRole.admin), isTrue, reason: a.name);
        expect(mayTakeAction(a, UserRole.verifier), isFalse, reason: a.name);
        expect(mayTakeAction(a, UserRole.maintenance), isFalse);
        expect(mayTakeAction(a, UserRole.reporter), isFalse);
      }
      for (final ManageAction a in <ManageAction>[
        ManageAction.reviewAndRoute,
        ManageAction.verify,
        ManageAction.reject,
      ]) {
        expect(mayTakeAction(a, UserRole.admin), isTrue, reason: a.name);
        expect(mayTakeAction(a, UserRole.verifier), isTrue, reason: a.name);
        expect(mayTakeAction(a, UserRole.maintenance), isFalse);
      }
    });

    test('a closed complaint is read-only for everyone (INV-4)', () {
      for (final UserRole role in UserRole.values) {
        final PublicComplaintView c = viewIn(ComplaintStatus.closed);
        expect(manageActionsFor(c, role), isEmpty);
        expect(priorityActionsFor(c, role), isEmpty);
      }
    });

    test('roles that cannot use the console are offered nothing', () {
      for (final UserRole role in <UserRole>[
        UserRole.reporter,
        UserRole.maintenance,
      ]) {
        for (final ComplaintStatus s in ComplaintStatus.values) {
          expect(manageActionsFor(viewIn(s), role), isEmpty);
        }
      }
    });

    test('Verify is disabled with the core rule reason when the evidence '
        'is missing; Reject stays open', () {
      final List<ManageActionOption> options = manageActionsFor(
        viewIn(ComplaintStatus.resolved, evidence: false),
        UserRole.verifier,
      );
      final ManageActionOption verify = options.firstWhere(
        (o) => o.action == ManageAction.verify,
      );
      expect(verify.enabled, isFalse);
      expect(
        verify.disabledReason,
        'Add at least one after-repair photo. Add a resolution note.',
      );
      expect(
        options.firstWhere((o) => o.action == ManageAction.reject).enabled,
        isTrue,
      );
      expect(
        verifyBlockedReason(viewIn(ComplaintStatus.resolved)),
        isNull,
        reason: 'complete evidence: nothing blocks Verify',
      );
    });
  });

  group('priorityActionsFor', () {
    test('an admin may override and flag until the repair is done', () {
      for (final ComplaintStatus s in <ComplaintStatus>[
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
      ]) {
        final List<ManageActionOption> o = priorityActionsFor(
          viewIn(s),
          UserRole.admin,
        );
        expect(actionsOf(o), <ManageAction>[
          ManageAction.setPriorityOverride,
          ManageAction.toggleSafetyFlag,
        ]);
        expect(o.every((x) => x.enabled), isTrue, reason: s.name);
      }
    });

    test('the override stays open after resolve, the flag does not', () {
      for (final ComplaintStatus s in <ComplaintStatus>[
        ComplaintStatus.resolved,
        ComplaintStatus.verified,
      ]) {
        final List<ManageActionOption> o = priorityActionsFor(
          viewIn(s),
          UserRole.admin,
        );
        expect(o.first.enabled, isTrue);
        expect(o.last.action, ManageAction.toggleSafetyFlag);
        expect(o.last.enabled, isFalse);
        expect(
          o.last.disabledReason,
          'The safety flag cannot change once the repair is done.',
        );
      }
    });

    test('a Safety complaint cannot lose its flag; the label follows the '
        'state', () {
      final PublicComplaintView safety = viewIn(
        ComplaintStatus.assigned,
        category: ProblemCategory.safety,
        safetyFlag: true,
      );
      final ManageActionOption flag = priorityActionsFor(
        safety,
        UserRole.admin,
      ).last;
      expect(flag.enabled, isFalse);
      expect(flag.disabledReason, 'A Safety complaint is always flagged.');
      expect(flag.label, 'Remove safety flag');

      final ManageActionOption plain = priorityActionsFor(
        viewIn(ComplaintStatus.assigned),
        UserRole.admin,
      ).last;
      expect(plain.enabled, isTrue);
      expect(plain.label, 'Flag as safety issue');

      expect(
        priorityActionsFor(
          viewIn(ComplaintStatus.assigned),
          UserRole.admin,
          hasOverride: true,
        ).first.label,
        'Change priority override',
      );
    });

    test('a verifier is offered no priority edit at all', () {
      for (final ComplaintStatus s in ComplaintStatus.values) {
        expect(priorityActionsFor(viewIn(s), UserRole.verifier), isEmpty);
      }
    });
  });

  group('complaintDetailProvider: the role split', () {
    test('an admin gets the admin form: full view and staff names', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final ComplaintDetail? detail = await settled(
        container,
        complaintDetailProvider(resolvedIt),
      );
      expect(detail, isNotNull);
      expect(detail!.isAdmin, isTrue);
      expect(detail.complaint, toPublicView(seedComplaint(resolvedIt)));
      expect(detail.admin!.view.id, resolvedIt);
      expect(detail.admin!.view.priority, seedComplaint(resolvedIt).priority);
      // The ids on the view resolve to staff name and ID.
      final Assignment a = seedComplaint(resolvedIt).assignment!;
      expect(detail.admin!.staffById(a.assigneeId)!.name, 'Nikhil Sawant');
      expect(detail.admin!.staffById(a.assignedBy)!.idNumber, 'VER-01');
    });

    test('the admin staff directory never holds a reporter', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final ComplaintDetail detail = (await settled(
        container,
        complaintDetailProvider(resolvedIt),
      ))!;
      final Set<String> reporterIds = <String>{
        for (final AppUser u in testSeed.usersWithRole(UserRole.reporter)) u.id,
      };
      expect(
        detail.admin!.staff.keys.toSet().intersection(reporterIds),
        isEmpty,
      );
      expect(
        detail.admin!.staff.values.map((s) => s.role).toSet().intersection(
          <UserRole>{UserRole.reporter},
        ),
        isEmpty,
      );
    });

    test('a verifier gets the limited form: a public view and no admin '
        'data at all (AC-52)', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);
      final ComplaintDetail? detail = await settled(
        container,
        complaintDetailProvider(resolvedIt),
      );
      expect(detail, isNotNull);
      expect(detail!.isAdmin, isFalse);
      expect(detail.admin, isNull);
      expect(detail.complaint, toPublicView(seedComplaint(resolvedIt)));
    });

    test('an unknown id is null (E-404) for both roles', () async {
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        final ProviderContainer container = await signedIn(role);
        expect(
          await settled(container, complaintDetailProvider('CF-9999-00000')),
          isNull,
          reason: role.name,
        );
      }
    });

    test('signed out, or a role outside the console, stays loading', () async {
      final ProviderContainer signedOut = testContainer();
      expect(
        signedOut.read(complaintDetailProvider(resolvedIt)).isLoading,
        isTrue,
      );
      final ProviderContainer reporter = await signedIn(UserRole.reporter);
      expect(
        reporter.read(complaintDetailProvider(resolvedIt)).isLoading,
        isTrue,
      );
    });

    test('both forms are live: a status change reaches the provider', () async {
      for (final UserRole role in <UserRole>[
        UserRole.admin,
        UserRole.verifier,
      ]) {
        final ProviderContainer container = await signedIn(role);
        final List<ComplaintStatus> seen = <ComplaintStatus>[];
        final sub = container.listen<AsyncValue<ComplaintDetail?>>(
          complaintDetailProvider(resolvedIt),
          (_, next) {
            final ComplaintDetail? d = next.value;
            if (d != null) seen.add(d.status);
          },
          fireImmediately: true,
        );
        addTearDown(sub.close);
        await settled(container, complaintDetailProvider(resolvedIt));

        await container
            .read(complaintRepositoryProvider)
            .update(
              seedComplaint(
                resolvedIt,
              ).copyWith(status: ComplaintStatus.verified),
            );
        await pumpEventQueue();
        expect(seen.last, ComplaintStatus.verified, reason: role.name);
      }
    });
  });

  group('DetailActionNotifier: who may do what', () {
    test('a verifier cannot assign, close or touch the priority even by '
        'calling the runner (AC-52, AC-55)', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);
      for (final (ManageAction a, String id, ComplaintStatus s)
          in <(ManageAction, String, ComplaintStatus)>[
            (ManageAction.close, verifiedCivil, ComplaintStatus.verified),
            (ManageAction.assign, reviewedSafety, ComplaintStatus.reviewed),
            (
              ManageAction.setPriorityOverride,
              reportedPlumbing,
              ComplaintStatus.reported,
            ),
            (
              ManageAction.toggleSafetyFlag,
              reportedPlumbing,
              ComplaintStatus.reported,
            ),
            (
              ManageAction.reassign,
              assignedCarpenter,
              ComplaintStatus.assigned,
            ),
            (
              ManageAction.startWork,
              assignedCarpenter,
              ComplaintStatus.assigned,
            ),
          ]) {
        final Complaint before = await stored(container, id);
        final DetailActionResult? r = await runner(container, id).run(
          a,
          seenStatus: s,
          input: const ManageInput(
            department: Department.electrician,
            priorityOverride: Priority.critical,
          ),
        );
        expect(r!.outcome, DetailActionOutcome.blocked, reason: a.name);
        expect(r.messages, <String>['You cannot take this action.']);
        expect(await stored(container, id), before, reason: 'unchanged');
      }
    });

    test('a verifier verifies and rejects (the reason is required)', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);
      final DetailActionNotifier n = runner(container, resolvedIt);

      final DetailActionResult? blank = await n.run(
        ManageAction.reject,
        seenStatus: ComplaintStatus.resolved,
        input: const ManageInput(note: '   '),
      );
      expect(blank!.outcome, DetailActionOutcome.blocked);
      expect(blank.messages, contains('Add a reason.'));
      expect(
        (await stored(container, resolvedIt)).status,
        ComplaintStatus.resolved,
      );

      final DetailActionResult? rejected = await n.run(
        ManageAction.reject,
        seenStatus: ComplaintStatus.resolved,
        input: const ManageInput(note: 'Still flickering.'),
      );
      expect(rejected!.ok, isTrue);
      final Complaint c = await stored(container, resolvedIt);
      expect(c.status, ComplaintStatus.inProgress);
      expect(c.timeline.last.note, 'Still flickering.');
      expect(c.timeline.last.actorRole, UserRole.verifier);

      // Another resolved complaint: verify.
      final DetailActionResult? verified = await runner(
        container,
        'CF-2026-00015',
      ).run(ManageAction.verify, seenStatus: ComplaintStatus.resolved);
      expect(verified!.ok, isTrue);
      expect(
        (await stored(container, 'CF-2026-00015')).status,
        ComplaintStatus.verified,
      );
    });

    test('an admin closes a verified complaint; a closed one accepts nothing '
        '(INV-4)', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final DetailActionResult? closed = await runner(
        container,
        verifiedCivil,
      ).run(ManageAction.close, seenStatus: ComplaintStatus.verified);
      expect(closed!.ok, isTrue);
      expect(
        (await stored(container, verifiedCivil)).status,
        ComplaintStatus.closed,
      );

      for (final ManageAction a in <ManageAction>[
        ManageAction.setPriorityOverride,
        ManageAction.toggleSafetyFlag,
        ManageAction.verify,
        ManageAction.reassign,
      ]) {
        final Complaint before = await stored(container, closedFurniture);
        final DetailActionResult? r = await runner(container, closedFurniture)
            .run(
              a,
              seenStatus: ComplaintStatus.closed,
              input: const ManageInput(
                department: Department.plumber,
                note: 'x',
                priorityOverride: Priority.low,
              ),
            );
        expect(r!.ok, isFalse, reason: a.name);
        expect(r.messages, isNotEmpty);
        expect(await stored(container, closedFurniture), before);
      }
    });
  });

  group('DetailActionNotifier: routing and assignment', () {
    test('Review & Route auto-routes by category; a verifier\'s review of '
        'Safety / Other ends at Reviewed (AC-55)', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);

      final DetailActionResult? routed = await runner(
        container,
        reportedPlumbing,
      ).run(ManageAction.reviewAndRoute, seenStatus: ComplaintStatus.reported);
      expect(routed!.ok, isTrue);
      final Complaint plumbing = await stored(container, reportedPlumbing);
      expect(plumbing.status, ComplaintStatus.assigned);
      expect(plumbing.assignment!.department, Department.plumber);
      expect(plumbing.assignment!.isManual, isFalse);

      final DetailActionResult? other = await runner(container, reportedOther)
          .run(
            ManageAction.reviewAndRoute,
            seenStatus: ComplaintStatus.reported,
            // A verifier's department is ignored: only an admin may choose.
            input: const ManageInput(department: Department.electrician),
          );
      expect(other!.ok, isTrue);
      final Complaint c = await stored(container, reportedOther);
      expect(c.status, ComplaintStatus.reviewed);
      expect(c.assignment, isNull);
    });

    test(
      'an admin may name the department in the same Review (manual)',
      () async {
        final ProviderContainer container = await signedIn(UserRole.admin);
        final DetailActionResult? r = await runner(container, reportedOther)
            .run(
              ManageAction.reviewAndRoute,
              seenStatus: ComplaintStatus.reported,
              input: const ManageInput(department: Department.itTeam),
            );
        expect(r!.ok, isTrue);
        final Complaint c = await stored(container, reportedOther);
        expect(c.status, ComplaintStatus.assigned);
        expect(c.assignment!.department, Department.itTeam);
        expect(c.assignment!.isManual, isTrue);
        expect(c.assignment!.assignedBy, demoAccount(UserRole.admin).user.id);
      },
    );

    test('Assign: only an admin; the department is required; the staff '
        'member must belong to it', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final DetailActionNotifier n = runner(container, reviewedSafety);

      final DetailActionResult? none = await n.run(
        ManageAction.assign,
        seenStatus: ComplaintStatus.reviewed,
      );
      expect(none!.messages, <String>['Choose a department.']);

      final DetailActionResult? wrong = await n.run(
        ManageAction.assign,
        seenStatus: ComplaintStatus.reviewed,
        input: const ManageInput(
          department: Department.electrician,
          assigneeId: 'u-mnt-plu-01',
        ),
      );
      expect(wrong!.messages, contains('Assignee not in that department.'));
      expect(
        (await stored(container, reviewedSafety)).status,
        ComplaintStatus.reviewed,
      );

      final DetailActionResult? ok = await n.run(
        ManageAction.assign,
        seenStatus: ComplaintStatus.reviewed,
        input: const ManageInput(
          department: Department.electrician,
          assigneeId: 'u-mnt-ele-01',
          note: 'Fuse board first.',
        ),
      );
      expect(ok!.ok, isTrue);
      final Complaint c = await stored(container, reviewedSafety);
      expect(c.status, ComplaintStatus.assigned);
      expect(c.assignment!.assigneeId, 'u-mnt-ele-01');
      expect(c.assignment!.isManual, isTrue, reason: 'Safety has no route');
    });

    test('Reassign: the reason is required, a real change is required and '
        'a reviewed complaint cannot be reassigned (RA2)', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);

      final DetailActionResult? ra2 = await runner(container, reviewedSafety)
          .run(
            ManageAction.reassign,
            seenStatus: ComplaintStatus.reviewed,
            input: const ManageInput(
              department: Department.electrician,
              note: 'Wrong team',
            ),
          );
      expect(ra2!.outcome, DetailActionOutcome.blocked);
      expect(ra2.messages.single, startsWith('Only assigned or in-progress'));

      final DetailActionNotifier n = runner(container, assignedCarpenter);
      final DetailActionResult? noReason = await n.run(
        ManageAction.reassign,
        seenStatus: ComplaintStatus.assigned,
        input: const ManageInput(department: Department.plumber),
      );
      expect(noReason!.messages, contains('Add a reason.'));

      final DetailActionResult? same = await n.run(
        ManageAction.reassign,
        seenStatus: ComplaintStatus.assigned,
        input: const ManageInput(
          department: Department.carpenter,
          note: 'Same team',
        ),
      );
      expect(
        same!.messages,
        contains('Choose a different department or assignee.'),
      );

      final DetailActionResult? ok = await n.run(
        ManageAction.reassign,
        seenStatus: ComplaintStatus.assigned,
        input: const ManageInput(
          department: Department.civilMaintenance,
          note: 'Needs a mason',
        ),
      );
      expect(ok!.ok, isTrue);
      final Complaint c = await stored(container, assignedCarpenter);
      expect(c.assignment!.department, Department.civilMaintenance);
      expect(c.timeline.last.note, contains('Needs a mason'));
    });

    test(
      'Start and Resolve on behalf; Resolve needs a photo and a note',
      () async {
        final ProviderContainer container = await signedIn(UserRole.admin);
        final DetailActionResult? started = await runner(
          container,
          assignedCarpenter,
        ).run(ManageAction.startWork, seenStatus: ComplaintStatus.assigned);
        expect(started!.ok, isTrue);
        expect(
          (await stored(container, assignedCarpenter)).status,
          ComplaintStatus.inProgress,
        );

        final DetailActionNotifier n = runner(container, inProgressElectrical);
        final DetailActionResult? bare = await n.run(
          ManageAction.resolve,
          seenStatus: ComplaintStatus.inProgress,
          input: const ManageInput(resolutionNote: ' '),
        );
        expect(
          bare!.messages,
          containsAll(<String>[
            'Add at least one after-repair photo.',
            'Add a resolution note.',
          ]),
        );

        final DetailActionResult? ok = await n.run(
          ManageAction.resolve,
          seenStatus: ComplaintStatus.inProgress,
          input: ManageInput(
            resolutionNote: 'Replaced the breaker.',
            afterPhotos: <Attachment>[
              Attachment(
                id: 'after-test-1',
                kind: AttachmentKind.afterPhoto,
                ref: 'assets/samples/after_sample_1.jpg',
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );
        expect(ok!.ok, isTrue);
        final Complaint c = await stored(container, inProgressElectrical);
        expect(c.status, ComplaintStatus.resolved);
        expect(c.resolutionNote, 'Replaced the breaker.');
        expect(c.afterPhotos, hasLength(1));
      },
    );
  });

  group('DetailActionNotifier: priority (AC-54)', () {
    test('the override changes the effective priority, not the computed '
        'one, and clears again', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final Complaint before = await stored(container, reportedPlumbing);
      expect(before.priorityOverride, isNull);
      final DetailActionNotifier n = runner(container, reportedPlumbing);

      expect(
        (await n.run(
          ManageAction.setPriorityOverride,
          seenStatus: ComplaintStatus.reported,
          input: const ManageInput(priorityOverride: Priority.critical),
        ))!.ok,
        isTrue,
      );
      final Complaint set = await stored(container, reportedPlumbing);
      expect(set.effectivePriority, Priority.critical);
      expect(set.priority, before.priority, reason: 'computed is untouched');
      expect(set.timeline, before.timeline, reason: 'no event');

      // The public feeds (A-02 / A-03) carry the effective priority.
      final List<PublicComplaintView> all = await settled(
        container,
        allComplaintsProvider,
      );
      expect(
        all.firstWhere((v) => v.id == reportedPlumbing).effectivePriority,
        Priority.critical,
      );

      expect(
        (await n.run(
          ManageAction.setPriorityOverride,
          seenStatus: ComplaintStatus.reported,
        ))!.ok,
        isTrue,
        reason: 'no priority in the input clears the override',
      );
      final Complaint cleared = await stored(container, reportedPlumbing);
      expect(cleared.priorityOverride, isNull);
      expect(cleared.effectivePriority, before.priority);
    });

    test(
      'the safety flag recomputes the priority, only while unresolved',
      () async {
        final ProviderContainer container = await signedIn(UserRole.admin);
        final Complaint before = await stored(container, reportedPlumbing);
        final DetailActionNotifier n = runner(container, reportedPlumbing);

        expect(
          (await n.run(
            ManageAction.toggleSafetyFlag,
            seenStatus: ComplaintStatus.reported,
          ))!.ok,
          isTrue,
        );
        final Complaint flagged = await stored(container, reportedPlumbing);
        expect(flagged.safetyFlag, isTrue);
        expect(
          flagged.priority.weight,
          greaterThanOrEqualTo(Priority.high.weight),
        );

        expect(
          (await n.run(
            ManageAction.toggleSafetyFlag,
            seenStatus: ComplaintStatus.reported,
          ))!.ok,
          isTrue,
        );
        final Complaint unflagged = await stored(container, reportedPlumbing);
        expect(unflagged.safetyFlag, isFalse);
        expect(unflagged.priority, before.priority);

        final DetailActionResult? late = await runner(container, resolvedIt)
            .run(
              ManageAction.toggleSafetyFlag,
              seenStatus: ComplaintStatus.resolved,
            );
        expect(late!.ok, isFalse);
        expect(
          late.messages,
          contains('The safety flag cannot change once the repair is done.'),
        );
      },
    );
  });

  group('DetailActionNotifier: stale, missing, in flight, failure', () {
    test('a complaint that changed since the screen drew it is stale (P8) '
        'and nothing is applied', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);
      final Complaint before = await stored(container, resolvedIt);
      // The screen believes `resolved`, but another admin already verified it.
      await container
          .read(complaintRepositoryProvider)
          .update(before.copyWith(status: ComplaintStatus.verified));
      final Complaint changed = await stored(container, resolvedIt);

      final DetailActionResult? r = await runner(
        container,
        resolvedIt,
      ).run(ManageAction.verify, seenStatus: ComplaintStatus.resolved);
      expect(r!.outcome, DetailActionOutcome.stale);
      expect(
        r.messages,
        contains('This complaint changed; refresh and retry.'),
      );
      expect(await stored(container, resolvedIt), changed);
    });

    test('an unknown id is blocked, not thrown', () async {
      final ProviderContainer container = await signedIn(UserRole.admin);
      final DetailActionResult? r = await runner(
        container,
        'CF-9999-00000',
      ).run(ManageAction.close, seenStatus: ComplaintStatus.verified);
      expect(r!.outcome, DetailActionOutcome.blocked);
      expect(r.messages, <String>["We couldn't find that complaint."]);
    });

    test('a second action while one is in flight is ignored (no double '
        'submit)', () async {
      final ProviderContainer container = await signedIn(UserRole.verifier);
      final DetailActionNotifier n = runner(container, resolvedIt);

      final Future<DetailActionResult?> first = n.run(
        ManageAction.verify,
        seenStatus: ComplaintStatus.resolved,
      );
      expect(
        container
            .read(detailActionProvider(resolvedIt))
            .isRunning(ManageAction.verify),
        isTrue,
      );
      expect(container.read(detailActionProvider(resolvedIt)).busy, isTrue);
      final DetailActionResult? second = await n.run(
        ManageAction.verify,
        seenStatus: ComplaintStatus.resolved,
      );
      expect(second, isNull);

      expect((await first)!.ok, isTrue);
      expect(container.read(detailActionProvider(resolvedIt)).busy, isFalse);
      // Exactly one verify event was written.
      final Complaint c = await stored(container, resolvedIt);
      expect(
        c.timeline.where((e) => e.status == ComplaintStatus.verified),
        hasLength(1),
      );
    });

    test('a failed write is a "couldn\'t" result and leaves nothing half '
        'done', () async {
      final ProviderContainer container = await signedIn(
        UserRole.verifier,
        overrides: <Override>[
          complaintRepositoryProvider.overrideWith((ref) => _FailingWrites()),
        ],
      );
      final DetailActionResult? r = await runner(
        container,
        resolvedIt,
      ).run(ManageAction.verify, seenStatus: ComplaintStatus.resolved);
      expect(r!.outcome, DetailActionOutcome.failed);
      expect(r.messages.single, startsWith("We couldn't verify the repair."));
      expect(container.read(detailActionProvider(resolvedIt)).busy, isFalse);
      expect(
        (await stored(container, resolvedIt)).status,
        ComplaintStatus.resolved,
      );
    });
  });
}
