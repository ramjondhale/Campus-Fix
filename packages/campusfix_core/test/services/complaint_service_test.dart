// ComplaintService (S2.7): submit, the L3 transition executor and its
// invariants - status-machine-spec §1-§7, priority-engine-spec §6,
// assignment-routing-spec §3-§6 and the carry-overs of the run ledger.
import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import 'service_harness.dart';

/// INV-1..INV-5 and TL-1..TL-7 (status-machine-spec §7) over any complaint
/// the service produced.
void expectInvariants(Complaint c) {
  final reason = c.id;
  if (c.status.order >= ComplaintStatus.assigned.order) {
    expect(c.assignment, isNotNull, reason: 'INV-1 $reason');
  }
  if (c.status == ComplaintStatus.reviewed) {
    expect(routeToDepartment(c.category), isNull, reason: 'INV-2 $reason');
  }
  if (c.status.order >= ComplaintStatus.resolved.order) {
    expect(
      c.afterPhotos.where((p) => p.kind == AttachmentKind.afterPhoto),
      isNotEmpty,
      reason: 'INV-3 photo $reason',
    );
    expect(c.resolutionNote?.trim(), isNotEmpty, reason: 'INV-3 note $reason');
  }
  final assignment = c.assignment;
  if (assignment != null) {
    expect(
      assignment.isManual,
      isManualAssignment(c.category, assignment.department),
      reason: 'isManual is derived $reason',
    );
  }

  final tl = c.timeline;
  expect(tl.first.status, ComplaintStatus.reported, reason: 'TL-1 $reason');
  expect(tl.first.actorRole, UserRole.reporter, reason: 'TL-1 $reason');
  expect(tl.first.at, c.createdAt, reason: 'TL-1 $reason');
  for (var i = 1; i < tl.length; i++) {
    final prev = tl[i - 1];
    final next = tl[i];
    expect(next.at.isBefore(prev.at), isFalse, reason: 'TL-2 $reason event $i');
    if (next.status != prev.status) {
      expect(
        StatusMachine.canTransition(prev.status, next.status, next.actorRole),
        isTrue,
        reason: 'TL-3 $reason ${prev.status.name}->${next.status.name}',
      );
    }
    final backward =
        (prev.status == ComplaintStatus.resolved &&
            next.status == ComplaintStatus.inProgress) ||
        (prev.status == ComplaintStatus.inProgress &&
            next.status == ComplaintStatus.assigned);
    if (backward) {
      expect(next.note?.trim(), isNotEmpty, reason: 'TL-7 $reason event $i');
    }
    if (next.status.order < prev.status.order) {
      expect(backward, isTrue, reason: 'TL-6 $reason event $i');
    }
  }
  expect(tl.last.status, c.status, reason: 'TL-4 $reason');
  expect(c.updatedAt, tl.last.at, reason: 'TL-4 $reason');
  if (c.status == ComplaintStatus.closed) {
    final order = [for (final e in tl) e.status];
    final r = order.lastIndexOf(ComplaintStatus.resolved);
    final v = order.indexOf(ComplaintStatus.verified);
    final cl = order.indexOf(ComplaintStatus.closed);
    expect(r, greaterThanOrEqualTo(0), reason: 'TL-5 $reason');
    expect(v, greaterThan(r), reason: 'TL-5 $reason');
    expect(cl, greaterThan(v), reason: 'TL-5 $reason');
  }
}

/// A repository that stores the draft under a different id, like the Firebase
/// one (the Complaint ID comes from a server-side counter).
class _RekeyingComplaintRepository extends MockComplaintRepository {
  _RekeyingComplaintRepository(this.newId);

  final String newId;

  @override
  Future<Complaint> submit(Complaint draft) => super.submit(
    draft.copyWith(
      id: newId,
      timeline: [
        for (var i = 0; i < draft.timeline.length; i++)
          draft.timeline[i].copyWith(
            id: 'ev-$newId-${(i + 1).toString().padLeft(2, '0')}',
          ),
      ],
    ),
  );
}

