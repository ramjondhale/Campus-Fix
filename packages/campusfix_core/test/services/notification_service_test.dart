// NotificationService / NotificationTemplates (S2.7): triggers, recipient sets
// and the canonical PII-free templates - status-machine-spec §5.1,
// privacy-spec LK-1.
import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../logic/privacy_test.dart'
    show
        adminActorId,
        buildFixtureComplaint,
        leaksIn,
        sentinelFragments,
        staffId,
        staffUser;
import 'service_harness.dart';

/// The notifying (from, to) pairs and their trigger (§5.1).
const _notifying = <(ComplaintStatus, ComplaintStatus), NotificationTrigger>{
  (ComplaintStatus.reported, ComplaintStatus.reviewed):
      NotificationTrigger.reviewed,
  (ComplaintStatus.reviewed, ComplaintStatus.assigned):
      NotificationTrigger.assigned,
  (ComplaintStatus.assigned, ComplaintStatus.inProgress):
      NotificationTrigger.started,
  (ComplaintStatus.inProgress, ComplaintStatus.resolved):
      NotificationTrigger.resolved,
  (ComplaintStatus.resolved, ComplaintStatus.verified):
      NotificationTrigger.verified,
  (ComplaintStatus.verified, ComplaintStatus.closed):
      NotificationTrigger.closed,
  (ComplaintStatus.resolved, ComplaintStatus.inProgress):
      NotificationTrigger.rejected,
  (ComplaintStatus.inProgress, ComplaintStatus.assigned):
      NotificationTrigger.reassigned,
  (ComplaintStatus.assigned, ComplaintStatus.assigned):
      NotificationTrigger.reassigned,
};

