// Pure unit tests (NO Firebase, NO emulator: run with `flutter test` in this
// package) for the MVP client-side notification producer (chunk C4):
// `FirebaseNotificationService`.
//
// The producer resolves recipients from two non-PII lookups (the reporter uid
// in `private/admin`, the `rosters/staff` document) instead of the user
// directory and `private/identity`; both are injected through
// `NotificationRecipientSource`, so these tests stub them. What they prove:
//
//   * the owner is the submit-time `reporter.userId`, or - on a transition,
//     where the assembled complaint carries `''` - the stored `reporterId`;
//   * the staff audiences come from the roster (department filter, verifiers =
//     verifiers + admins, admins), with the stock one-message-per-person rule;
//   * an audience that cannot be resolved is skipped (never an empty
//     `recipientId`) and a failed lookup never throws;
//   * the roster / reporter lookups are made once and kept;
//   * after the submit re-key the ids and `complaintId` carry the stored ID;
//   * for every notifying event the result equals core's stock
//     `NotificationService` over the real user directory (parity);
//   * `deliver` treats `permission-denied` on a deterministic id as an
//     idempotent re-delivery and rethrows anything else;
//   * the user directory is never read.
import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// The two lookups, counted.
class _FakeSource implements NotificationRecipientSource {
  _FakeSource({
    this.reporterIds = const <String, String>{},
    StaffRoster? roster,
  }) : roster = roster ?? StaffRoster.empty;

  final Map<String, String> reporterIds;
  StaffRoster roster;

  /// When set, both lookups throw it.
  Object? failure;

  int reporterReads = 0;
  int rosterReads = 0;

  @override
  Future<String?> reporterIdOf(String complaintId) async {
    reporterReads++;
    if (failure != null) throw failure!;
    return reporterIds[complaintId];
  }

  @override
  Future<StaffRoster> staffRoster() async {
    rosterReads++;
    if (failure != null) throw failure!;
    return roster;
  }
}

FirebaseException _denied() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
  message: 'denied',
);

/// A notification store that behaves like the rules: creating an existing id
/// is `permission-denied` (the recipient may only flip `read`).
class _RulesLikeStore implements NotificationRepository {
  final Map<String, AppNotification> docs = <String, AppNotification>{};

  /// Ids whose `add` fails with this error instead.
  final Map<String, Object> failing = <String, Object>{};

  @override
  Future<AppNotification> add(AppNotification notification) async {
    final Object? error = failing[notification.id];
    if (error != null) throw error;
    if (docs.containsKey(notification.id)) throw _denied();
    docs[notification.id] = notification;
    return notification;
  }

  @override
  Future<List<AppNotification>> all() => throw UnimplementedError();

  @override
  Future<List<AppNotification>> byRecipient(String recipientId) async =>
      <AppNotification>[
        for (final AppNotification n in docs.values)
          if (n.recipientId == recipientId) n,
      ];

  @override
  Future<AppNotification?> markRead(String id) async {
    final AppNotification? n = docs[id];
    if (n == null) return null;
    return docs[id] = n.copyWith(read: true);
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    for (final String id in docs.keys.toList()) {
      if (docs[id]!.recipientId == recipientId) {
        docs[id] = docs[id]!.copyWith(read: true);
      }
    }
  }

  @override
  Stream<List<AppNotification>> watchByRecipient(String recipientId) =>
      const Stream<List<AppNotification>>.empty();
}

/// A user directory that must never be read.
class _NoDirectory implements UserRepository {
  const _NoDirectory();

  @override
  Future<List<AppUser>> all() =>
      Future<List<AppUser>>.error(StateError('directory read'));

  @override
  Future<AppUser?> byId(String id) =>
      Future<AppUser?>.error(StateError('directory read'));

