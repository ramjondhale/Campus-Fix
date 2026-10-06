// Shared fixtures for the service tests: a ComplaintService wired to the mock
// repositories, the seed directory of users and a few helpers to drive a
// complaint through its lifecycle.
import 'package:campusfix_core/campusfix_core.dart';

/// The instant everything in the service tests is relative to.
final DateTime t0 = DateTime.utc(2026, 10, 6, 9);

DateTime at(Duration after) => t0.add(after);

Duration hours(int h) => Duration(hours: h);

class Harness {
  Harness._({
    required this.seed,
    required this.complaints,
    required this.notifications,
    required this.users,
    required this.service,
    required this.notifier,
  });

  factory Harness({SeedData? seed}) {
    final data = seed ?? SeedData.build();
    final complaints = MockComplaintRepository();
    final notifications = MockNotificationRepository();
    final users = MockUserRepository.seeded(seed: data);
    return Harness._(
      seed: data,
      complaints: complaints,
      notifications: notifications,
      users: users,
      service: ComplaintService(
        complaints: complaints,
        notifications: notifications,
        users: users,
        ids: ComplaintIdGenerator(),
        clock: () => t0,
      ),
      notifier: NotificationService(notifications: notifications, users: users),
    );
  }

  final SeedData seed;
  final MockComplaintRepository complaints;
  final MockNotificationRepository notifications;
  final MockUserRepository users;
  final ComplaintService service;
  final NotificationService notifier;

  AppUser get reporterUser => seed.userById('u-rep-01')!;
  AppUser get otherReporter => seed.userById('u-rep-02')!;
  AppUser get verifier => seed.userById('u-ver-01')!;
  AppUser get verifier2 => seed.userById('u-ver-02')!;
  AppUser get admin => seed.userById('u-adm-01')!;

  /// Staff member [n] (1 or 2) of [department].
  AppUser staff(Department department, [int n = 1]) => seed.users
      .where(
        (u) => u.role == UserRole.maintenance && u.department == department,
      )
      .toList()[n - 1];

  List<AppUser> staffOf(Department department) => seed.users
      .where(
        (u) => u.role == UserRole.maintenance && u.department == department,
      )
      .toList();

  ReporterIdentity identityOf(AppUser u, {String? phone}) => ReporterIdentity(
    userId: u.id,
    fullName: u.displayName,
    idNumber: u.idNumber,
    email: u.email,
    phone: phone ?? '+91 90000 11001',
  );

  Future<Complaint> submit({
    ProblemCategory category = ProblemCategory.electrical,
    Severity severity = Severity.moderate,
    PeopleAffected people = PeopleAffected.small,
    bool safetyFlag = false,
    DateTime? now,
    AppUser? reporter,
    String building = 'Science Block',
    String floor = '2',
    String room = 'Lab 204',
  }) => service.submit(
    reporter: identityOf(reporter ?? reporterUser),
    category: category,
    description: 'The problem is clearly visible near the entrance.',
    building: building,
    floor: floor,
    room: room,
    beforePhotos: [
      Attachment(
        id: 'att-before-1',
        kind: AttachmentKind.beforePhoto,
        ref: 'assets/seed/before.jpg',
        createdAt: now ?? t0,
      ),
    ],
    severity: severity,
    peopleAffected: people,
    safetyFlag: safetyFlag,
    now: now ?? t0,
  );

  /// An after-repair photo taken at [taken].
  Attachment afterPhoto(
    String id,
    DateTime taken, {
    AttachmentKind kind = AttachmentKind.afterPhoto,
  }) => Attachment(
    id: id,
    kind: kind,
    ref: 'assets/seed/$id.jpg',
    createdAt: taken,
  );

  Future<Complaint> stored(String id) async => (await complaints.byId(id))!;

  /// Runs [step], expects success, and returns the stored complaint.
  Future<Complaint> ok(Future<ComplaintActionResult> step) async {
    final r = await step;
    if (!r.ok) throw StateError('Expected success, blocked by ${r.codes}');
    return r.complaint!;
  }

  /// One hour after the last event of [c]: the default time of each helper.
  DateTime nextAfter(Complaint c) =>
      c.timeline.last.at.add(const Duration(hours: 1));

  /// Review & Route by the verifier (auto-routable category => `assigned`).
  Future<Complaint> routed(Complaint c, {DateTime? now}) =>
      ok(service.reviewAndRoute(c, verifier, now: now ?? nextAfter(c)));

  /// `routed` then T3 by the first staff member of the assigned department.
  Future<Complaint> started(Complaint c, {DateTime? now}) async {
    final assigned = c.status == ComplaintStatus.reported ? await routed(c) : c;
    return ok(
      service.startWork(
        assigned,
        staff(assigned.assignment!.department),
        now: now ?? nextAfter(assigned),
      ),
    );
  }

  /// `started` then T4 by the claiming staff member.
  Future<Complaint> resolved(Complaint c, {DateTime? now}) async {
    final working = c.status == ComplaintStatus.inProgress
        ? c
        : await started(c);
    final when = now ?? nextAfter(working);
    return ok(
      service.resolve(
        working,
        staff(working.assignment!.department),
        resolutionNote: 'Replaced the part and tested it.',
        afterPhotos: [afterPhoto('att-after-${working.timeline.length}', when)],
        now: when,
      ),
    );
  }

  Future<Complaint> verified(Complaint c, {DateTime? now}) async {
    final done = c.status == ComplaintStatus.resolved ? c : await resolved(c);
    return ok(service.verify(done, verifier, now: now ?? nextAfter(done)));
  }

  Future<Complaint> closed(Complaint c, {DateTime? now}) async {
    final v = c.status == ComplaintStatus.verified ? c : await verified(c);
    return ok(service.close(v, admin, now: now ?? nextAfter(v)));
  }

  /// Notifications addressed to [user], oldest first.
  Future<List<AppNotification>> inbox(AppUser user) async =>
      (await notifications.byRecipient(user.id)).reversed.toList();

  Future<List<AppNotification>> allNotifications() => notifications.all();
}

/// Identity strings that must never appear in notification text.
List<String> identityFragments(SeedData seed, ReporterIdentity r) => [
  r.userId,
  r.fullName,
  r.idNumber,
  r.email,
  ?r.phone,
  ...r.fullName.split(' ').where((t) => t.length >= 4),
  for (final u in seed.users) ...[
    u.id,
    u.displayName,
    u.idNumber,
    u.email,
    ...u.displayName.split(' ').where((t) => t.length >= 4),
  ],
];

/// The fragments of [fragments] that occur in [text] (case-insensitive).
List<String> leaks(String text, Iterable<String> fragments) {
  final haystack = text.toLowerCase();
  return [
    for (final f in fragments)
      if (haystack.contains(f.toLowerCase())) f,
  ];
}