void main() {
  late Harness h;
  setUp(() => h = Harness());

  /// [c] as it is after moving to [to] (with its assignment), and the event.
  Complaint after(
    Complaint c,
    ComplaintStatus to, {
    Department? department,
    String? note,
    String eventId = 'ev-test-1',
  }) {
    final event = StatusEvent(
      id: eventId,
      status: to,
      actorId: h.admin.id,
      actorRole: UserRole.admin,
      note: note,
      at: at(hours(5)),
    );
    return c.copyWith(
      status: to,
      assignment: Assignment(
        department: department ?? Department.electrician,
        assignedBy: h.admin.id,
        assignedAt: at(hours(1)),
        isManual: false,
      ),
      timeline: [...c.timeline, event],
      updatedAt: event.at,
    );
  }

  group('triggerFor', () {
    test('maps exactly the notifying status pairs', () {
      for (final from in ComplaintStatus.values) {
        for (final to in ComplaintStatus.values) {
          expect(
            NotificationTemplates.triggerFor(from, to),
            _notifying[(from, to)],
            reason: '${from.name} -> ${to.name}',
          );
        }
      }
    });

    test('creation is the only notifying event without a previous status', () {
      expect(
        NotificationTemplates.triggerFor(null, ComplaintStatus.reported),
        NotificationTrigger.submitted,
      );
      for (final to in ComplaintStatus.values.skip(1)) {
        expect(NotificationTemplates.triggerFor(null, to), isNull);
      }
    });

    test('every legal edge and the annotation event notifies', () {
      for (final from in ComplaintStatus.values) {
        for (final role in UserRole.values) {
          for (final to in StatusMachine.nextStatuses(from, role)) {
            expect(
              NotificationTemplates.triggerFor(from, to),
              isNotNull,
              reason: '${from.name} -> ${to.name}',
            );
          }
        }
      }
    });
  });

  group('templates (§5.1)', () {
    late Complaint c;
    setUp(() async => c = await h.submit(floor: 'Ground', room: 'Lab 204'));

    List<(NotificationAudience, NotificationType, String, String)> plan(
      NotificationTrigger t, {
      Department? dept = Department.electrician,
      Department? previous,
      String? note,
    }) => [
      for (final d in NotificationTemplates.plan(
        t,
        dept == null ? c : after(c, ComplaintStatus.assigned, department: dept),
        previousDepartment: previous,
        note: note,
      ))
        (d.audience, d.type, d.title, d.body),
    ];

    test('creation', () {
      expect(plan(NotificationTrigger.submitted, dept: null), [
        (
          NotificationAudience.owner,
          NotificationType.submission,
          'Complaint submitted',
          'Complaint CF-2026-00001 submitted.',
        ),
        (
          NotificationAudience.admins,
          NotificationType.submission,
          'New complaint',
          'New High complaint CF-2026-00001 — Electrical, Science Block.',
        ),
      ]);
    });

    test('T1 reviewed, T3 started, T6 closed', () {
      expect(
        plan(NotificationTrigger.reviewed).single.$4,
        'CF-2026-00001 has been reviewed.',
      );
      expect(
        plan(NotificationTrigger.started).single.$4,
        'Work has started on CF-2026-00001.',
      );
      expect(
        plan(NotificationTrigger.closed).single.$4,
        'CF-2026-00001 is closed.',
      );
      expect(
        plan(NotificationTrigger.closed).single.$2,
        NotificationType.closure,
      );
    });

    test('T2 assigned: owner and department', () {
      final p = plan(NotificationTrigger.assigned);
      expect(p, hasLength(2));
      expect(p[0].$1, NotificationAudience.owner);
      expect(p[0].$2, NotificationType.assignment);
      expect(p[0].$4, 'CF-2026-00001 assigned to Electrician.');
      expect(p[1].$1, NotificationAudience.department);
      expect(
        p[1].$4,
        'New work: CF-2026-00001 — Electrical, Science Block, Ground floor, '
        'Lab 204.',
      );
    });

    test('T4 resolved: owner and verifiers', () {
      final p = plan(NotificationTrigger.resolved);
      expect(p.map((e) => e.$1), [
        NotificationAudience.owner,
        NotificationAudience.verifiers,
      ]);
      expect(p[0].$2, NotificationType.completion);
      expect(
        p[0].$4,
        'Repair completed on CF-2026-00001; awaiting verification.',
      );
      expect(p[1].$4, 'CF-2026-00001 is ready to verify.');
    });

    test('T5 verified: owner and department', () {
      final p = plan(NotificationTrigger.verified);
      expect(p.map((e) => e.$1), [
        NotificationAudience.owner,
        NotificationAudience.department,
      ]);
      expect(p.map((e) => e.$4).toSet(), {'CF-2026-00001 repair verified.'});
    });

    test(
      'T7 rejected: department gets the note, owner is told work resumed',
      () {
        final p = plan(NotificationTrigger.rejected, note: 'Still leaking');
        expect(p.map((e) => e.$1), [
          NotificationAudience.department,
          NotificationAudience.owner,
        ]);
        expect(p[0].$4, 'Rework needed on CF-2026-00001: Still leaking.');
        expect(p[1].$4, 'CF-2026-00001 needs more work; work resumed.');
        // A note that already ends a sentence is not double-punctuated.
        expect(
          plan(NotificationTrigger.rejected, note: ' Redo it! ')[0].$4,
          'Rework needed on CF-2026-00001: Redo it!',
        );
        expect(
          plan(NotificationTrigger.rejected)[0].$4,
          'Rework needed on CF-2026-00001.',
        );
      },
    );

    test('T8 reassigned: owner, old department, new department', () {
      final p = plan(
        NotificationTrigger.reassigned,
        dept: Department.plumber,
        previous: Department.electrician,
      );
      expect(p.map((e) => e.$1), [
        NotificationAudience.owner,
        NotificationAudience.department,
        NotificationAudience.department,
      ]);
      expect(p[0].$4, 'CF-2026-00001 reassigned to Plumber.');
      expect(p[1].$4, 'CF-2026-00001 removed from your queue.');
      expect(p[2].$4, startsWith('New work: CF-2026-00001'));
      final departments = [
        for (final d in NotificationTemplates.plan(
          NotificationTrigger.reassigned,
          after(c, ComplaintStatus.assigned, department: Department.plumber),
          previousDepartment: Department.electrician,
        ))
          d.department,
      ];
      expect(departments, [null, Department.electrician, Department.plumber]);
    });

    test('a reassignment within one department does not "remove" it', () {
      final p = plan(
        NotificationTrigger.reassigned,
        previous: Department.electrician,
      );
      expect(p.map((e) => e.$3), ['Complaint reassigned', 'New work assigned']);
    });

    test('floor labels', () {
      String where(String floor) {
        final complaint = after(
          c.copyWith(floor: floor),
          ComplaintStatus.assigned,
        );
        return NotificationTemplates.plan(
          NotificationTrigger.assigned,
          complaint,
        ).last.body;
      }

      expect(where('2'), contains('Science Block, Floor 2, Lab 204'));
      expect(where('Ground'), contains('Science Block, Ground floor, Lab 204'));
      expect(where('Mezzanine'), contains('Science Block, Mezzanine, Lab 204'));
    });

    test('department messages are dropped when there is no department', () {
      expect(
        NotificationTemplates.plan(NotificationTrigger.assigned, c),
        isEmpty,
      );
      expect(
        NotificationTemplates.plan(
          NotificationTrigger.verified,
          c,
        ).map((d) => d.audience),
        [NotificationAudience.owner],
      );
    });
  });

  group('recipients (§5.1)', () {
    late Complaint c;
    setUp(() async => c = await h.submit());

    Set<String> ids(Iterable<AppUser> users) => {for (final u in users) u.id};

    Future<Set<String>> recipients(
      ComplaintStatus from,
      ComplaintStatus to, {
      Department? previous,
      Department? department,
    }) async {
      final before = c.copyWith(
        status: from,
        assignment: previous == null
            ? null
            : Assignment(
                department: previous,
                assignedBy: h.admin.id,
                assignedAt: at(hours(1)),
                isManual: false,
              ),
      );
      final built = await h.notifier.buildFor(
        before,
        after(before, to, department: department),
        after(before, to, department: department).timeline.last,
      );
      return {for (final n in built) n.recipientId};
    }

    test('creation: owner and every admin', () async {
      final built = await h.notifier.buildFor(null, c, c.timeline.first);
      expect(
        {for (final n in built) n.recipientId},
        {h.reporterUser.id, h.admin.id},
      );
    });

    test('T1, T3, T6: the owner only', () async {
      for (final (from, to) in [
        (ComplaintStatus.reported, ComplaintStatus.reviewed),
        (ComplaintStatus.assigned, ComplaintStatus.inProgress),
        (ComplaintStatus.verified, ComplaintStatus.closed),
      ]) {
        expect(await recipients(from, to), {h.reporterUser.id});
      }
    });

    test(
      'T2, T5, T7: owner and the staff of the assigned department',
      () async {
        final carpenters = ids(h.staffOf(Department.carpenter));
        for (final (from, to) in [
          (ComplaintStatus.reviewed, ComplaintStatus.assigned),
          (ComplaintStatus.resolved, ComplaintStatus.verified),
          (ComplaintStatus.resolved, ComplaintStatus.inProgress),
        ]) {
          expect(await recipients(from, to, department: Department.carpenter), {
            h.reporterUser.id,
            ...carpenters,
          });
        }
      },
    );

    test('T4: owner and all verifiers and admins, no staff', () async {
      expect(
        await recipients(ComplaintStatus.inProgress, ComplaintStatus.resolved),
        {h.reporterUser.id, h.verifier.id, h.verifier2.id, h.admin.id},
      );
    });

    test('T8: owner, old department staff and new department staff', () async {
      expect(
        await recipients(
          ComplaintStatus.inProgress,
          ComplaintStatus.assigned,
          previous: Department.civilMaintenance,
          department: Department.itTeam,
        ),
        {
          h.reporterUser.id,
          ...ids(h.staffOf(Department.civilMaintenance)),
          ...ids(h.staffOf(Department.itTeam)),
        },
      );
    });

    test('a same-department reassignment notifies the owner and the '
        'department once', () async {
      expect(
        await recipients(
          ComplaintStatus.assigned,
          ComplaintStatus.assigned,
          previous: Department.itTeam,
          department: Department.itTeam,
        ),
        {h.reporterUser.id, ...ids(h.staffOf(Department.itTeam))},
      );
    });

    test('nobody outside the audiences is notified', () async {
      final everyone = ids(h.seed.users);
      final notified = await recipients(
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
        department: Department.electrician,
      );
      expect(everyone.difference(notified), isNotEmpty);
      expect(notified.difference(everyone), isEmpty);
      expect(notified.contains(h.verifier.id), isFalse);
      expect(notified.contains(h.otherReporter.id), isFalse);
    });

    test(
      'a person in several audiences gets one notification (owner wins)',
      () async {
        // An admin who reported the complaint themselves.
        final own = await h.submit(reporter: h.admin);
        final mine = (await h.inbox(
          h.admin,
        )).where((n) => n.complaintId == own.id);
        expect(mine, hasLength(1));
        expect(mine.single.body, 'Complaint ${own.id} submitted.');
      },
    );

    test('pairs that are not notifying events produce nothing', () async {
      final closed = after(c, ComplaintStatus.closed);
      final stored = (await h.allNotifications()).length;
      final built = await h.notifier.buildFor(c, closed, closed.timeline.last);
      expect(built, isEmpty);
      expect(
        await h.notifier.emitFor(c, closed, closed.timeline.last),
        isEmpty,
      );
      expect(await h.allNotifications(), hasLength(stored));
    });
  });

  group('building and storing', () {
    late Complaint c;
    late Complaint a;
    setUp(() async {
      c = await h.submit();
      await h.notifications.markAllRead(h.reporterUser.id);
      a = after(c, ComplaintStatus.reviewed);
    });

    test(
      'buildFor is deterministic, stores nothing, and ids are stable',
      () async {
        final first = await h.notifier.buildFor(c, a, a.timeline.last);
        final second = await h.notifier.buildFor(c, a, a.timeline.last);
        expect(first, second);
        expect(first.single.id, 'ntf-ev-test-1-${h.reporterUser.id}');
        expect(first.single.createdAt, a.timeline.last.at);
        expect(first.single.complaintId, c.id);
        expect(first.single.read, isFalse);
        expect(first.single.type, NotificationType.statusChange);
        // Only the two creation notifications exist.
        expect(await h.allNotifications(), hasLength(2));
      },
    );

    test('emitFor stores what buildFor built', () async {
      final emitted = await h.notifier.emitFor(c, a, a.timeline.last);
      expect(emitted, await h.notifier.buildFor(c, a, a.timeline.last));
      expect(await h.allNotifications(), hasLength(3));
      expect(
        (await h.notifications.byRecipient(h.reporterUser.id)).map((n) => n.id),
        contains(emitted.single.id),
      );
    });

    test('emitSubmission notifies owner and admins', () async {
      // `submit` already emitted into `h`; use a separate inbox here.
      final inbox = MockNotificationRepository();
      final notifier = NotificationService(
        notifications: inbox,
        users: h.users,
      );
      final emitted = await notifier.emitSubmission(c);
      expect(
        {for (final n in emitted) n.recipientId},
        {h.reporterUser.id, h.admin.id},
      );
      expect(await inbox.all(), unorderedEquals(emitted));
      expect(
        emitted.every((n) => n.type == NotificationType.submission),
        isTrue,
      );
      // Emitting the same event twice is refused by the repository.
      await expectLater(notifier.emitSubmission(c), throwsStateError);
    });
  });

  group('serving notifications', () {
    late Complaint c;
    setUp(() async => c = await h.submit());

    test(
      'byRecipient is newest first; unreadCount, markRead, markAllRead',
      () async {
        final owner = h.reporterUser.id;
        expect(await h.notifier.unreadCount(owner), 1);

        final reviewed = after(c, ComplaintStatus.reviewed, eventId: 'ev-b');
        await h.notifier.emitFor(c, reviewed, reviewed.timeline.last);
        expect(await h.notifier.unreadCount(owner), 2);

        final list = await h.notifier.byRecipient(owner);
        expect(list.map((n) => n.title), [
          'Complaint reviewed',
          'Complaint submitted',
        ]);

        final read = await h.notifier.markRead(list.first.id);
        expect(read!.read, isTrue);
        expect(await h.notifier.unreadCount(owner), 1);
        expect(await h.notifier.markRead('ntf-missing'), isNull);

        await h.notifier.markAllRead(owner);
        expect(await h.notifier.unreadCount(owner), 0);
        // Other recipients are untouched.
        expect(await h.notifier.unreadCount(h.admin.id), 1);
      },
    );

    test('watchByRecipient emits now and on change', () async {
      final emissions = <List<AppNotification>>[];
      final sub = h.notifier
          .watchByRecipient(h.reporterUser.id)
          .listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.last, hasLength(1));

      final reviewed = after(c, ComplaintStatus.reviewed, eventId: 'ev-w');
      await h.notifier.emitFor(c, reviewed, reviewed.timeline.last);
      await pumpEventQueue();
      expect(emissions.last, hasLength(2));
      await sub.cancel();
    });
  });

  group('no PII in generated messages (LK-1 / PR-T15, sentinel scan)', () {
    const sentinelAdmin = AppUser(
      id: adminActorId,
      idNumber: 'ADM-SENT-9',
      displayName: 'Adminton Sentinelle',
      role: UserRole.admin,
      email: 'adminton.sentinelle@college.test',
    );
    final fragments = [
      ...sentinelFragments,
      'Adminton',
      'Sentinelle',
      'ADM-SENT-9',
      'adminton.sentinelle@college.test',
    ];

    test('every trigger, recipient and audience stays clean', () async {
      final users = MockUserRepository([
        ...h.seed.users.where((u) => u.role != UserRole.admin),
        staffUser,
        sentinelAdmin,
      ]);
      final notifier = NotificationService(
        notifications: MockNotificationRepository(),
        users: users,
      );

      var checked = 0;
      Future<void> scan(
        Complaint? before,
        Complaint to,
        StatusEvent event,
      ) async {
        final built = await notifier.buildFor(before, to, event);
        expect(built, isNotEmpty, reason: event.status.name);
        for (final n in built) {
          expect(
            leaksIn('${n.title}\n${n.body}', fragments),
            isEmpty,
            reason: '${event.status.name}: ${n.body}',
          );
          checked++;
        }
      }

      final c = buildFixtureComplaint(status: ComplaintStatus.reported);
      await scan(null, c, c.timeline.first);
      for (final (from, to) in _notifying.keys) {
        final prev = buildFixtureComplaint(status: from);
        final next = buildFixtureComplaint(status: to);
        final event = next.timeline.last.copyWith(note: 'Water still leaks');
        await scan(prev, next, event);
        // ... and with a different previous department.
        await scan(
          prev.copyWith(
            assignment: prev.assignment!.copyWith(
              department: Department.plumber,
            ),
          ),
          next,
          event,
        );
      }
      expect(checked, greaterThan(30)); // anti-vacuity

      // The fixture really does contain the identities being scanned for.
      expect(c.reporter.fullName, 'Zelda Quillfeather');
      expect(staffUser.id, staffId);
    });

    test('positive control: the scan would catch a leaky template', () {
      final c = buildFixtureComplaint(status: ComplaintStatus.reported);
      final leaky = 'Complaint ${c.id} by ${c.reporter.fullName} submitted.';
      expect(leaksIn(leaky, fragments), isNotEmpty);
      final leakyStaff = 'Assigned to ${staffUser.displayName}.';
      expect(leaksIn(leakyStaff, fragments), isNotEmpty);
    });

    test('messages are built from labels and ids only', () async {
      final c = await h.submit(category: ProblemCategory.civil);
      final r = await h.service.reviewAndRoute(
        c,
        h.verifier,
        now: at(hours(1)),
      );
      final fragmentsOfSeed = identityFragments(
        h.seed,
        h.identityOf(h.reporterUser),
      );
      for (final n in r.notifications) {
        expect(leaks('${n.title} ${n.body}', fragmentsOfSeed), isEmpty);
      }
    });
  });
}