  @override
  Future<List<AppUser>> maintenanceByDepartment(Department department) =>
      Future<List<AppUser>>.error(StateError('directory read'));
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final SeedData seed = SeedData.build();
final DateTime t0 = DateTime.utc(2026, 10, 6, 9);

/// `rosters/staff` as the seed script writes it, from the seed users.
StaffRoster rosterOf(Iterable<AppUser> users) => StaffRoster(
  maintenance: <String, List<String>>{
    for (final Department d in Department.values)
      d.name: <String>[
        for (final AppUser u in users)
          if (u.role == UserRole.maintenance && u.department == d) u.id,
      ],
  },
  verifiers: <String>[
    for (final AppUser u in users)
      if (u.role == UserRole.verifier) u.id,
  ],
  admins: <String>[
    for (final AppUser u in users)
      if (u.role == UserRole.admin) u.id,
  ],
);

final StaffRoster roster = rosterOf(seed.users);
final AppUser reporterUser = seed.userById('u-rep-01')!;
final AppUser admin = seed.userById('u-adm-01')!;

const String complaintId = 'CF-2026-00042';

ReporterIdentity identityOf(AppUser u) => ReporterIdentity(
  userId: u.id,
  fullName: u.displayName,
  idNumber: u.idNumber,
  email: u.email,
  phone: '+91 90000 11001',
);

/// The reporter as a non-owner viewer assembles it.
const ReporterIdentity blankReporter = ReporterIdentity(
  userId: '',
  fullName: '',
  idNumber: '',
  email: '',
);

StatusEvent event(
  ComplaintStatus status, {
  String id = 'ev-CF-2026-00042-02',
  String? note,
  UserRole role = UserRole.verifier,
  int hour = 5,
}) => StatusEvent(
  id: id,
  status: status,
  actorId: '',
  actorRole: role,
  note: note,
  at: t0.add(Duration(hours: hour)),
);

Assignment assignment(Department d) =>
    Assignment(department: d, assignedBy: '', assignedAt: t0, isManual: false);

/// A complaint in [status] filed by [reporter], as the Firebase repository
/// assembles it. [timeline] defaults to the TL-1 event plus [last].
Complaint complaintIn(
  ComplaintStatus status, {
  ReporterIdentity reporter = blankReporter,
  Department? department,
  StatusEvent? last,
  String id = complaintId,
}) {
  final StatusEvent first = event(
    ComplaintStatus.reported,
    id: 'ev-$id-01',
    role: UserRole.reporter,
    hour: 0,
  );
  return Complaint(
    id: id,
    category: ProblemCategory.electrical,
    description: 'The breaker keeps tripping near the entrance.',
    building: 'Science Block',
    floor: '2',
    room: 'Lab 204',
    reporter: reporter,
    priority: Priority.high,
    status: status,
    assignment: department == null ? null : assignment(department),
    timeline: <StatusEvent>[first, ?last],
    severity: Severity.moderate,
    peopleAffected: PeopleAffected.small,
    createdAt: t0,
    updatedAt: last?.at ?? t0,
  );
}

FirebaseNotificationService _producer(
  _FakeSource source, {
  NotificationRepository? store,
}) => FirebaseNotificationService.withSource(
  recipients: source,
  notifications: store ?? _RulesLikeStore(),
  users: const _NoDirectory(),
);

Set<String> recipients(List<AppNotification> list) => <String>{
  for (final AppNotification n in list) n.recipientId,
};

void main() {
  // -------------------------------------------------------------------------
  group('submit (the owner is the submitting reporter)', () {
    test('owner from reporter.userId (no lookup), admins from the roster, '
        'ids from the event id', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      final FirebaseNotificationService service = _producer(source);
      final Complaint submitted = complaintIn(
        ComplaintStatus.reported,
        reporter: identityOf(reporterUser),
      );

      final List<AppNotification> built = await service.buildFor(
        null,
        submitted,
        submitted.timeline.first,
      );

      expect(recipients(built), <String>{reporterUser.id, admin.id});
      expect(source.reporterReads, 0);
      expect(source.rosterReads, 1);
      final AppNotification owner = built.firstWhere(
        (AppNotification n) => n.recipientId == reporterUser.id,
      );
      expect(owner.id, 'ntf-ev-$complaintId-01-${reporterUser.id}');
      expect(owner.complaintId, complaintId);
      expect(owner.type, NotificationType.submission);
      expect(owner.title, 'Complaint submitted');
      expect(owner.body, 'Complaint $complaintId submitted.');
      expect(owner.createdAt, submitted.timeline.first.at);
      expect(owner.read, isFalse);
      final AppNotification toAdmin = built.firstWhere(
        (AppNotification n) => n.recipientId == admin.id,
      );
      expect(toAdmin.title, 'New complaint');
    });

    test('after the repository re-keys the draft the ids and complaintId '
        'carry the stored Complaint ID', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      final FirebaseNotificationService service = _producer(source);
      // What ComplaintService builds locally, then what the repository stores.
      final Complaint draft = complaintIn(
        ComplaintStatus.reported,
        reporter: identityOf(reporterUser),
        id: 'CF-2026-00500',
      );
      final Complaint saved = withAllocatedId(draft, 'CF-2026-00001');

      final List<AppNotification> built = await service.buildFor(
        null,
        saved,
        saved.timeline.first,
      );

      expect(built, hasLength(2));
      for (final AppNotification n in built) {
        expect(n.complaintId, 'CF-2026-00001');
        expect(n.id, startsWith('ntf-ev-CF-2026-00001-01-'));
        expect(n.body, contains('CF-2026-00001'));
        expect('${n.id} ${n.body}', isNot(contains('00500')));
      }
    });

    test('a reporter who is also an admin gets only the owner message '
        '(first message wins)', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      final Complaint submitted = complaintIn(
        ComplaintStatus.reported,
        reporter: identityOf(admin),
      );

      final List<AppNotification> built = await _producer(
        source,
      ).buildFor(null, submitted, submitted.timeline.first);

      expect(built, hasLength(1));
      expect(built.single.recipientId, admin.id);
      expect(built.single.title, 'Complaint submitted');
    });
  });

  // -------------------------------------------------------------------------
  group('transitions (the owner comes from private/admin.reporterId)', () {
    test(
      'owner-only events read the reporter id once and never the roster',
      () async {
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final FirebaseNotificationService service = _producer(source);
        final Complaint before = complaintIn(ComplaintStatus.reported);
        final StatusEvent reviewed = event(ComplaintStatus.reviewed);
        final Complaint after = complaintIn(
          ComplaintStatus.reviewed,
          last: reviewed,
        );

        final List<AppNotification> built = await service.buildFor(
          before,
          after,
          reviewed,
        );

        expect(built, hasLength(1));
        expect(built.single.recipientId, reporterUser.id);
        expect(built.single.id, 'ntf-${reviewed.id}-${reporterUser.id}');
        expect(built.single.complaintId, complaintId);
        expect(built.single.type, NotificationType.statusChange);
        expect(source.reporterReads, 1);
        expect(source.rosterReads, 0);

        // The reporter id is kept per complaint (Review & Route builds twice).
        await service.buildFor(before, after, reviewed);
        expect(source.reporterReads, 1);
      },
    );

    test(
      'assigned: owner + the maintenance staff of that department only',
      () async {
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final StatusEvent assigned = event(ComplaintStatus.assigned);
        final List<AppNotification> built = await _producer(source).buildFor(
          complaintIn(ComplaintStatus.reviewed),
          complaintIn(
            ComplaintStatus.assigned,
            department: Department.plumber,
            last: assigned,
          ),
          assigned,
        );

        expect(recipients(built), <String>{
          reporterUser.id,
          'u-mnt-plu-01',
          'u-mnt-plu-02',
        });
        final AppNotification staff = built.firstWhere(
          (AppNotification n) => n.recipientId == 'u-mnt-plu-01',
        );
        expect(staff.type, NotificationType.assignment);
        expect(staff.title, 'New work assigned');
      },
    );

    test(
      'resolved: owner + every verifier and admin (no maintenance)',
      () async {
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final StatusEvent resolved = event(
          ComplaintStatus.resolved,
          role: UserRole.maintenance,
        );
        final List<AppNotification> built = await _producer(source).buildFor(
          complaintIn(
            ComplaintStatus.inProgress,
            department: Department.itTeam,
          ),
          complaintIn(
            ComplaintStatus.resolved,
            department: Department.itTeam,
            last: resolved,
          ),
          resolved,
        );

        expect(recipients(built), <String>{
          reporterUser.id,
          ...roster.verifiers,
          ...roster.admins,
        });
        expect(roster.verifiers, isNotEmpty);
        expect(
          built.where((AppNotification n) => n.recipientId.startsWith('u-mnt')),
          isEmpty,
        );
      },
    );

    test('a submit event whose complaint has no reporter uid: owner looked up, '
        'admins from the roster', () async {
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: reporterUser.id},
        roster: roster,
      );
      final Complaint submitted = complaintIn(ComplaintStatus.reported);
      final List<AppNotification> built = await _producer(
        source,
      ).buildFor(null, submitted, submitted.timeline.first);
      // owner (looked up) + admins; verifiers are not an audience of a submit.
      expect(recipients(built), <String>{reporterUser.id, ...roster.admins});
    });

    test('reject: the department staff get the rework note, the owner '
        'a resume message', () async {
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: reporterUser.id},
        roster: roster,
      );
      final StatusEvent rejected = event(
        ComplaintStatus.inProgress,
        note: 'Still tripping',
      );
      final List<AppNotification> built = await _producer(source).buildFor(
        complaintIn(
          ComplaintStatus.resolved,
          department: Department.electrician,
        ),
        complaintIn(
          ComplaintStatus.inProgress,
          department: Department.electrician,
          last: rejected,
        ),
        rejected,
      );

      final AppNotification staff = built.firstWhere(
        (AppNotification n) => n.recipientId == 'u-mnt-ele-01',
      );
      expect(staff.body, 'Rework needed on $complaintId: Still tripping.');
      expect(recipients(built), <String>{
        reporterUser.id,
        'u-mnt-ele-01',
        'u-mnt-ele-02',
      });
    });

    test(
      'reassign tells the previous department it left their queue',
      () async {
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final StatusEvent moved = event(
          ComplaintStatus.assigned,
          role: UserRole.admin,
        );
        final List<AppNotification> built = await _producer(source).buildFor(
          complaintIn(
            ComplaintStatus.inProgress,
            department: Department.electrician,
          ),
          complaintIn(
            ComplaintStatus.assigned,
            department: Department.civilMaintenance,
            last: moved,
          ),
          moved,
        );

        final Map<String, AppNotification> byRecipient =
            <String, AppNotification>{
              for (final AppNotification n in built) n.recipientId: n,
            };
        expect(byRecipient['u-mnt-ele-01']!.title, 'Removed from your queue');
        expect(byRecipient['u-mnt-civ-01']!.title, 'New work assigned');
        expect(byRecipient[reporterUser.id]!.title, 'Complaint reassigned');
      },
    );

    test('a person in two audiences gets one message, the first in template '
        'order', () async {
      final StaffRoster overlapping = StaffRoster(
        maintenance: <String, List<String>>{
          Department.electrician.name: <String>['u-x', 'u-y'],
        },
        verifiers: <String>['u-x', 'u-v'],
        admins: <String>['u-x', 'u-a'],
      );
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: 'u-x'},
        roster: overlapping,
      );
      final StatusEvent resolved = event(ComplaintStatus.resolved);
      final List<AppNotification> built = await _producer(source).buildFor(
        complaintIn(
          ComplaintStatus.inProgress,
          department: Department.electrician,
        ),
        complaintIn(
          ComplaintStatus.resolved,
          department: Department.electrician,
          last: resolved,
        ),
        resolved,
      );

      // owner = u-x (also a verifier and an admin); verifiers audience adds
      // u-v and u-a; each person appears once.
      expect(built.map((AppNotification n) => n.recipientId).toList(), <String>[
        'u-x',
        'u-v',
        'u-a',
      ]);
      expect(built.first.title, 'Repair completed');
      expect(built.map((AppNotification n) => n.id).toSet(), hasLength(3));
    });
  });

  // -------------------------------------------------------------------------
  group('unresolvable audiences are skipped, never empty', () {
    final StatusEvent reviewed = event(ComplaintStatus.reviewed);
    final Complaint before = complaintIn(ComplaintStatus.reported);
    final Complaint after = complaintIn(
      ComplaintStatus.reviewed,
      last: reviewed,
    );

    test('no stored reporterId: no owner notification', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      expect(
        await _producer(source).buildFor(before, after, reviewed),
        isEmpty,
      );
    });

    test('a blank reporterId counts as missing', () async {
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: ''},
        roster: roster,
      );
      expect(
        await _producer(source).buildFor(before, after, reviewed),
        isEmpty,
      );
    });

    test(
      'no reporter: staff are still notified, nobody gets an empty id',
      () async {
        final _FakeSource source = _FakeSource(roster: roster);
        final StatusEvent resolved = event(ComplaintStatus.resolved);
        final List<AppNotification> built = await _producer(source).buildFor(
          complaintIn(
            ComplaintStatus.inProgress,
            department: Department.itTeam,
          ),
          complaintIn(
            ComplaintStatus.resolved,
            department: Department.itTeam,
            last: resolved,
          ),
          resolved,
        );
        expect(recipients(built), <String>{
          ...roster.verifiers,
          ...roster.admins,
        });
        expect(
          built.every((AppNotification n) => n.recipientId.isNotEmpty),
          isTrue,
        );
      },
    );

    test('a failed lookup never throws and is not remembered', () async {
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: reporterUser.id},
        roster: roster,
      )..failure = _denied();
      final FirebaseNotificationService service = _producer(source);
      final Complaint submitted = complaintIn(ComplaintStatus.reported);

      expect(await service.buildFor(before, after, reviewed), isEmpty);
      expect(
        await service.buildFor(null, submitted, submitted.timeline.first),
        isEmpty,
      );
      expect(source.reporterReads, 2);
      expect(source.rosterReads, 1);

      // The failure is transient: the next write retries the lookups.
      source.failure = null;
      final List<AppNotification> retried = await service.buildFor(
        before,
        after,
        reviewed,
      );
      expect(retried.single.recipientId, reporterUser.id);
      expect(source.reporterReads, 3);
    });

    test('an unseeded (empty) roster is not remembered', () async {
      final _FakeSource source = _FakeSource();
      final FirebaseNotificationService service = _producer(source);
      final Complaint submitted = complaintIn(
        ComplaintStatus.reported,
        reporter: identityOf(reporterUser),
      );

      final List<AppNotification> first = await service.buildFor(
        null,
        submitted,
        submitted.timeline.first,
      );
      expect(recipients(first), <String>{reporterUser.id});

      source.roster = roster; // the seed ran in between
      final List<AppNotification> second = await service.buildFor(
        null,
        submitted,
        submitted.timeline.first,
      );
      expect(recipients(second), <String>{reporterUser.id, ...roster.admins});
      expect(source.rosterReads, 2);
    });

    test('a non-notifying event builds nothing and reads nothing', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      final StatusEvent same = event(ComplaintStatus.reported);
      expect(
        await _producer(source).buildFor(
          complaintIn(ComplaintStatus.reported),
          complaintIn(ComplaintStatus.reported, last: same),
          same,
        ),
        isEmpty,
      );
      expect(source.reporterReads + source.rosterReads, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('the roster is read once per instance', () {
    test('across events and complaints', () async {
      final _FakeSource source = _FakeSource(roster: roster);
      final FirebaseNotificationService service = _producer(source);
      for (final String id in <String>['CF-2026-00001', 'CF-2026-00002']) {
        final Complaint submitted = complaintIn(
          ComplaintStatus.reported,
          reporter: identityOf(reporterUser),
          id: id,
        );
        await service.buildFor(null, submitted, submitted.timeline.first);
        final StatusEvent resolved = event(
          ComplaintStatus.resolved,
          id: 'ev-$id-05',
        );
        await service.buildFor(
          complaintIn(
            ComplaintStatus.inProgress,
            reporter: identityOf(reporterUser),
            department: Department.itTeam,
            id: id,
          ),
          complaintIn(
            ComplaintStatus.resolved,
            reporter: identityOf(reporterUser),
            department: Department.itTeam,
            last: resolved,
            id: id,
          ),
          resolved,
        );
      }
      expect(source.rosterReads, 1);
      expect(source.reporterReads, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('parity with core\'s stock NotificationService', () {
    final Map<(ComplaintStatus?, ComplaintStatus), Department?>
    cases = <(ComplaintStatus?, ComplaintStatus), Department?>{
      (null, ComplaintStatus.reported): null,
      (ComplaintStatus.reported, ComplaintStatus.reviewed): null,
      (ComplaintStatus.reviewed, ComplaintStatus.assigned): Department.plumber,
      (ComplaintStatus.assigned, ComplaintStatus.inProgress):
          Department.plumber,
      (ComplaintStatus.inProgress, ComplaintStatus.resolved):
          Department.plumber,
      (ComplaintStatus.resolved, ComplaintStatus.verified): Department.plumber,
      (ComplaintStatus.verified, ComplaintStatus.closed): Department.plumber,
      (ComplaintStatus.resolved, ComplaintStatus.inProgress):
          Department.plumber,
      (ComplaintStatus.inProgress, ComplaintStatus.assigned):
          Department.carpenter,
      (ComplaintStatus.assigned, ComplaintStatus.assigned):
          Department.carpenter,
    };

    for (final MapEntry<(ComplaintStatus?, ComplaintStatus), Department?> c
        in cases.entries) {
      final (ComplaintStatus? from, ComplaintStatus to) = c.key;
      test('${from?.name ?? 'new'} -> ${to.name}', () async {
        final StatusEvent e = event(
          to,
          note: to == ComplaintStatus.inProgress ? 'Still broken' : null,
        );
        final Complaint? previous = from == null
            ? null
            : complaintIn(
                from,
                department: from.order >= ComplaintStatus.assigned.order
                    ? Department.plumber
                    : null,
              );
        Complaint next(ReporterIdentity reporter) => complaintIn(
          to,
          reporter: reporter,
          department: c.value,
          last: from == null ? null : e,
        );

        // Core's stock service over the real directory, the reporter known.
        final List<AppNotification> stock =
            await NotificationService(
              notifications: MockNotificationRepository(),
              users: MockUserRepository.seeded(seed: seed),
            ).buildFor(
              previous,
              next(identityOf(reporterUser)),
              from == null ? next(identityOf(reporterUser)).timeline.first : e,
            );

        // The Firebase producer, the reporter only in private/admin.
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final Complaint after = next(
          from == null ? identityOf(reporterUser) : blankReporter,
        );
        final List<AppNotification> built = await _producer(
          source,
        ).buildFor(previous, after, from == null ? after.timeline.first : e);

        expect(stock, isNotEmpty);
        expect(built, unorderedEquals(stock));
      });
    }
  });

  // -------------------------------------------------------------------------
  group('deliver (idempotent re-delivery)', () {
    final AppNotification a = AppNotification(
      id: 'ntf-ev-1-u-a',
      recipientId: 'u-a',
      complaintId: complaintId,
      type: NotificationType.statusChange,
      title: 'Complaint reviewed',
      body: '$complaintId has been reviewed.',
      createdAt: t0,
    );
    final AppNotification b = a.copyWith(
      id: 'ntf-ev-1-u-b',
      recipientId: 'u-b',
    );

    test('stores every notification and returns them', () async {
      final _RulesLikeStore store = _RulesLikeStore();
      final FirebaseNotificationService service = _producer(
        _FakeSource(roster: roster),
        store: store,
      );
      expect(await service.deliver(<AppNotification>[a, b]), <AppNotification>[
        a,
        b,
      ]);
      expect(store.docs.keys, <String>['ntf-ev-1-u-a', 'ntf-ev-1-u-b']);
    });

    test('permission-denied on an existing deterministic id is success and '
        'the rest are still stored', () async {
      final _RulesLikeStore store = _RulesLikeStore();
      final FirebaseNotificationService service = _producer(
        _FakeSource(roster: roster),
        store: store,
      );
      await service.deliver(<AppNotification>[a]);

      final List<AppNotification> again = await service.deliver(
        <AppNotification>[a, b],
      );
      expect(again, <AppNotification>[a, b]);
      expect(store.docs.keys.toSet(), <String>{'ntf-ev-1-u-a', 'ntf-ev-1-u-b'});
    });

    test('any other error is rethrown', () async {
      final _RulesLikeStore store = _RulesLikeStore()
        ..failing['ntf-ev-1-u-b'] = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      final FirebaseNotificationService service = _producer(
        _FakeSource(roster: roster),
        store: store,
      );
      await expectLater(
        service.deliver(<AppNotification>[a, b]),
        throwsA(
          isA<FirebaseException>().having(
            (FirebaseException e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
    });

    test(
      'emitFor builds then delivers; a retry of the same event is a no-op',
      () async {
        final _RulesLikeStore store = _RulesLikeStore();
        final _FakeSource source = _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        );
        final FirebaseNotificationService service = _producer(
          source,
          store: store,
        );
        final StatusEvent reviewed = event(ComplaintStatus.reviewed);
        final Complaint before = complaintIn(ComplaintStatus.reported);
        final Complaint after = complaintIn(
          ComplaintStatus.reviewed,
          last: reviewed,
        );

        final List<AppNotification> first = await service.emitFor(
          before,
          after,
          reviewed,
        );
        final List<AppNotification> retry = await service.emitFor(
          before,
          after,
          reviewed,
        );
        expect(retry, first);
        expect(store.docs, hasLength(1));
      },
    );
  });

  // -------------------------------------------------------------------------
  group('privacy and the inherited consumer half', () {
    test('no notification carries the reporter\'s identity and the user '
        'directory is never read', () async {
      final _RulesLikeStore store = _RulesLikeStore();
      final _FakeSource source = _FakeSource(
        reporterIds: <String, String>{complaintId: reporterUser.id},
        roster: roster,
      );
      final FirebaseNotificationService service = _producer(
        source,
        store: store,
      );
      final StatusEvent resolved = event(ComplaintStatus.resolved);
      final List<AppNotification> emitted = await service.emitFor(
        complaintIn(ComplaintStatus.inProgress, department: Department.itTeam),
        complaintIn(
          ComplaintStatus.resolved,
          department: Department.itTeam,
          last: resolved,
        ),
        resolved,
      );

      expect(emitted, isNotEmpty);
      for (final AppNotification n in emitted) {
        final String text = '${n.title} ${n.body}'.toLowerCase();
        for (final String secret in <String>[
          reporterUser.displayName,
          reporterUser.idNumber,
          reporterUser.email,
          reporterUser.id,
        ]) {
          expect(text, isNot(contains(secret.toLowerCase())), reason: secret);
        }
      }
    });

    test('feed, unread count and mark-read are the inherited ones', () async {
      final _RulesLikeStore store = _RulesLikeStore();
      final FirebaseNotificationService service = _producer(
        _FakeSource(
          reporterIds: <String, String>{complaintId: reporterUser.id},
          roster: roster,
        ),
        store: store,
      );
      final StatusEvent reviewed = event(ComplaintStatus.reviewed);
      final List<AppNotification> emitted = await service.emitFor(
        complaintIn(ComplaintStatus.reported),
        complaintIn(ComplaintStatus.reviewed, last: reviewed),
        reviewed,
      );

      expect(await service.byRecipient(reporterUser.id), emitted);
      expect(await service.unreadCount(reporterUser.id), 1);
      await service.markRead(emitted.single.id);
      expect(await service.unreadCount(reporterUser.id), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('StaffRoster', () {
    test('parses the document the seed writes', () {
      final StaffRoster parsed = StaffRoster.fromJson(<String, Object?>{
        'maintenance': <String, Object?>{
          'itTeam': <Object?>['u-1', 'u-2'],
          'plumber': <Object?>[],
        },
        'verifiers': <Object?>['u-v'],
        'admins': <Object?>['u-a'],
      });
      expect(parsed.maintenanceOf(Department.itTeam), <String>['u-1', 'u-2']);
      expect(parsed.maintenanceOf(Department.plumber), isEmpty);
      expect(parsed.maintenanceOf(Department.housekeeping), isEmpty);
      expect(parsed.verifiersAndAdmins, <String>['u-v', 'u-a']);
      expect(parsed.isEmpty, isFalse);
    });

    test('missing or malformed parts read as empty (never throw)', () {
      expect(StaffRoster.fromJson(null).isEmpty, isTrue);
      expect(StaffRoster.fromJson(<String, Object?>{}).isEmpty, isTrue);
      final StaffRoster odd = StaffRoster.fromJson(<String, Object?>{
        'maintenance': 'nope',
        'verifiers': <Object?>['u-v', 3, '', null],
        'admins': <String, Object?>{'x': 1},
      });
      expect(odd.verifiers, <String>['u-v']);
      expect(odd.admins, isEmpty);
      expect(odd.maintenance, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('the seed script writes the shape the resolver reads', () {
    const String seedPath = '../../backend/seed/seed.mjs';
    final bool haveSeed = File(seedPath).existsSync();

    test(
      'rosters/staff is { maintenance: { <Department.name>: [...] }, '
      'verifiers, admins } of uids, and private/admin carries reporterId',
      () {
        final String src = File(seedPath).readAsStringSync();
        expect(src, contains("path: 'rosters/staff'"));
        expect(src, contains('maintenance: {}, verifiers: [], admins: []'));
        // Department keys are the enum names, as in users[].department.
        expect(src, contains('roster.maintenance[u.department]'));
        expect(
          src,
          contains('reporterId: c.identity.userId'),
          reason: 'private/admin.reporterId = the reporter uid (no PII)',
        );
        // The department strings the seed exports are the Department names.
        expect(<String>{
          for (final AppUser u in seed.users)
            if (u.department != null) u.department!.name,
        }, Department.values.map((Department d) => d.name).toSet());
      },
      skip: haveSeed ? false : 'run from packages/campusfix_firebase',
    );
  });
}