void main() {
  late Harness h;
  setUp(() => h = Harness());

  group('submit', () {
    test(
      'produces a valid reported complaint with priority and TL-1',
      () async {
        final c = await h.submit(
          category: ProblemCategory.electrical,
          severity: Severity.moderate,
          people: PeopleAffected.small,
        );

        expect(c.id, matches(complaintIdPattern));
        expect(c.id, 'CF-2026-00001');
        expect(c.status, ComplaintStatus.reported);
        expect(c.assignment, isNull);
        expect(c.priorityOverride, isNull);
        expect(c.resolutionNote, isNull);
        expect(c.afterPhotos, isEmpty);
        expect(c.beforePhotos, hasLength(1));
        expect(c.createdAt, t0);
        expect(c.updatedAt, t0);
        // electrical 15 + moderate 20 + small 10 = 45 => High, no aging.
        expect(
          c.priority,
          computePriority(
            const PriorityInputs(
              category: ProblemCategory.electrical,
              safetyFlag: false,
              severity: Severity.moderate,
              peopleAffected: PeopleAffected.small,
            ),
          ),
        );
        expect(c.priority, Priority.high);

        expect(c.timeline, hasLength(1));
        expect(
          c.timeline.single,
          StatusEvent(
            id: 'ev-CF-2026-00001-01',
            status: ComplaintStatus.reported,
            actorId: h.reporterUser.id,
            actorRole: UserRole.reporter,
            at: t0,
          ),
        );
        expectInvariants(c);
        expect(await h.complaints.byId(c.id), c);
      },
    );

    test('ids continue per year and restart in a new year', () async {
      final a = await h.submit();
      final b = await h.submit();
      final c = await h.submit(now: DateTime.utc(2027, 1, 2));
      expect(
        [a.id, b.id, c.id],
        ['CF-2026-00001', 'CF-2026-00002', 'CF-2027-00001'],
      );
    });

    test('the safety category forces the safety flag', () async {
      final c = await h.submit(
        category: ProblemCategory.safety,
        severity: Severity.minor,
        people: PeopleAffected.individual,
      );
      expect(c.safetyFlag, isTrue);
      expect(c.priority, Priority.high); // floor: never below High
      final severe = await h.submit(
        category: ProblemCategory.safety,
        severity: Severity.severe,
      );
      expect(severe.priority, Priority.critical);
    });

    test('an explicit safety flag raises the priority', () async {
      final plain = await h.submit(
        category: ProblemCategory.furniture,
        severity: Severity.minor,
        people: PeopleAffected.individual,
      );
      final flagged = await h.submit(
        category: ProblemCategory.furniture,
        severity: Severity.minor,
        people: PeopleAffected.individual,
        safetyFlag: true,
      );
      expect(plain.priority, Priority.low);
      expect(flagged.safetyFlag, isTrue);
      expect(flagged.priority, Priority.high);
    });

    test(
      'emits submission notifications to the owner and the admins',
      () async {
        final c = await h.submit();
        final all = await h.allNotifications();
        expect(all, hasLength(2));

        final owner = (await h.inbox(h.reporterUser)).single;
        expect(owner.type, NotificationType.submission);
        expect(owner.title, 'Complaint submitted');
        expect(owner.body, 'Complaint ${c.id} submitted.');
        expect(owner.complaintId, c.id);
        expect(owner.read, isFalse);
        expect(owner.createdAt, t0);

        final admin = (await h.inbox(h.admin)).single;
        expect(admin.type, NotificationType.submission);
        expect(
          admin.body,
          'New High complaint ${c.id} — Electrical, Science Block.',
        );

        expect(await h.inbox(h.verifier), isEmpty);
        for (final d in Department.values) {
          for (final s in h.staffOf(d)) {
            expect(await h.inbox(s), isEmpty);
          }
        }
      },
    );

    test('builds the submission notifications from the persisted complaint '
        '(a repository that re-keys the draft)', () async {
      // The Firebase repository replaces the local id (and the TL-1 event id)
      // with the counter-allocated Complaint ID inside `submit`: the
      // notifications must carry the stored id, not the draft's.
      final service = ComplaintService(
        complaints: _RekeyingComplaintRepository('CF-2026-00777'),
        notifications: h.notifications,
        users: h.users,
        ids: ComplaintIdGenerator(),
        clock: () => t0,
      );

      final saved = await service.submit(
        reporter: h.identityOf(h.reporterUser),
        category: ProblemCategory.electrical,
        description: 'The problem is clearly visible near the entrance.',
        building: 'Science Block',
        floor: '2',
        room: 'Lab 204',
        severity: Severity.moderate,
        peopleAffected: PeopleAffected.small,
        now: t0,
      );

      expect(saved.id, 'CF-2026-00777');
      expect(saved.timeline.single.id, 'ev-CF-2026-00777-01');
      final all = await h.allNotifications();
      expect(all, hasLength(2));
      for (final n in all) {
        expect(n.complaintId, 'CF-2026-00777');
        expect(n.id, startsWith('ntf-ev-CF-2026-00777-01-'));
        expect(n.body, contains('CF-2026-00777'));
        expect(n.body, isNot(contains('CF-2026-00001')));
      }
      expect(
        {for (final n in all) n.recipientId},
        {h.reporterUser.id, h.admin.id},
      );
    });

    test('rejects blank text and non-before photos; stores nothing', () async {
      Future<void> bad({String description = 'ok text', String room = 'R1'}) =>
          h.service.submit(
            reporter: h.identityOf(h.reporterUser),
            category: ProblemCategory.civil,
            description: description,
            building: 'Block A',
            floor: '1',
            room: room,
            severity: Severity.minor,
            peopleAffected: PeopleAffected.individual,
            now: t0,
          );
      await expectLater(bad(description: '   '), throwsArgumentError);
      await expectLater(bad(room: ''), throwsArgumentError);
      await expectLater(
        h.service.submit(
          reporter: h.identityOf(h.reporterUser),
          category: ProblemCategory.civil,
          description: 'ok text',
          building: 'Block A',
          floor: '1',
          room: 'R1',
          beforePhotos: [h.afterPhoto('x', t0)],
          severity: Severity.minor,
          peopleAffected: PeopleAffected.individual,
          now: t0,
        ),
        throwsArgumentError,
      );
      expect(await h.complaints.all(), isEmpty);
      expect(await h.allNotifications(), isEmpty);
    });

    test('trims text and drops a blank title', () async {
      final c = await h.service.submit(
        reporter: h.identityOf(h.reporterUser),
        category: ProblemCategory.civil,
        title: '   ',
        description: '  Crack in the wall  ',
        building: ' Block A ',
        floor: ' 1 ',
        room: ' R1 ',
        severity: Severity.minor,
        peopleAffected: PeopleAffected.individual,
        now: t0,
      );
      expect(c.title, isNull);
      expect(c.description, 'Crack in the wall');
      expect([c.building, c.floor, c.room], ['Block A', '1', 'R1']);
    });
  });

  group('T1 / T2 Review & Route', () {
    test(
      'T1 alone for a safety complaint: verifier review stops at reviewed',
      () async {
        final c = await h.submit(category: ProblemCategory.safety);
        final r = await h.service.reviewAndRoute(
          c,
          h.verifier,
          note: '  Looks genuine ',
          now: at(hours(1)),
        );

        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.reviewed);
        expect(u.assignment, isNull); // W4
        expect(u.updatedAt, at(hours(1)));
        expect(r.events, hasLength(1));
        expect(
          r.events.single,
          StatusEvent(
            id: 'ev-${c.id}-02',
            status: ComplaintStatus.reviewed,
            actorId: h.verifier.id,
            actorRole: UserRole.verifier,
            note: 'Looks genuine',
            at: at(hours(1)),
          ),
        );
        expect(u.timeline.map((e) => e.status), [
          ComplaintStatus.reported,
          ComplaintStatus.reviewed,
        ]);
        // §5.1: the reporter only.
        expect(r.notifications, hasLength(1));
        expect(r.notifications.single.recipientId, h.reporterUser.id);
        expect(r.notifications.single.body, '${c.id} has been reviewed.');
        expect(r.notifications.single.type, NotificationType.statusChange);
        expectInvariants(u);
      },
    );

    test('T1 recomputes the priority with the aged waiting time', () async {
      final c = await h.submit(
        category: ProblemCategory.other,
        severity: Severity.minor,
        people: PeopleAffected.small,
      );
      expect(c.priority, Priority.low); // 0 + 10 + 10 = 20
      final u = await h.ok(
        h.service.reviewAndRoute(c, h.verifier, now: at(hours(25))),
      );
      expect(u.status, ComplaintStatus.reviewed);
      expect(u.priority, Priority.medium); // + 5 aging = 25
    });

    test(
      'W1: a verifier review auto-routes (T1 + T2, same actor, same at)',
      () async {
        final c = await h.submit(category: ProblemCategory.electrical);
        final r = await h.service.reviewAndRoute(
          c,
          h.verifier,
          now: at(hours(1)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;

        expect(u.status, ComplaintStatus.assigned);
        expect(
          u.assignment,
          Assignment(
            department: Department.electrician,
            assigneeId: null,
            assignedBy: h.verifier.id,
            assignedAt: at(hours(1)),
            isManual: false,
          ),
        );
        expect(u.timeline.map((e) => e.status), [
          ComplaintStatus.reported,
          ComplaintStatus.reviewed,
          ComplaintStatus.assigned,
        ]);
        final reviewed = u.timeline[1];
        final assigned = u.timeline[2];
        expect(assigned.note, 'Auto-routed to Electrician');
        expect(assigned.at, reviewed.at);
        expect(assigned.actorId, reviewed.actorId);
        expect(assigned.actorRole, UserRole.verifier);
        expect(r.events, [reviewed, assigned]);
        expect(u.updatedAt, at(hours(1)));

        // Owner: reviewed + assigned. Department: new work for both staff.
        final bodies = r.notifications.map((n) => n.body).toList();
        expect(bodies, hasLength(4));
        expect(bodies, contains('${c.id} has been reviewed.'));
        expect(bodies, contains('${c.id} assigned to Electrician.'));
        final work =
            'New work: ${c.id} — Electrical, Science Block, Floor 2, Lab 204.';
        expect(bodies.where((b) => b == work), hasLength(2));
        expect(
          {for (final n in r.notifications) n.recipientId},
          {
            h.reporterUser.id,
            for (final s in h.staffOf(Department.electrician)) s.id,
          },
        );
        expectInvariants(u);
      },
    );

    test('W2: an admin may route to another department (manual)', () async {
      final c = await h.submit(category: ProblemCategory.plumbing);
      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.admin,
          department: Department.carpenter,
          now: at(hours(1)),
        ),
      );
      expect(u.assignment!.department, Department.carpenter);
      expect(u.assignment!.isManual, isTrue);
      expect(u.assignment!.assignedBy, h.admin.id);
      expect(u.timeline.last.note, 'Assigned to Carpenter');
      expectInvariants(u);
    });

    test('W3: an admin choosing the router department is not manual', () async {
      final c = await h.submit(category: ProblemCategory.plumbing);
      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.admin,
          department: Department.plumber,
          now: at(hours(1)),
        ),
      );
      expect(u.assignment!.isManual, isFalse);
      expect(u.timeline.last.note, 'Auto-routed to Plumber');
    });

    test(
      'isManual, assignedBy and assignedAt are derived, never trusted',
      () async {
        final c = await h.submit(category: ProblemCategory.plumbing);
        // An admin whose request lies about everything.
        final lying = Assignment(
          department: Department.plumber,
          assignedBy: 'someone-else',
          assignedAt: DateTime.utc(2000),
          isManual: true,
        );
        final u = await h.ok(
          h.service.apply(
            c,
            ComplaintStatus.reviewed,
            h.admin,
            TransitionRequest(
              expectedFrom: ComplaintStatus.reported,
              assignment: lying,
            ),
            now: at(hours(1)),
          ),
        );
        expect(u.assignment!.isManual, isFalse);
        expect(u.assignment!.assignedBy, h.admin.id);
        expect(u.assignment!.assignedAt, at(hours(1)));

        // A verifier claiming "not manual" for a custom department is caught.
        final c2 = await h.submit(category: ProblemCategory.plumbing);
        final r = await h.service.apply(
          c2,
          ComplaintStatus.reviewed,
          h.verifier,
          TransitionRequest(
            expectedFrom: ComplaintStatus.reported,
            assignment: Assignment(
              department: Department.carpenter,
              assignedBy: h.verifier.id,
              assignedAt: at(hours(1)),
              isManual: false,
            ),
          ),
          now: at(hours(1)),
        );
        expect(r.ok, isFalse);
        expect(r.codes, contains('P5'));
      },
    );

    test('N11: a verifier cannot route manually; nothing changes', () async {
      final c = await h.submit(category: ProblemCategory.plumbing);
      final before = await h.allNotifications();
      final r = await h.service.reviewAndRoute(
        c,
        h.verifier,
        department: Department.carpenter,
        now: at(hours(1)),
      );
      expect(r.ok, isFalse);
      expect(r.codes, ['P5']);
      expect(r.complaint, isNull);
      expect(r.events, isEmpty);
      expect(r.notifications, isEmpty);
      expect(await h.stored(c.id), c);
      expect(await h.allNotifications(), before);
    });

    test('W5 / N12: a verifier cannot assign a safety complaint', () async {
      final c = await h.submit(category: ProblemCategory.safety);
      final reviewed = await h.routed(c);
      expect(reviewed.status, ComplaintStatus.reviewed);

      final r = await h.service.assign(
        reviewed,
        h.verifier,
        department: Department.civilMaintenance,
        now: at(hours(2)),
      );
      expect(r.ok, isFalse);
      expect(r.codes, contains('P5'));
      expect(await h.stored(c.id), reviewed);

      // Even a request claiming the assignment is not manual.
      final lie = await h.service.apply(
        reviewed,
        ComplaintStatus.assigned,
        h.verifier,
        TransitionRequest(
          expectedFrom: ComplaintStatus.reviewed,
          assignment: Assignment(
            department: Department.civilMaintenance,
            assignedBy: h.verifier.id,
            assignedAt: at(hours(2)),
            isManual: false,
          ),
        ),
        now: at(hours(2)),
      );
      expect(lie.codes, contains('P5'));
    });

    test('W6: an admin assigns a reviewed safety complaint (T2)', () async {
      final c = await h.submit(category: ProblemCategory.safety);
      final reviewed = await h.routed(c);
      final r = await h.service.assign(
        reviewed,
        h.admin,
        department: Department.civilMaintenance,
        now: at(hours(2)),
      );
      expect(r.ok, isTrue, reason: '${r.codes}');
      final u = r.complaint!;
      expect(u.status, ComplaintStatus.assigned);
      expect(u.assignment!.isManual, isTrue);
      expect(u.assignment!.department, Department.civilMaintenance);
      expect(u.timeline.last.note, 'Assigned to Civil Maintenance');
      expect(r.events, hasLength(1));
      expect(
        {for (final n in r.notifications) n.recipientId},
        {
          h.reporterUser.id,
          for (final s in h.staffOf(Department.civilMaintenance)) s.id,
        },
      );
      expectInvariants(u);
    });

    test('an admin may route a safety complaint during review', () async {
      final c = await h.submit(category: ProblemCategory.safety);
      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.admin,
          department: Department.electrician,
          now: at(hours(1)),
        ),
      );
      expect(u.status, ComplaintStatus.assigned);
      expect(u.assignment!.isManual, isTrue);
      expectInvariants(u);
    });

    test('the reviewer note belongs to the reviewed event only', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.verifier,
          note: 'Checked on site',
          now: at(hours(1)),
        ),
      );
      expect(u.timeline[1].note, 'Checked on site');
      expect(u.timeline[2].note, 'Auto-routed to Electrician');
    });

    test(
      'only a verifier or admin can review (L1); reporters and staff not',
      () async {
        final c = await h.submit();
        for (final actor in [h.reporterUser, h.staff(Department.electrician)]) {
          final r = await h.service.reviewAndRoute(c, actor, now: at(hours(1)));
          expect(r.ok, isFalse, reason: actor.role.name);
          expect(r.codes, contains('L1'));
        }
        expect(await h.stored(c.id), c);
      },
    );

    test(
      'admin override and safety flag at review; verifiers cannot',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.individual,
        );
        expect(c.priority, Priority.low);

        // A verifier supplying the override or the flag is rejected, not
        // silently ignored, and nothing changes.
        final vOverride = await h.service.reviewAndRoute(
          c,
          h.verifier,
          priorityOverride: Priority.critical,
          now: at(hours(1)),
        );
        expect(vOverride.codes, ['PO']);
        final vFlag = await h.service.reviewAndRoute(
          c,
          h.verifier,
          safetyFlag: true,
          now: at(hours(1)),
        );
        expect(vFlag.codes, ['SF']);
        expect(await h.stored(c.id), c);

        final u = await h.ok(
          h.service.reviewAndRoute(
            c,
            h.admin,
            priorityOverride: Priority.low,
            safetyFlag: true,
            now: at(hours(1)),
          ),
        );
        expect(u.safetyFlag, isTrue);
        expect(u.priority, Priority.high); // floor from the flag
        expect(u.priorityOverride, Priority.low);
        expect(u.effectivePriority, Priority.low);
      },
    );

    test(
      'an admin may attach an override to any transition; others may not',
      () async {
        final assigned = await h.routed(await h.submit());
        final denied = await h.service.apply(
          assigned,
          ComplaintStatus.inProgress,
          h.staff(Department.electrician),
          const TransitionRequest(
            expectedFrom: ComplaintStatus.assigned,
            priorityOverride: Priority.low,
          ),
          now: at(hours(2)),
        );
        expect(denied.codes, ['PO']);
        expect(await h.stored(assigned.id), assigned);

        final u = await h.ok(
          h.service.apply(
            assigned,
            ComplaintStatus.inProgress,
            h.admin,
            const TransitionRequest(
              expectedFrom: ComplaintStatus.assigned,
              priorityOverride: Priority.low,
            ),
            now: at(hours(2)),
          ),
        );
        expect(u.priorityOverride, Priority.low);
      },
    );

    test('only an admin may name a specific assignee (MA-3, MA-7)', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      final pick = h.staff(Department.electrician, 2);
      final r = await h.service.reviewAndRoute(
        c,
        h.verifier,
        assigneeId: pick.id,
        now: at(hours(1)),
      );
      expect(r.codes, ['P5']);
      expect(await h.stored(c.id), c);

      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.admin,
          assigneeId: pick.id,
          now: at(hours(1)),
        ),
      );
      expect(u.assignment!.assigneeId, pick.id);
      expect(u.assignment!.isManual, isFalse); // the router's own department
    });

    test(
      'a priority override is never touched by recomputation (PC-2)',
      () async {
        final c = await h.submit(category: ProblemCategory.furniture);
        var u = await h.ok(
          h.service.reviewAndRoute(
            c,
            h.admin,
            priorityOverride: Priority.critical,
            now: at(hours(1)),
          ),
        );
        expect(u.priorityOverride, Priority.critical);
        u = await h.started(u);
        u = h.service.refreshAging(u, at(const Duration(days: 20)));
        expect(u.priorityOverride, Priority.critical);
      },
    );

    test('N13: a stale expectedFrom is rejected (P8)', () async {
      final c = await h.submit();
      final r = await h.service.apply(
        c,
        ComplaintStatus.reviewed,
        h.verifier,
        const TransitionRequest(expectedFrom: ComplaintStatus.assigned),
        now: at(hours(1)),
      );
      expect(r.ok, isFalse);
      expect(r.codes, contains('P8'));
      expect(await h.stored(c.id), c);
    });

    test(
      'a note over 500 chars is rejected (P9) and nothing changes',
      () async {
        final c = await h.submit();
        final r = await h.service.reviewAndRoute(
          c,
          h.verifier,
          note: 'x' * 501,
          now: at(hours(1)),
        );
        expect(r.codes, ['P9']);
        expect(await h.stored(c.id), c);
      },
    );

    test('an unknown complaint is blocked, not thrown', () async {
      final ghost = (await h.submit()).copyWith(id: 'CF-2026-09999');
      final r = await h.service.reviewAndRoute(ghost, h.verifier);
      expect(r.ok, isFalse);
      expect(r.codes, ['NF']);
    });
  });

  group('T3 start work', () {
    test(
      'the department member claims the work; the priority is recomputed',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.small,
        );
        final assigned = await h.routed(c);
        expect(assigned.priority, Priority.low);

        final worker = h.staff(Department.carpenter, 2);
        final r = await h.service.startWork(
          assigned,
          worker,
          note: 'On my way',
          now: at(hours(30)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.inProgress);
        expect(u.assignment!.assigneeId, worker.id); // CL-1 claim
        expect(u.assignment!.department, Department.carpenter);
        expect(u.priority, Priority.medium); // 20 + 5 aging after 30 h
        expect(u.timeline.last.actorId, worker.id);
        expect(u.timeline.last.actorRole, UserRole.maintenance);
        expect(u.timeline.last.note, 'On my way');
        expect(u.updatedAt, at(hours(30)));
        expect(r.notifications, hasLength(1));
        expect(r.notifications.single.recipientId, h.reporterUser.id);
        expect(r.notifications.single.body, 'Work has started on ${c.id}.');
        expectInvariants(u);
      },
    );

    test(
      'an admin starting on behalf leaves the assignee empty (CL-3)',
      () async {
        final assigned = await h.routed(await h.submit());
        final u = await h.ok(
          h.service.startWork(assigned, h.admin, now: at(hours(2))),
        );
        expect(u.status, ComplaintStatus.inProgress);
        expect(u.assignment!.assigneeId, isNull);
      },
    );

    test('N9: staff of another department are rejected (P6)', () async {
      final assigned = await h.routed(await h.submit()); // electrician
      final r = await h.service.startWork(
        assigned,
        h.staff(Department.plumber),
        now: at(hours(2)),
      );
      expect(r.codes, contains('P6'));
      expect(await h.stored(assigned.id), assigned);
    });

    test('N10: a colleague cannot take claimed work (P7)', () async {
      final started = await h.started(await h.submit());
      final claimedBy = started.assignment!.assigneeId;
      expect(claimedBy, h.staff(Department.electrician).id);

      // The claimant may not "start" again (status), but a colleague trying
      // to resolve is rejected on P7.
      final r = await h.service.resolve(
        started,
        h.staff(Department.electrician, 2),
        resolutionNote: 'Fixed',
        afterPhotos: [h.afterPhoto('a', at(hours(3)))],
        now: at(hours(3)),
      );
      expect(r.codes, contains('P7'));
    });

    test(
      'a double tap and a race between colleagues apply exactly once',
      () async {
        final assigned = await h.routed(await h.submit());
        final worker = h.staff(Department.electrician);
        final peer = h.staff(Department.electrician, 2);

        final taps = await Future.wait([
          h.service.startWork(assigned, worker, now: at(hours(2))),
          h.service.startWork(assigned, worker, now: at(hours(2))),
        ]);
        expect(taps.where((r) => r.ok), hasLength(1));
        final loser = taps.firstWhere((r) => !r.ok);
        expect(loser.codes, contains('P8'));

        final other = await h.routed(await h.submit());
        final race = await Future.wait([
          h.service.startWork(other, worker, now: at(hours(2))),
          h.service.startWork(other, peer, now: at(hours(2))),
        ]);
        expect(race.where((r) => r.ok), hasLength(1));
        expect(
          (await h.stored(
            other.id,
          )).timeline.where((e) => e.status == ComplaintStatus.inProgress),
          hasLength(1),
        );
      },
    );
  });

  group('T4 resolve', () {
    Future<Complaint> inProgress({
      ProblemCategory category = ProblemCategory.furniture,
    }) async => h.started(
      await h.submit(
        category: category,
        severity: Severity.minor,
        people: PeopleAffected.small,
      ),
    );

    test(
      'stores proof, freezes priority, notifies the owner and verifiers',
      () async {
        final working = await inProgress(); // started at +2 h => Low
        expect(working.priority, Priority.low);
        final worker = h.staff(Department.carpenter);
        final photo = h.afterPhoto('att-after-1', at(hours(100)));

        final r = await h.service.resolve(
          working,
          worker,
          resolutionNote: '  Replaced the hinge.  ',
          afterPhotos: [photo],
          now: at(hours(100)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.resolved);
        expect(u.resolutionNote, 'Replaced the hinge.');
        expect(u.afterPhotos, [photo]);
        expect(u.timeline.last.note, 'Replaced the hinge.'); // copied
        // INV-5: frozen. 100 h of waiting would have been Medium.
        expect(u.priority, Priority.low);
        expect(u.assignment!.assigneeId, worker.id);
        expect(u.updatedAt, at(hours(100)));

        expect(r.notifications.map((n) => n.recipientId).toSet(), {
          h.reporterUser.id,
          h.verifier.id,
          h.verifier2.id,
          h.admin.id, // "Verifiers" = every verifier and admin (§5.1)
        });
        final owner = r.notifications.firstWhere(
          (n) => n.recipientId == h.reporterUser.id,
        );
        expect(owner.type, NotificationType.completion);
        expect(
          owner.body,
          'Repair completed on ${u.id}; awaiting verification.',
        );
        final verifier = r.notifications.firstWhere(
          (n) => n.recipientId == h.verifier.id,
        );
        expect(verifier.body, '${u.id} is ready to verify.');
        expectInvariants(u);
      },
    );

    test('an admin resolving on behalf needs the same proof; the staff '
        'member who resolves later claims it', () async {
      final assigned = await h.routed(
        await h.submit(category: ProblemCategory.furniture),
      );
      final working = await h.ok(
        h.service.startWork(assigned, h.admin, now: at(hours(2))),
      );
      final worker = h.staff(Department.carpenter, 2);
      final u = await h.ok(
        h.service.resolve(
          working,
          worker,
          resolutionNote: 'Done',
          afterPhotos: [h.afterPhoto('a1', at(hours(3)))],
          now: at(hours(3)),
        ),
      );
      expect(u.assignment!.assigneeId, worker.id); // CL-3
    });

    test('N1: no after photo is rejected (P1)', () async {
      final working = await inProgress();
      final r = await h.service.resolve(
        working,
        h.staff(Department.carpenter),
        resolutionNote: 'Done',
        afterPhotos: const [],
        now: at(hours(3)),
      );
      expect(r.codes, ['P1']);
      expect(await h.stored(working.id), working);
    });

    test('N2: photos of the wrong kind do not count (P1)', () async {
      final working = await inProgress();
      final r = await h.service.resolve(
        working,
        h.staff(Department.carpenter),
        resolutionNote: 'Done',
        afterPhotos: [
          h.afterPhoto('b', at(hours(3)), kind: AttachmentKind.beforePhoto),
        ],
        now: at(hours(3)),
      );
      expect(r.codes, ['P1']);
    });

    test('only afterPhoto attachments are stored', () async {
      final working = await inProgress();
      final good = h.afterPhoto('good', at(hours(3)));
      final u = await h.ok(
        h.service.resolve(
          working,
          h.staff(Department.carpenter),
          resolutionNote: 'Done',
          afterPhotos: [
            good,
            h.afterPhoto('other', at(hours(3)), kind: AttachmentKind.other),
            good, // duplicate id
          ],
          now: at(hours(3)),
        ),
      );
      expect(u.afterPhotos, [good]);
    });

    test('N3: a blank resolution note is rejected (P2)', () async {
      final working = await inProgress();
      final r = await h.service.resolve(
        working,
        h.staff(Department.carpenter),
        resolutionNote: '   ',
        afterPhotos: [h.afterPhoto('a', at(hours(3)))],
        now: at(hours(3)),
      );
      expect(r.codes, ['P2']);
    });

    test('N5: a 501-char resolution note is rejected (P2/P9)', () async {
      final working = await inProgress();
      final r = await h.service.resolve(
        working,
        h.staff(Department.carpenter),
        resolutionNote: 'n' * 501,
        afterPhotos: [h.afterPhoto('a', at(hours(3)))],
        now: at(hours(3)),
      );
      expect(r.codes, containsAll(['P2', 'P9']));
      expect(await h.stored(working.id), working);
    });

    test('only maintenance and admin may resolve (L1)', () async {
      final working = await inProgress();
      final r = await h.service.resolve(
        working,
        h.verifier,
        resolutionNote: 'Done',
        afterPhotos: [h.afterPhoto('a', at(hours(3)))],
        now: at(hours(3)),
      );
      expect(r.codes, contains('L1'));
    });
  });

  group('T5 verify / T6 close', () {
    test(
      'T5 verifies but does not close; owner and department are told',
      () async {
        final done = await h.resolved(
          await h.submit(category: ProblemCategory.furniture),
        );
        final r = await h.service.verify(
          done,
          h.verifier,
          note: 'Looks good',
          now: at(hours(4)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.verified); // not closed
        expect(r.events, hasLength(1));
        expect(u.timeline.last.note, 'Looks good');
        expect(u.priority, done.priority); // frozen
        expect(u.afterPhotos, done.afterPhotos);
        expect(u.resolutionNote, done.resolutionNote);
        expect(
          {for (final n in r.notifications) n.recipientId},
          {
            h.reporterUser.id,
            for (final s in h.staffOf(Department.carpenter)) s.id,
          },
        );
        expect(
          r.notifications.every((n) => n.body == '${u.id} repair verified.'),
          isTrue,
        );
        expectInvariants(u);
      },
    );

    test('N6: corrupt data (proof cleared) cannot be verified', () async {
      final done = await h.resolved(await h.submit());
      await h.complaints.update(
        done.copyWith(afterPhotos: const [], clearResolutionNote: true),
      );
      final r = await h.service.verify(done, h.verifier, now: at(hours(4)));
      expect(r.codes, containsAll(['P1', 'P2']));
    });

    test('T6 closes: only the owner is told; terminal', () async {
      final v = await h.verified(await h.submit());
      final r = await h.service.close(v, h.admin, now: at(hours(5)));
      expect(r.ok, isTrue, reason: '${r.codes}');
      final u = r.complaint!;
      expect(u.status, ComplaintStatus.closed);
      expect(u.status.isTerminal, isTrue);
      expect(r.notifications, hasLength(1));
      expect(r.notifications.single.recipientId, h.reporterUser.id);
      expect(r.notifications.single.type, NotificationType.closure);
      expect(r.notifications.single.body, '${u.id} is closed.');
      expectInvariants(u);
    });

    test('a verifier may also close; staff and reporters may not', () async {
      final v = await h.verified(await h.submit());
      for (final actor in [h.reporterUser, h.staff(Department.electrician)]) {
        final r = await h.service.close(v, actor, now: at(hours(5)));
        expect(r.codes, contains('L1'), reason: actor.role.name);
      }
      final closed = await h.ok(
        h.service.close(v, h.verifier, now: at(hours(5))),
      );
      expect(closed.status, ComplaintStatus.closed);
    });

    test(
      'verify skipping resolve, and close skipping verify, are illegal',
      () async {
        final working = await h.started(await h.submit());
        expect(
          (await h.service.verify(working, h.admin)).codes,
          contains('L1'),
        );
        final done = await h.resolved(await h.submit());
        expect((await h.service.close(done, h.admin)).codes, contains('L1'));
      },
    );
  });

  group('T7 reject', () {
    test('requires a reason (P3)', () async {
      final done = await h.resolved(await h.submit());
      for (final note in ['', '   ', 'n' * 501]) {
        final r = await h.service.reject(
          done,
          h.verifier,
          note: note,
          now: at(hours(4)),
        );
        expect(r.ok, isFalse, reason: 'note length ${note.length}');
        expect(r.codes, contains('P3'));
      }
      expect(await h.stored(done.id), done);
    });

    test(
      'unfreezes and recomputes priority; keeps history; notifies',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.small,
        );
        // Resolved after 100 h, but the priority froze at the last recompute.
        final done = await h.resolved(c, now: at(hours(100)));
        expect(done.priority, Priority.low);

        final r = await h.service.reject(
          done,
          h.verifier2,
          note: 'The hinge is still loose',
          now: at(hours(200)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.inProgress);
        // INV-5 unfreeze: 200 h of waiting => 20 + 15 = 35 => Medium.
        expect(u.priority, Priority.medium);
        expect(u.afterPhotos, done.afterPhotos);
        expect(u.resolutionNote, done.resolutionNote);
        expect(u.assignment, done.assignment);
        expect(u.timeline.last.status, ComplaintStatus.inProgress);
        expect(u.timeline.last.actorRole, UserRole.verifier);
        expect(u.timeline.last.note, 'The hinge is still loose');

        final byRecipient = {for (final n in r.notifications) n.recipientId: n};
        expect(byRecipient.keys.toSet(), {
          h.reporterUser.id,
          for (final s in h.staffOf(Department.carpenter)) s.id,
        });
        expect(
          byRecipient[h.staff(Department.carpenter).id]!.body,
          'Rework needed on ${u.id}: The hinge is still loose.',
        );
        expect(
          byRecipient[h.reporterUser.id]!.body,
          '${u.id} needs more work; work resumed.',
        );
        expectInvariants(u);
      },
    );

    test('N4: after a reject only fresh evidence counts (P1)', () async {
      final done = await h.resolved(await h.submit(), now: at(hours(3)));
      final rework = await h.ok(
        h.service.reject(done, h.verifier, note: 'Redo it', now: at(hours(10))),
      );
      final worker = h.staff(done.assignment!.department);

      // The only after photo predates the reject.
      final stale = await h.service.resolve(
        rework,
        worker,
        resolutionNote: 'Trying again',
        afterPhotos: const [],
        now: at(hours(11)),
      );
      expect(stale.codes, ['P1']);

      final fresh = await h.ok(
        h.service.resolve(
          rework,
          worker,
          resolutionNote: 'Redone properly',
          afterPhotos: [h.afterPhoto('att-fresh', at(hours(12)))],
          now: at(hours(12)),
        ),
      );
      expect(fresh.status, ComplaintStatus.resolved);
      expect(fresh.afterPhotos, hasLength(2)); // history retained
      expect(fresh.resolutionNote, 'Redone properly');
      expectInvariants(fresh);
    });

    test('a staff member cannot reject (L1)', () async {
      final done = await h.resolved(await h.submit());
      final r = await h.service.reject(
        done,
        h.staff(done.assignment!.department),
        note: 'No',
      );
      expect(r.codes, contains('L1'));
    });
  });

  group('T8 pull-back and reassignment', () {
    test('W12: an admin pulls an in-progress complaint back (T8)', () async {
      final c = await h.submit(
        category: ProblemCategory.civil,
        severity: Severity.minor,
        people: PeopleAffected.small,
      );
      final working = await h.started(c);
      expect(working.assignment!.assigneeId, isNotNull);

      final r = await h.service.reassign(
        working,
        h.admin,
        department: Department.electrician,
        reason: 'It is a wiring problem',
        now: at(hours(30)),
      );
      expect(r.ok, isTrue, reason: '${r.codes}');
      final u = r.complaint!;
      expect(u.status, ComplaintStatus.assigned);
      expect(u.assignment!.department, Department.electrician);
      expect(u.assignment!.assigneeId, isNull);
      expect(u.assignment!.isManual, isTrue); // civil routes to civil
      expect(u.assignment!.assignedBy, h.admin.id);
      expect(u.assignment!.assignedAt, at(hours(30)));
      expect(u.timeline.last.status, ComplaintStatus.assigned);
      expect(u.timeline.last.note, 'It is a wiring problem');
      expect(u.timeline.last.actorRole, UserRole.admin);
      expect(u.priority, Priority.medium); // recomputed: 20 + 10 + 5 aging...
      expect(u.afterPhotos, isEmpty);

      final byRecipient = {
        for (final n in r.notifications) n.recipientId: n.body,
      };
      expect(
        byRecipient[h.reporterUser.id],
        '${u.id} reassigned to Electrician.',
      );
      for (final s in h.staffOf(Department.civilMaintenance)) {
        expect(byRecipient[s.id], '${u.id} removed from your queue.');
      }
      for (final s in h.staffOf(Department.electrician)) {
        expect(
          byRecipient[s.id],
          'New work: ${u.id} — Civil / Building, Science Block, Floor 2, '
          'Lab 204.',
        );
      }
      expect(byRecipient, hasLength(5));
      expectInvariants(u);

      // The new team starts from `assigned` and can claim.
      final restarted = await h.ok(
        h.service.startWork(
          u,
          h.staff(Department.electrician, 2),
          now: at(hours(31)),
        ),
      );
      expect(
        restarted.assignment!.assigneeId,
        h.staff(Department.electrician, 2).id,
      );
      expectInvariants(restarted);
    });

    test('N8 / W14: a reason and a real change are required', () async {
      final working = await h.started(await h.submit());
      final noReason = await h.service.reassign(
        working,
        h.admin,
        department: Department.itTeam,
        reason: ' ',
      );
      expect(noReason.codes, contains('P3'));
      final noChange = await h.service.reassign(
        working,
        h.admin,
        department: Department.electrician,
        assigneeId: working.assignment!.assigneeId,
        reason: 'No-op',
      );
      expect(noChange.codes, contains('P4'));
      expect(await h.stored(working.id), working);
    });

    test('I13: only an admin may reassign (L1)', () async {
      final working = await h.started(await h.submit());
      for (final actor in [h.verifier, h.staff(Department.electrician)]) {
        final r = await h.service.reassign(
          working,
          actor,
          department: Department.itTeam,
          reason: 'Because',
        );
        expect(r.ok, isFalse, reason: actor.role.name);
        expect(r.codes, contains('L1'));
      }
    });

    test(
      'W11: reassigning while assigned appends an annotation event',
      () async {
        final assigned = await h.routed(await h.submit());
        final r = await h.service.reassign(
          assigned,
          h.admin,
          department: Department.itTeam,
          reason: 'Network fault',
          now: at(hours(2)),
        );
        expect(r.ok, isTrue, reason: '${r.codes}');
        final u = r.complaint!;
        expect(u.status, ComplaintStatus.assigned); // unchanged
        expect(u.assignment!.department, Department.itTeam);
        expect(u.assignment!.assigneeId, isNull);
        expect(u.assignment!.isManual, isTrue);
        expect(u.timeline, hasLength(assigned.timeline.length + 1));
        expect(u.timeline.last.status, ComplaintStatus.assigned);
        expect(u.timeline.last.actorRole, UserRole.admin);
        expect(
          u.timeline.last.note,
          'Reassigned: Electrician -> IT Team — Network fault',
        );
        expect(u.updatedAt, at(hours(2)));
        expect(r.events, [u.timeline.last]);
        expect(
          {for (final n in r.notifications) n.recipientId},
          {
            h.reporterUser.id,
            for (final s in h.staffOf(Department.electrician)) s.id,
            for (final s in h.staffOf(Department.itTeam)) s.id,
          },
        );
        expectInvariants(u);
      },
    );

    test('the annotation checks P3, P4 and the admin role', () async {
      final assigned = await h.routed(await h.submit());
      final stale = await h.service.reassign(
        assigned,
        h.admin,
        department: Department.electrician, // unchanged
        reason: 'Same',
      );
      expect(stale.codes, contains('P4'));
      final blank = await h.service.reassign(
        assigned,
        h.admin,
        department: Department.itTeam,
        reason: '',
      );
      expect(blank.codes, contains('P3'));
      final verifier = await h.service.reassign(
        assigned,
        h.verifier,
        department: Department.itTeam,
        reason: 'Because',
      );
      expect(verifier.codes, contains('L1'));
      expect(await h.stored(assigned.id), assigned);
    });

    test(
      'an assignee change within the department is a reassignment',
      () async {
        final assigned = await h.routed(await h.submit());
        final pick = h.staff(Department.electrician, 2);
        final u = await h.ok(
          h.service.reassign(
            assigned,
            h.admin,
            department: Department.electrician,
            assigneeId: pick.id,
            reason: 'Specialist',
            now: at(hours(2)),
          ),
        );
        expect(u.assignment!.assigneeId, pick.id);
        expect(u.assignment!.isManual, isFalse);
        // The other colleague is now blocked (P7) and the pick can start.
        final blocked = await h.service.startWork(
          u,
          h.staff(Department.electrician),
          now: at(hours(3)),
        );
        expect(blocked.codes, contains('P7'));
        final ok = await h.service.startWork(u, pick, now: at(hours(3)));
        expect(ok.ok, isTrue);
      },
    );

    test(
      'W13: resolved, verified, reported and reviewed cannot be reassigned',
      () async {
        final reported = await h.submit(category: ProblemCategory.safety);
        final reviewed = await h.routed(
          await h.submit(category: ProblemCategory.safety),
        );
        final resolved = await h.resolved(await h.submit());
        final verified = await h.verified(await h.submit());
        for (final c in [reported, reviewed, resolved, verified]) {
          final r = await h.service.reassign(
            c,
            h.admin,
            department: Department.itTeam,
            reason: 'Move it',
          );
          expect(r.ok, isFalse, reason: c.status.name);
          expect(r.codes, ['RA2'], reason: c.status.name);
          expect(await h.stored(c.id), c);
        }
      },
    );
  });

  group('P4 directory check (N15)', () {
    test('review: an invalid assignee blocks the whole composite', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      final before = await h.allNotifications();
      final invalid = <String, String>{
        'a verifier': h.verifier.id,
        'a reporter': h.reporterUser.id,
        'another department': h.staff(Department.plumber).id,
        'a missing user': 'u-nobody',
      };
      for (final entry in invalid.entries) {
        final r = await h.service.reviewAndRoute(
          c,
          h.admin,
          assigneeId: entry.value,
          now: at(hours(1)),
        );
        expect(r.ok, isFalse, reason: entry.key);
        expect(r.codes, ['P4'], reason: entry.key);
        expect(r.messages, ['Assignee not in that department.']);
        // Atomic: not even the review was applied.
        expect(await h.stored(c.id), c, reason: entry.key);
      }
      expect(await h.allNotifications(), before);
    });

    test(
      'W7: assigning an IT staff member of the chosen department works',
      () async {
        final c = await h.submit(category: ProblemCategory.other);
        final it = h.staff(Department.itTeam, 2);

        // The assignee must be in the department being assigned.
        final wrong = await h.service.reviewAndRoute(
          c,
          h.admin,
          department: Department.itTeam,
          assigneeId: h.staff(Department.electrician).id,
          now: at(hours(1)),
        );
        expect(wrong.codes, ['P4']);

        final u = await h.ok(
          h.service.reviewAndRoute(
            c,
            h.admin,
            department: Department.itTeam,
            assigneeId: it.id,
            now: at(hours(1)),
          ),
        );
        expect(u.status, ComplaintStatus.assigned);
        expect(u.assignment!.assigneeId, it.id);
        expect(u.assignment!.isManual, isTrue); // `other` has no route
        expectInvariants(u);
      },
    );

    test('T2 via assign() and T8 via reassign() are checked too', () async {
      final reviewed = await h.routed(
        await h.submit(category: ProblemCategory.safety),
      );
      final badAssign = await h.service.assign(
        reviewed,
        h.admin,
        department: Department.civilMaintenance,
        assigneeId: h.verifier.id,
        now: at(hours(2)),
      );
      expect(badAssign.codes, contains('P4'));
      expect(await h.stored(reviewed.id), reviewed);

      final working = await h.started(await h.submit());
      final badMove = await h.service.reassign(
        working,
        h.admin,
        department: Department.itTeam,
        assigneeId: h.staff(Department.plumber).id,
        reason: 'Needs IT',
        now: at(hours(5)),
      );
      expect(badMove.codes, contains('P4'));
      expect(await h.stored(working.id), working);

      final goodMove = await h.service.reassign(
        working,
        h.admin,
        department: Department.itTeam,
        assigneeId: h.staff(Department.itTeam).id,
        reason: 'Needs IT',
        now: at(hours(5)),
      );
      expect(goodMove.ok, isTrue, reason: '${goodMove.codes}');
      expect(
        goodMove.complaint!.assignment!.assigneeId,
        h.staff(Department.itTeam).id,
      );
    });
  });

  group('atomicity', () {
    test('Review & Route whose second step fails leaves no trace', () async {
      final c = await h.submit(category: ProblemCategory.plumbing);
      final complaintsBefore = await h.complaints.all();
      final notificationsBefore = await h.allNotifications();

      // T1 is valid for a verifier; T2 (manual department) is not.
      final r = await h.service.reviewAndRoute(
        c,
        h.verifier,
        note: 'Reviewed',
        department: Department.carpenter,
        now: at(hours(1)),
      );
      expect(r.ok, isFalse);
      expect(r.codes, ['P5']);
      expect(r.events, isEmpty);
      expect(r.notifications, isEmpty);
      expect(await h.complaints.all(), complaintsBefore);
      expect(await h.allNotifications(), notificationsBefore);
      final stored = await h.stored(c.id);
      expect(stored.status, ComplaintStatus.reported);
      expect(stored.timeline, hasLength(1));
      expect(stored.assignment, isNull);

      // The very same complaint can still be reviewed correctly.
      final u = await h.ok(h.service.reviewAndRoute(c, h.verifier));
      expect(u.status, ComplaintStatus.assigned);
    });

    test('a failing step emits no partial notifications', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      final before = (await h.allNotifications()).length;
      final r = await h.service.reviewAndRoute(
        c,
        h.admin,
        department: Department.electrician,
        assigneeId: 'u-nobody',
        now: at(hours(1)),
      );
      expect(r.ok, isFalse);
      expect((await h.allNotifications()).length, before);
    });

    test('a successful composite persists once with both events', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      final r = await h.service.reviewAndRoute(
        c,
        h.verifier,
        now: at(hours(1)),
      );
      expect(r.events, hasLength(2));
      expect(await h.stored(c.id), r.complaint);
    });
  });

  group('INV-4: a closed complaint is immutable', () {
    late Complaint closed;
    late List<Complaint> snapshot;
    late List<AppNotification> notified;

    setUp(() async {
      closed = await h.closed(await h.submit());
      snapshot = await h.complaints.all();
      notified = await h.allNotifications();
    });

    tearDown(() async {
      expect(await h.complaints.all(), snapshot, reason: 'nothing persisted');
      expect(await h.allNotifications(), notified, reason: 'nothing emitted');
    });

    test('no transition to any status, for any role', () async {
      for (final actor in [
        h.reporterUser,
        h.staff(Department.electrician),
        h.verifier,
        h.admin,
      ]) {
        for (final to in ComplaintStatus.values) {
          final r = await h.service.apply(
            closed,
            to,
            actor,
            TransitionRequest(
              expectedFrom: ComplaintStatus.closed,
              note: 'again',
              resolutionNote: 'again',
              afterPhotos: [h.afterPhoto('x', at(hours(9)))],
              assignment: Assignment(
                department: Department.itTeam,
                assignedBy: actor.id,
                assignedAt: at(hours(9)),
                isManual: true,
              ),
            ),
            now: at(hours(9)),
          );
          expect(r.ok, isFalse, reason: '${actor.role.name} -> ${to.name}');
          expect(r.codes, contains('P8'));
        }
      }
    });

    test('the convenience actions are all blocked', () async {
      final results = [
        await h.service.reviewAndRoute(closed, h.admin),
        await h.service.assign(closed, h.admin, department: Department.itTeam),
        await h.service.startWork(closed, h.admin),
        await h.service.resolve(
          closed,
          h.admin,
          resolutionNote: 'x',
          afterPhotos: [h.afterPhoto('y', at(hours(9)))],
        ),
        await h.service.verify(closed, h.admin),
        await h.service.close(closed, h.admin),
        await h.service.reject(closed, h.admin, note: 'x'),
        await h.service.reassign(
          closed,
          h.admin,
          department: Department.itTeam,
          reason: 'x',
        ),
      ];
      for (final r in results) {
        expect(r.ok, isFalse);
      }
    });

    test('priority override and safety flag edits are blocked (N14)', () async {
      final override = await h.service.setPriorityOverride(
        closed,
        h.admin,
        Priority.critical,
      );
      expect(override.ok, isFalse);
      expect(override.codes, ['P8']);
      final flag = await h.service.setSafetyFlag(closed, h.admin, true);
      expect(flag.ok, isFalse);
      expect(flag.codes, ['P8']);
    });

    test(
      'a stale snapshot cannot sneak a change past a closed complaint',
      () async {
        // Close from a `verified` snapshot, then retry with the same snapshot.
        final verified = await h.verified(await h.submit());
        await h.ok(h.service.close(verified, h.admin, now: at(hours(5))));
        final again = await h.service.close(
          verified,
          h.admin,
          now: at(hours(6)),
        );
        expect(again.ok, isFalse);
        expect(again.codes, contains('P8'));
        // `tearDown` compares against the snapshot taken before this test; the
        // extra complaint above only exists in this test, so restore it.
        snapshot = await h.complaints.all();
        notified = await h.allNotifications();
      },
    );

    test('aging never touches a closed complaint', () {
      expect(
        h.service.refreshAging(closed, at(const Duration(days: 60))),
        closed,
      );
    });
  });

  group('INV-5: priority freeze and unfreeze', () {
    test(
      'frozen from resolved to closed; refreshAging is a no-op there',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.small,
        );
        final working = await h.started(c); // last recompute at +2 h => Low
        final far = at(const Duration(days: 30));
        expect(h.service.refreshAging(working, far).priority, Priority.high);

        final done = await h.resolved(working, now: at(hours(100)));
        final verified = await h.verified(done, now: at(hours(101)));
        final closed = await h.closed(verified, now: at(hours(102)));
        for (final s in [done, verified, closed]) {
          expect(s.priority, Priority.low, reason: s.status.name);
          expect(h.service.refreshAging(s, far), s, reason: s.status.name);
        }
      },
    );

    test('refreshAging recomputes unresolved complaints only', () async {
      final c = await h.submit(
        category: ProblemCategory.furniture,
        severity: Severity.minor,
        people: PeopleAffected.small,
      );
      expect(c.priority, Priority.low);
      final far = at(const Duration(days: 15));

      final aged = h.service.refreshAging(c, far);
      expect(aged.priority, Priority.high); // 20 + 25
      expect(aged.updatedAt, c.updatedAt); // TL-4 untouched
      expect(aged.copyWith(priority: c.priority), c);
      // Not yet aged: same instance.
      expect(h.service.refreshAging(c, at(hours(1))), same(c));

      for (final status in [
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
      ]) {
        expect(
          h.service.refreshAging(c.copyWith(status: status), far).priority,
          Priority.high,
          reason: status.name,
        );
      }
      for (final status in [
        ComplaintStatus.resolved,
        ComplaintStatus.verified,
        ComplaintStatus.closed,
      ]) {
        final frozen = c.copyWith(status: status);
        expect(
          h.service.refreshAging(frozen, far),
          frozen,
          reason: status.name,
        );
      }
    });

    test(
      'refreshAndPersist stores a changed priority and nothing else',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.small,
        );
        final far = at(const Duration(days: 15));
        final stored = await h.service.refreshAndPersist(c, now: far);
        expect(stored.priority, Priority.high);
        expect(await h.stored(c.id), stored);
        expect(stored.copyWith(priority: c.priority), c);

        // Unchanged => returned as stored.
        expect(await h.service.refreshAndPersist(c, now: far), stored);
        // A frozen complaint is returned untouched.
        final done = await h.resolved(
          await h.submit(category: ProblemCategory.furniture),
        );
        expect(await h.service.refreshAndPersist(done, now: far), done);
      },
    );

    test('the admin priority override survives and wins', () async {
      final c = await h.submit(category: ProblemCategory.furniture);
      final set = await h.service.setPriorityOverride(c, h.admin, Priority.low);
      expect(set.ok, isTrue);
      expect(set.complaint!.priorityOverride, Priority.low);
      expect(set.complaint!.effectivePriority, Priority.low);
      expect(set.complaint!.priority, c.priority); // PC-2
      expect(set.complaint!.updatedAt, c.updatedAt);
      expect(set.events, isEmpty);

      final aged = h.service.refreshAging(
        set.complaint!,
        at(const Duration(days: 20)),
      );
      expect(aged.priorityOverride, Priority.low);

      final cleared = await h.service.setPriorityOverride(
        set.complaint!,
        h.admin,
        null,
      );
      expect(cleared.complaint!.priorityOverride, isNull);
    });

    test('only an admin may set or clear the override (PC-1)', () async {
      final c = await h.submit();
      for (final actor in [
        h.reporterUser,
        h.staff(Department.electrician),
        h.verifier,
      ]) {
        final r = await h.service.setPriorityOverride(c, actor, Priority.low);
        expect(r.codes, ['PO'], reason: actor.role.name);
      }
      expect(await h.stored(c.id), c);
    });

    test(
      'the safety flag recomputes immediately; admin only; before resolved',
      () async {
        final c = await h.submit(
          category: ProblemCategory.furniture,
          severity: Severity.minor,
          people: PeopleAffected.individual,
        );
        expect(c.priority, Priority.low);

        final denied = await h.service.setSafetyFlag(c, h.verifier, true);
        expect(denied.codes, ['SF']);

        final on = await h.service.setSafetyFlag(
          c,
          h.admin,
          true,
          now: at(hours(1)),
        );
        expect(on.complaint!.safetyFlag, isTrue);
        expect(on.complaint!.priority, Priority.high);
        expect(on.complaint!.updatedAt, c.updatedAt);
        final off = await h.service.setSafetyFlag(
          on.complaint!,
          h.admin,
          false,
        );
        expect(off.complaint!.priority, Priority.low);

        final safety = await h.submit(category: ProblemCategory.safety);
        expect((await h.service.setSafetyFlag(safety, h.admin, false)).codes, [
          'SF',
        ]);

        final done = await h.resolved(await h.submit());
        expect((await h.service.setSafetyFlag(done, h.admin, true)).codes, [
          'SF',
        ]);
      },
    );
  });

  group('lifecycle replays (§8)', () {
    test('happy path reported -> ... -> closed (verifier verifies, admin '
        'closes)', () async {
      final c = await h.submit(category: ProblemCategory.electrical);
      var u = await h.routed(c);
      expectInvariants(u);
      u = await h.ok(
        h.service.startWork(
          u,
          h.staff(Department.electrician),
          now: at(hours(2)),
        ),
      );
      expectInvariants(u);
      u = await h.resolved(u);
      expectInvariants(u);
      u = await h.ok(h.service.verify(u, h.verifier, now: at(hours(4))));
      expect(u.status, ComplaintStatus.verified);
      expectInvariants(u);
      u = await h.ok(h.service.close(u, h.admin, now: at(hours(5))));
      expectInvariants(u);

      expect(u.timeline.map((e) => e.status), [
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
        ComplaintStatus.resolved,
        ComplaintStatus.verified,
        ComplaintStatus.closed,
      ]);
      expect(await h.stored(c.id), u);
    });

    test(
      'reject loop: resolved -> inProgress -> resolved -> verified -> closed',
      () async {
        var u = await h.resolved(await h.submit(), now: at(hours(3)));
        u = await h.ok(
          h.service.reject(u, h.verifier, note: 'Redo', now: at(hours(4))),
        );
        expectInvariants(u);
        u = await h.ok(
          h.service.resolve(
            u,
            h.staff(u.assignment!.department),
            resolutionNote: 'Redone',
            afterPhotos: [h.afterPhoto('att-redo', at(hours(5)))],
            now: at(hours(5)),
          ),
        );
        expectInvariants(u);
        u = await h.closed(u, now: at(hours(7)));
        expectInvariants(u);
      },
    );

    test('pull-back: inProgress -> assigned -> inProgress with a new '
        'department', () async {
      var u = await h.started(await h.submit());
      u = await h.ok(
        h.service.reassign(
          u,
          h.admin,
          department: Department.plumber,
          reason: 'A pipe, not a wire',
          now: at(hours(3)),
        ),
      );
      expect(u.status, ComplaintStatus.assigned);
      u = await h.ok(
        h.service.startWork(u, h.staff(Department.plumber), now: at(hours(4))),
      );
      u = await h.resolved(u, now: at(hours(5)));
      u = await h.closed(u, now: at(hours(7)));
      expectInvariants(u);
      expect(u.assignment!.department, Department.plumber);
    });

    test('manual triage: a safety complaint waits in reviewed until an admin '
        'assigns', () async {
      var u = await h.routed(await h.submit(category: ProblemCategory.safety));
      expect(u.status, ComplaintStatus.reviewed);
      expectInvariants(u);
      u = await h.ok(
        h.service.assign(
          u,
          h.admin,
          department: Department.civilMaintenance,
          now: at(hours(2)),
        ),
      );
      u = await h.closed(u, now: at(hours(8)));
      expectInvariants(u);
    });

    test('event ids are unique and the timeline is append-only', () async {
      final u = await h.closed(await h.submit());
      final ids = [for (final e in u.timeline) e.id];
      expect(ids.toSet(), hasLength(ids.length));
      final mid = await h.complaints.byId(u.id);
      expect(mid!.timeline.take(3), u.timeline.take(3));
    });

    test('a clock earlier than the last event is clamped (TL-2)', () async {
      final c = await h.submit();
      final u = await h.ok(
        h.service.reviewAndRoute(
          c,
          h.verifier,
          now: at(const Duration(hours: -5)),
        ),
      );
      expect(u.timeline.last.at, c.createdAt);
      expectInvariants(u);
    });
  });

  group('privacy of generated notifications', () {
    test('no notification of a full lifecycle carries identity', () async {
      final identity = h.identityOf(h.reporterUser, phone: '+91 90000 11001');
      final fragments = identityFragments(h.seed, identity);
      expect(fragments.length, greaterThan(50)); // anti-vacuity

      final c = await h.submit(category: ProblemCategory.plumbing);
      var u = await h.routed(c);
      u = await h.ok(
        h.service.startWork(u, h.staff(Department.plumber), now: at(hours(2))),
      );
      u = await h.resolved(u, now: at(hours(3)));
      u = await h.ok(
        h.service.reject(
          u,
          h.verifier,
          note: 'Water still leaks near the tap',
          now: at(hours(4)),
        ),
      );
      u = await h.ok(
        h.service.reassign(
          u,
          h.admin,
          department: Department.civilMaintenance,
          reason: 'Wall damage',
          now: at(hours(5)),
        ),
      );
      u = await h.closed(
        await h
            .ok(
              h.service.startWork(
                u,
                h.staff(Department.civilMaintenance),
                now: at(hours(6)),
              ),
            )
            .then((w) => h.resolved(w, now: at(hours(7)))),
        now: at(hours(9)),
      );
      expect(u.status, ComplaintStatus.closed);

      final all = await h.allNotifications();
      expect(all.length, greaterThan(20));
      for (final n in all) {
        expect(
          leaks('${n.title}\n${n.body}', fragments),
          isEmpty,
          reason: '${n.id}: ${n.body}',
        );
      }
    });
  });
}
