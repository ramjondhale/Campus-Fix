import 'package:meta/meta.dart';

import '../enums/attachment_kind.dart';
import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../enums/notification_type.dart';
import '../enums/people_affected.dart';
import '../enums/priority.dart';
import '../enums/problem_category.dart';
import '../enums/severity.dart';
import '../enums/user_role.dart';
import '../logic/assignment_router.dart';
import '../logic/priority_engine.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../models/attachment.dart';
import '../models/complaint.dart';
import '../models/reporter_identity.dart';
import '../models/status_event.dart';
import 'id_generator.dart';
import 'mock_account.dart';

/// The reference "now" of the default seed: 2026-10-06 09:00 UTC. Every seed
/// timestamp is an offset from it, so the default seed is deterministic.
final DateTime seedReferenceTime = DateTime.utc(2026, 10, 6, 9);

/// The password of every seeded account (prototype only; see `MockAccount`).
const String seedDemoPassword = 'campusfix-demo';

/// The prototype's seed data: users and their logins, 29 complaints with
/// replay-valid timelines, and the in-app notifications those timelines
/// produce.
///
/// All of it is derived from one reference time, so build it with the real
/// clock (`SeedData.build(now: DateTime.now())`) to make a demo look fresh, or
/// with no argument for the deterministic default ([seedReferenceTime]).
///
/// Invariants the seed satisfies (asserted by the seed-integrity tests):
/// * every `Assignment.isManual == isManualAssignment(category, department)`;
/// * every timeline is replay-valid against `StatusMachine.canTransition`
///   (TL-1..TL-7) and the complaint satisfies INV-1..INV-5;
/// * `priority` is `computePriority(...)` - recomputed with the aged waiting
///   time for unresolved complaints, frozen at the last pre-resolution
///   recompute for `resolved` / `verified` / `closed` ones;
/// * no free text contains a seeded reporter's or staff member's identity
///   (privacy-spec LK-6 / PR-T9).
@immutable
class SeedData {
  const SeedData._({
    required this.now,
    required this.users,
    required this.accounts,
    required this.demoAccounts,
    required this.complaints,
    required this.notifications,
    required this.lastSequenceByYear,
  });

  /// Builds the seed relative to [now] (default [seedReferenceTime]).
  factory SeedData.build({DateTime? now}) =>
      _SeedBuilder(now ?? seedReferenceTime).build();

  /// The reference time every seed timestamp is relative to.
  final DateTime now;

  /// Reporters, maintenance staff (two per department), verifiers and one
  /// admin.
  final List<AppUser> users;

  /// A login for every user in [users] (all share [seedDemoPassword]).
  final List<MockAccount> accounts;

  /// One account per role for the "Demo accounts" quick-fill: the first
  /// reporter, an electrician, a verifier and the admin.
  final List<MockAccount> demoAccounts;

  /// The seed complaints, oldest first (ascending Complaint ID).
  final List<Complaint> complaints;

  /// Seed notifications (PII-free, status-machine-spec §5.1), oldest first.
  final List<AppNotification> notifications;

  /// The last Complaint ID sequence used per year. Pass it to
  /// `ComplaintIdGenerator(initialCounters: ...)` so new IDs continue after
  /// the seed.
  final Map<int, int> lastSequenceByYear;

  /// The users with [role].
  List<AppUser> usersWithRole(UserRole role) => [
    for (final u in users)
      if (u.role == role) u,
  ];

  /// The user with [id], or `null`.
  AppUser? userById(String id) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

typedef _Reporter = ({AppUser user, String? phone});

AppUser _person(
  String id,
  String idNumber,
  String name,
  UserRole role, {
  Department? department,
}) => AppUser(
  id: id,
  idNumber: idNumber,
  displayName: name,
  role: role,
  email: '${name.toLowerCase().replaceAll(' ', '.')}@campus.test',
  department: department,
);

final List<_Reporter> _reporters = [
  (
    user: _person('u-rep-01', 'S2024-1001', 'Aditi Sharma', UserRole.reporter),
    phone: '+91 90000 11001',
  ),
  (
    user: _person(
      'u-rep-02',
      'S2024-1002',
      'Rohit Deshmukh',
      UserRole.reporter,
    ),
    phone: '+91 90000 11002',
  ),
  (
    user: _person('u-rep-03', 'S2023-0871', 'Priyanka Iyer', UserRole.reporter),
    phone: '+91 90000 11003',
  ),
  (
    user: _person(
      'u-rep-04',
      'S2023-0914',
      'Vikram Choudhary',
      UserRole.reporter,
    ),
    phone: '+91 90000 11004',
  ),
  (
    user: _person(
      'u-rep-05',
      'S2022-0415',
      'Sneha Kulkarni',
      UserRole.reporter,
    ),
    phone: '+91 90000 11005',
  ),
  (
    user: _person(
      'u-rep-06',
      'S2024-1033',
      'Arjun Bhatnagar',
      UserRole.reporter,
    ),
    phone: null,
  ),
  (
    user: _person(
      'u-rep-07',
      'F2019-0127',
      'Meenakshi Pillai',
      UserRole.reporter,
    ),
    phone: '+91 90000 11007',
  ),
  (
    user: _person(
      'u-rep-08',
      'S2022-0498',
      'Farhan Qureshi',
      UserRole.reporter,
    ),
    phone: null,
  ),
  (
    user: _person('u-rep-09', 'S2025-1210', 'Kavya Reddy', UserRole.reporter),
    phone: '+91 90000 11009',
  ),
  (
    user: _person(
      'u-rep-10',
      'F2016-0042',
      'Imran Siddiqui',
      UserRole.reporter,
    ),
    phone: '+91 90000 11010',
  ),
];

AppUser _staff(String code, int n, String name, Department department) =>
    _person(
      'u-mnt-$code-0$n',
      'MNT-${code.toUpperCase()}-0$n',
      name,
      UserRole.maintenance,
      department: department,
    );

final List<AppUser> _maintenance = [
  _staff('ele', 1, 'Suresh Patil', Department.electrician),
  _staff('ele', 2, 'Ganesh Jadhav', Department.electrician),
  _staff('plu', 1, 'Mahesh Gaikwad', Department.plumber),
  _staff('plu', 2, 'Dattatray Shinde', Department.plumber),
  _staff('car', 1, 'Ramesh Pawar', Department.carpenter),
  _staff('car', 2, 'Santosh Wagh', Department.carpenter),
  _staff('civ', 1, 'Prakash Salunkhe', Department.civilMaintenance),
  _staff('civ', 2, 'Nitin Bhosale', Department.civilMaintenance),
  _staff('it', 1, 'Deepak Naik', Department.itTeam),
  _staff('it', 2, 'Nikhil Sawant', Department.itTeam),
  _staff('hk', 1, 'Sunita Waghmare', Department.housekeeping),
  _staff('hk', 2, 'Lakshmi Gawade', Department.housekeeping),
];

final List<AppUser> _verifiers = [
  _person('u-ver-01', 'VER-01', 'Kiran Joshi', UserRole.verifier),
  _person('u-ver-02', 'VER-02', 'Neelam Bhandari', UserRole.verifier),
];

final AppUser _admin = _person(
  'u-adm-01',
  'ADM-01',
  'Sandeep Kapoor',
  UserRole.admin,
);

// ---------------------------------------------------------------------------
// Complaint specs: a compact script per complaint. The builder turns each
// script into a complete, replay-valid Complaint (timeline, assignment,
// photos, priority) so the 29 complaints cannot drift out of the rules.
// Times are hours after the complaint was created.
// ---------------------------------------------------------------------------

/// Who performs a review / verification.
enum _Who { verifier1, verifier2, admin }

/// A verifier's rejection of a resolved complaint (T7) and, optionally, the
/// next resolution.
class _Rework {
  const _Rework({
    required this.rejectH,
    required this.note,
    this.rejectBy = _Who.verifier2,
    this.resolveH,
    this.resolution,
  });

  final double rejectH;
  final String note;
  final _Who rejectBy;

  /// When the work is resolved again; `null` leaves it in rework.
  final double? resolveH;
  final String? resolution;
}

/// An admin pull-back (T8) to another department, then a restart.
class _PullBack {
  const _PullBack({
    required this.atH,
    required this.department,
    required this.reason,
    required this.restartH,
    this.worker = 0,
  });

  final double atH;
  final Department department;
  final String reason;
  final double restartH;
  final int worker;
}

/// An admin reassignment while still `assigned` (annotation event).
class _Reassign {
  const _Reassign({
    required this.atH,
    required this.department,
    required this.reason,
  });

  final double atH;
  final Department department;
  final String reason;
}

class _Spec {
  const _Spec({
    required this.ageH,
    required this.reporter,
    required this.category,
    this.title,
    required this.description,
    required this.building,
    required this.floor,
    required this.room,
    required this.severity,
    required this.people,
    this.safety = false,
    this.beforePhotos = 1,
    required this.status,
    this.reviewH,
    this.reviewer = _Who.verifier1,
    this.reviewNote,
    this.priorityOverride,
    this.assignDepartment,
    this.assignH,
    this.assignNote,
    this.pick,
    this.startH,
    this.worker = 0,
    this.resolveH,
    this.resolution,
    this.afterPhotos = 1,
    this.rework = const [],
    this.pullBack,
    this.reassign,
    this.verifyH,
    this.verifier = _Who.verifier1,
    this.closeH,
  });

  /// Hours before "now" the complaint was created.
  final double ageH;

  /// Index into [_reporters].
  final int reporter;
  final ProblemCategory category;
  final String? title;
  final String description;
  final String building;
  final String floor;
  final String room;
  final Severity severity;
  final PeopleAffected people;
  final bool safety;
  final int beforePhotos;

  /// The status the complaint ends in.
  final ComplaintStatus status;

  // T1 (+ auto T2): review.
  final double? reviewH;
  final _Who reviewer;
  final String? reviewNote;

  /// Admin priority override set at review (admin reviewers only).
  final Priority? priorityOverride;

  /// A department chosen by an admin (required for `safety` / `other`, which
  /// have no auto-route; optional elsewhere to override the route).
  final Department? assignDepartment;

  /// When the admin assigns a `safety` / `other` complaint (after review).
  final double? assignH;
  final String? assignNote;

  /// Index (0/1) of a department staff member the admin picks as assignee.
  final int? pick;

  // T3: start (claim).
  final double? startH;

  /// Index (0/1) of the department staff member who claims and does the work.
  final int worker;

  // T4: resolve.
  final double? resolveH;
  final String? resolution;
  final int afterPhotos;

  final List<_Rework> rework;
  final _PullBack? pullBack;
  final _Reassign? reassign;

  // T5 / T6.
  final double? verifyH;
  final _Who verifier;
  final double? closeH;
}

final List<_Spec> _specs = [
  // ---- closed -------------------------------------------------------------
  const _Spec(
    ageH: 720,
    reporter: 1,
    category: ProblemCategory.furniture,
    title: 'Wobbly desk in classroom',
    description:
        'One of the desks in the front row wobbles badly and the writing '
        'surface has started to come loose. It is hard to take notes.',
    building: 'Academic Block A',
    floor: '1',
    room: 'Classroom 103',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.closed,
    reviewH: 6,
    startH: 20,
    resolveH: 44,
    resolution:
        'Replaced the damaged desk top and tightened the legs. The desk is '
        'stable now.',
    verifyH: 70,
    closeH: 90,
  ),
  const _Spec(
    ageH: 624,
    reporter: 2,
    category: ProblemCategory.plumbing,
    title: 'Washroom tap leaking continuously',
    description:
        'The tap in the washroom near the stairs has been dripping non-stop '
        'for two days and the floor around the basin stays wet.',
    building: 'Academic Block A',
    floor: '2',
    room: 'Washroom (near stairs)',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.closed,
    reviewH: 4,
    reviewer: _Who.verifier2,
    startH: 10,
    resolveH: 32,
    resolution:
        'Replaced the worn tap cartridge and washer. No leakage after a '
        'two-hour test.',
    verifyH: 50,
    verifier: _Who.verifier2,
    closeH: 72,
  ),
  const _Spec(
    ageH: 528,
    reporter: 0,
    category: ProblemCategory.it,
    title: 'Projector shows no display',
    description:
        'The projector in the lecture theatre powers on but shows "No '
        'signal" even with a laptop connected. The morning lecture had to be '
        'held without slides.',
    building: 'Academic Block B',
    floor: 'Ground',
    room: 'Lecture Theatre 1',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.closed,
    reviewH: 3,
    startH: 20,
    resolveH: 40,
    resolution:
        'Replaced the faulty HDMI wall port and re-tested with two laptops.',
    verifyH: 60,
    closeH: 80,
  ),
  const _Spec(
    ageH: 432,
    reporter: 3,
    category: ProblemCategory.electrical,
    title: 'Flickering tube lights in lab',
    description:
        'Several tube lights in the computer lab flicker constantly, which '
        'is giving everyone headaches during long practical sessions.',
    building: 'Science & Computer Block',
    floor: '1',
    room: 'Computer Lab 2',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    beforePhotos: 2,
    status: ComplaintStatus.closed,
    reviewH: 2,
    startH: 6,
    worker: 1,
    resolveH: 30,
    resolution: 'Replaced the starters on four tube lights.',
    rework: [
      _Rework(
        rejectH: 50,
        note:
            'Two lights near the back row still flicker. Please check the '
            'ballast.',
        resolveH: 80,
        resolution:
            'Replaced two ballasts and ran all tubes for an hour with no '
            'flicker.',
      ),
    ],
    verifyH: 100,
    verifier: _Who.verifier2,
    closeH: 110,
  ),
  const _Spec(
    ageH: 360,
    reporter: 4,
    category: ProblemCategory.safety,
    title: 'Live wires hanging from junction box',
    description:
        'Live wires are hanging from an open junction box right above the '
        'corridor near the lecture theatre entrance. Students walk directly '
        'under it.',
    building: 'Academic Block B',
    floor: 'Ground',
    room: 'Corridor',
    severity: Severity.severe,
    people: PeopleAffected.many,
    beforePhotos: 2,
    status: ComplaintStatus.closed,
    reviewH: 1,
    reviewer: _Who.verifier2,
    assignDepartment: Department.electrician,
    assignH: 2,
    assignNote: 'Urgent electrical hazard; assigned to Electrician.',
    startH: 3,
    worker: 1,
    resolveH: 8,
    resolution:
        'Isolated the supply, re-terminated the wires inside a closed '
        'junction box and fixed the cover.',
    verifyH: 20,
    verifier: _Who.verifier2,
    closeH: 24,
  ),
  // ---- verified -----------------------------------------------------------
  const _Spec(
    ageH: 288,
    reporter: 2,
    category: ProblemCategory.civil,
    title: 'Damp patch and cracked plaster on wall',
    description:
        'A large damp patch has appeared on the side wall and the plaster '
        'is cracking and peeling off. It gets worse after rain.',
    building: 'Academic Block B',
    floor: '1',
    room: 'Classroom B102',
    severity: Severity.moderate,
    people: PeopleAffected.small,
    status: ComplaintStatus.verified,
    reviewH: 5,
    startH: 30,
    resolveH: 100,
    resolution:
        'Scraped off the damaged plaster, applied a waterproof coat and '
        'repainted the patch.',
    afterPhotos: 2,
    verifyH: 130,
  ),
  const _Spec(
    ageH: 240,
    reporter: 5,
    category: ProblemCategory.cleanliness,
    title: 'Washroom not cleaned for days',
    description:
        'The washroom block on this floor has not been cleaned for several '
        'days and there is a strong smell. Residents are avoiding it.',
    building: 'Hostel Block A',
    floor: '2',
    room: 'Washroom Block',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.verified,
    reviewH: 6,
    reviewer: _Who.verifier2,
    startH: 20,
    resolveH: 30,
    resolution:
        'Deep-cleaned the washroom block, restocked supplies and applied '
        'disinfectant.',
    verifyH: 48,
    verifier: _Who.verifier2,
  ),
  const _Spec(
    ageH: 216,
    reporter: 6,
    category: ProblemCategory.other,
    title: 'Water cooler not cooling',
    description:
        'The water cooler in the reading hall only dispenses warm water. '
        'Many readers use it every day.',
    building: 'Central Library',
    floor: 'Ground',
    room: 'Reading Hall',
    severity: Severity.minor,
    people: PeopleAffected.many,
    status: ComplaintStatus.verified,
    reviewH: 8,
    assignDepartment: Department.electrician,
    assignH: 20,
    startH: 40,
    resolveH: 55,
    resolution:
        'Cleaned the condenser and reset the thermostat. Water is chilled '
        'again.',
    verifyH: 90,
  ),
  // ---- unresolved, aged ---------------------------------------------------
  const _Spec(
    ageH: 210,
    reporter: 3,
    category: ProblemCategory.cleanliness,
    title: 'Classroom not cleaned',
    description:
        'The classroom has not been swept for over a week. There is dust on '
        'the benches and cobwebs in the corners.',
    building: 'Academic Block A',
    floor: '1',
    room: 'Classroom 104',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.assigned,
    reviewH: 8,
    reviewer: _Who.admin,
    reviewNote: 'Raised priority: exams start next week.',
    priorityOverride: Priority.high,
  ),
  const _Spec(
    ageH: 192,
    reporter: 4,
    category: ProblemCategory.electrical,
    title: 'Ceiling fans not working',
    description:
        'Three ceiling fans in the corridor stopped working and the rooms '
        'get very hot in the afternoon.',
    building: 'Hostel Block A',
    floor: '3',
    room: 'Corridor',
    severity: Severity.moderate,
    people: PeopleAffected.small,
    status: ComplaintStatus.inProgress,
    reviewH: 5,
    startH: 50,
    worker: 1,
  ),
  // ---- resolved -----------------------------------------------------------
  const _Spec(
    ageH: 144,
    reporter: 0,
    category: ProblemCategory.it,
    title: 'Wi-Fi down on the whole floor',
    description:
        'There has been no Wi-Fi signal on this floor since yesterday. '
        'Students cannot reach the e-journals or the online catalogue.',
    building: 'Central Library',
    floor: '1',
    room: 'Reference Section',
    severity: Severity.severe,
    people: PeopleAffected.many,
    status: ComplaintStatus.resolved,
    reviewH: 3,
    startH: 4,
    worker: 1,
    resolveH: 26,
    resolution:
        'Replaced the faulty power injector for the access point. Signal '
        'tested at several spots on the floor.',
  ),
  // ---- more in progress / assigned (aging) ---------------------------------
  const _Spec(
    ageH: 120,
    reporter: 5,
    category: ProblemCategory.cleanliness,
    title: 'Garbage not collected',
    description:
        'Garbage near the mess has not been collected for three days. It is '
        'attracting flies and the smell reaches the dining area.',
    building: 'Hostel Block A',
    floor: 'Ground',
    room: 'Mess Hall',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.inProgress,
    reviewH: 4,
    reviewer: _Who.verifier2,
    startH: 40,
  ),
  const _Spec(
    ageH: 98,
    reporter: 0,
    category: ProblemCategory.furniture,
    title: 'Lecture bench missing writing pad',
    description:
        'Several benches in the lecture theatre have lost their writing '
        'pads. Students have to hold their notebooks on their knees.',
    building: 'Academic Block B',
    floor: 'Ground',
    room: 'Lecture Theatre 2',
    severity: Severity.minor,
    people: PeopleAffected.small,
    status: ComplaintStatus.assigned,
    reviewH: 10,
    reviewer: _Who.admin,
    reviewNote: 'Cosmetic issue; scheduled with routine work.',
    priorityOverride: Priority.low,
  ),
  const _Spec(
    ageH: 96,
    reporter: 7,
    category: ProblemCategory.furniture,
    title: 'Broken chair leg',
    description:
        'The leg of my chair is cracked and the chair tilts when I sit. '
        'Someone could fall.',
    building: 'Academic Block A',
    floor: '2',
    room: 'Classroom 202',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.resolved,
    reviewH: 5,
    reviewer: _Who.verifier2,
    startH: 20,
    worker: 1,
    resolveH: 36,
    resolution:
        'Re-fixed the chair leg with new screws and glue and load-tested '
        'the chair.',
  ),
  const _Spec(
    ageH: 72,
    reporter: 1,
    category: ProblemCategory.electrical,
    title: 'Sparks from switchboard near lab bench',
    description:
        'The switchboard next to the third bench row sparked and there was '
        'a burning smell. We switched off the bench and stepped back.',
    building: 'Science & Computer Block',
    floor: 'Ground',
    room: 'Physics Lab',
    severity: Severity.severe,
    people: PeopleAffected.small,
    safety: true,
    beforePhotos: 2,
    status: ComplaintStatus.resolved,
    reviewH: 1,
    startH: 3,
    resolveH: 8,
    resolution:
        'Replaced the burnt switchboard, checked earthing and tested all '
        'sockets on the bench row.',
    afterPhotos: 2,
  ),
  const _Spec(
    ageH: 60,
    reporter: 1,
    category: ProblemCategory.it,
    title: 'Lab PCs not booting',
    description:
        'A row of PCs in the lab does not boot and shows a blue error '
        'screen. Our practical session could not be completed.',
    building: 'Science & Computer Block',
    floor: '1',
    room: 'Computer Lab 1',
    severity: Severity.moderate,
    people: PeopleAffected.small,
    status: ComplaintStatus.inProgress,
    reviewH: 2,
    reviewer: _Who.verifier2,
    startH: 4,
    resolveH: 16,
    resolution: 'Reinstalled the operating system image on the lab PCs.',
    rework: [
      _Rework(
        rejectH: 30,
        rejectBy: _Who.verifier1,
        note:
            'Five systems in the last row still do not boot. Please recheck '
            'every machine.',
      ),
    ],
  ),
  const _Spec(
    ageH: 50,
    reporter: 3,
    category: ProblemCategory.plumbing,
    title: 'Flush not working',
    description:
        'The flush in the washroom block does not work and the cistern '
        'keeps running. The whole floor uses this washroom.',
    building: 'Hostel Block B',
    floor: '1',
    room: 'Washroom Block',
    severity: Severity.minor,
    people: PeopleAffected.many,
    status: ComplaintStatus.resolved,
    reviewH: 3,
    reviewer: _Who.admin,
    reviewNote: 'Raising priority: the whole floor depends on this washroom.',
    priorityOverride: Priority.high,
    startH: 6,
    resolveH: 20,
    resolution: 'Cleared the blocked pipe and replaced the cistern valve.',
  ),
  const _Spec(
    ageH: 384,
    reporter: 2,
    category: ProblemCategory.plumbing,
    title: 'Water seeping through the ceiling',
    description:
        'Water drips through the ceiling of the seminar room whenever it '
        'rains and has left a stain on the wall. We keep a bucket underneath.',
    building: 'Academic Block A',
    floor: '3',
    room: 'Seminar Room 303',
    severity: Severity.minor,
    people: PeopleAffected.small,
    status: ComplaintStatus.inProgress,
    reviewH: 4,
    reviewer: _Who.verifier2,
    startH: 30,
    pullBack: _PullBack(
      atH: 90,
      department: Department.civilMaintenance,
      reason:
          'Seepage is coming from the roof slab, not the plumbing line. '
          'Moving to Civil Maintenance.',
      restartH: 120,
      worker: 1,
    ),
  ),
  const _Spec(
    ageH: 32,
    reporter: 5,
    category: ProblemCategory.it,
    title: 'ERP portal unreachable',
    description:
        'The campus ERP and exam registration portal cannot be opened from '
        'any lab or classroom since morning. Registration closes this week.',
    building: 'Science & Computer Block',
    floor: '1',
    room: 'Computer Lab 1',
    severity: Severity.severe,
    people: PeopleAffected.campusWide,
    status: ComplaintStatus.assigned,
    reviewH: 3,
    reviewer: _Who.admin,
    pick: 1,
  ),
  const _Spec(
    ageH: 30,
    reporter: 0,
    category: ProblemCategory.civil,
    title: 'Cracked window glass',
    description:
        'The window glass near the back of the classroom is cracked from '
        'corner to corner. It could shatter if the window is slammed.',
    building: 'Academic Block A',
    floor: '3',
    room: 'Classroom 301',
    severity: Severity.minor,
    people: PeopleAffected.small,
    status: ComplaintStatus.inProgress,
    reviewH: 2,
    startH: 10,
  ),
  const _Spec(
    ageH: 20,
    reporter: 6,
    category: ProblemCategory.safety,
    title: 'Slippery floor at cafeteria entrance',
    description:
        'The floor at the cafeteria entrance stays wet and slippery, and a '
        'couple of students have already slipped.',
    building: 'Cafeteria',
    floor: 'Ground',
    room: 'Dining Hall',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.inProgress,
    reviewH: 1,
    assignDepartment: Department.housekeeping,
    assignH: 2,
    startH: 4,
    worker: 1,
  ),
  const _Spec(
    ageH: 14,
    reporter: 4,
    category: ProblemCategory.electrical,
    title: 'Projector socket has no power',
    description:
        'The power socket for the projector in the seminar room is dead, so '
        'the projector cannot be switched on.',
    building: 'Academic Block A',
    floor: '3',
    room: 'Seminar Room 303',
    severity: Severity.minor,
    people: PeopleAffected.small,
    status: ComplaintStatus.assigned,
    reviewH: 2,
    reviewer: _Who.admin,
    reassign: _Reassign(
      atH: 6,
      department: Department.itTeam,
      reason: 'Fault is in the projector power adapter, not the wiring.',
    ),
  ),
  // ---- reviewed (manual triage) -------------------------------------------
  const _Spec(
    ageH: 10,
    reporter: 7,
    category: ProblemCategory.safety,
    title: 'Fire extinguisher missing',
    description:
        'The fire extinguisher bracket on this corridor is empty. The '
        'extinguisher has been missing since last week.',
    building: 'Academic Block A',
    floor: '2',
    room: 'Corridor',
    severity: Severity.moderate,
    people: PeopleAffected.individual,
    status: ComplaintStatus.reviewed,
    reviewH: 2,
  ),
  const _Spec(
    ageH: 7,
    reporter: 6,
    category: ProblemCategory.other,
    title: 'Stray dogs near the main gate',
    description:
        'A pack of stray dogs gathers near the main gate in the evening and '
        'students feel unsafe walking out.',
    building: 'Campus Grounds',
    floor: 'Outdoor / N.A.',
    room: 'Main Gate',
    severity: Severity.moderate,
    people: PeopleAffected.many,
    status: ComplaintStatus.reviewed,
    reviewH: 2,
    reviewer: _Who.verifier2,
  ),
  const _Spec(
    ageH: 5,
    reporter: 0,
    category: ProblemCategory.plumbing,
    title: 'Dripping tap',
    description:
        'The tap in the washroom near the stairs drips slowly all day.',
    building: 'Central Library',
    floor: '1',
    room: 'Washroom (near stairs)',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.reported,
  ),
  const _Spec(
    ageH: 3,
    reporter: 8,
    category: ProblemCategory.safety,
    title: 'Loose handrail on staircase',
    description:
        'The handrail on the staircase is completely loose and moves when '
        'you hold it. A student nearly fell this morning.',
    building: 'Academic Block B',
    floor: '2',
    room: 'Staircase',
    severity: Severity.severe,
    people: PeopleAffected.individual,
    beforePhotos: 2,
    status: ComplaintStatus.reviewed,
    reviewH: 1,
    reviewer: _Who.admin,
  ),
  // ---- reported -----------------------------------------------------------
  const _Spec(
    ageH: 2,
    reporter: 1,
    category: ProblemCategory.civil,
    title: 'Plaster falling from ceiling',
    description:
        'Pieces of plaster are falling from the ceiling in the corridor. A '
        'large chunk fell this morning right where students queue.',
    building: 'Administrative Building',
    floor: 'Ground',
    room: 'Admissions Office',
    severity: Severity.severe,
    people: PeopleAffected.many,
    safety: true,
    beforePhotos: 3,
    status: ComplaintStatus.reported,
  ),
  const _Spec(
    ageH: 50 / 60,
    reporter: 2,
    category: ProblemCategory.furniture,
    description:
        'The marker tray of the whiteboard is broken and markers keep '
        'falling on the floor.',
    building: 'Academic Block A',
    floor: '2',
    room: 'Classroom 202',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.reported,
  ),
  const _Spec(
    ageH: 40 / 60,
    reporter: 9,
    category: ProblemCategory.other,
    description:
        'The lock of the lost-and-found cabinet is jammed, so items cannot '
        'be returned to their owners.',
    building: 'Administrative Building',
    floor: 'Ground',
    room: 'Reception',
    severity: Severity.minor,
    people: PeopleAffected.individual,
    status: ComplaintStatus.reported,
  ),
];

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/// What an event meant, used to derive notifications (status-machine §5.1).
enum _Kind {
  created,
  review,
  assign,
  reassign,
  start,
  resolve,
  verify,
  close,
  reject,
  pullBack,
}

class _Emit {
  const _Emit(this.kind, this.event, {this.from, this.to});

  final _Kind kind;
  final StatusEvent event;

  /// Previous / new department for reassignments.
  final Department? from;
  final Department? to;
}

class _Draft {
  const _Draft(
    this.at,
    this.complaintId,
    this.recipientId,
    this.type,
    this.title,
    this.body,
    this.order,
  );

  final DateTime at;
  final String complaintId;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String body;

  /// Insertion order: keeps same-instant items (e.g. reviewed then assigned)
  /// in event order, since `List.sort` is not stable.
  final int order;
}

Duration _hours(double h) => Duration(minutes: (h * 60).round());

String _seqText(int seq) => seq.toString().padLeft(4, '0');

const Map<ProblemCategory, String> _photoPrefix = {
  ProblemCategory.electrical: 'elec',
  ProblemCategory.plumbing: 'plum',
  ProblemCategory.civil: 'civil',
  ProblemCategory.furniture: 'furn',
  ProblemCategory.cleanliness: 'clean',
  ProblemCategory.it: 'it',
  ProblemCategory.safety: 'safe',
  ProblemCategory.other: 'other',
};

class _SeedBuilder {
  _SeedBuilder(this.now);

  final DateTime now;

  final ComplaintIdGenerator _ids = ComplaintIdGenerator();
  final Map<ProblemCategory, int> _photoCounters = {};
  final List<_Draft> _drafts = [];

  AppUser _who(_Who who) => switch (who) {
    _Who.verifier1 => _verifiers[0],
    _Who.verifier2 => _verifiers[1],
    _Who.admin => _admin,
  };

  AppUser _staffOf(Department department, int index) =>
      _maintenance.where((u) => u.department == department).toList()[index];

  SeedData build() {
    final specs = [..._specs]..sort((a, b) => b.ageH.compareTo(a.ageH));
    final complaints = <Complaint>[];
    for (var i = 0; i < specs.length; i++) {
      complaints.add(_buildComplaint(specs[i], i + 1));
    }

    final sequences = <int, int>{};
    for (final c in complaints) {
      final m = complaintIdPattern.firstMatch(c.id)!;
      final year = int.parse(m.group(1)!);
      final seq = int.parse(m.group(2)!);
      if (seq > (sequences[year] ?? 0)) sequences[year] = seq;
    }

    _drafts.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      final byComplaint = a.complaintId.compareTo(b.complaintId);
      return byComplaint != 0 ? byComplaint : a.order.compareTo(b.order);
    });
    final notifications = [
      for (var i = 0; i < _drafts.length; i++)
        AppNotification(
          id: 'ntf-${(i + 1).toString().padLeft(4, '0')}',
          recipientId: _drafts[i].recipientId,
          complaintId: _drafts[i].complaintId,
          type: _drafts[i].type,
          title: _drafts[i].title,
          body: _drafts[i].body,
          createdAt: _drafts[i].at,
          read: now.difference(_drafts[i].at) > const Duration(hours: 36),
        ),
    ];

    final users = <AppUser>[
      for (final r in _reporters) r.user,
      ..._maintenance,
      ..._verifiers,
      _admin,
    ];
    final accounts = [
      for (final u in users) MockAccount(user: u, password: seedDemoPassword),
    ];
    final demoAccounts = [
      for (final u in [
        _reporters.first.user,
        _maintenance.first,
        _verifiers.first,
        _admin,
      ])
        MockAccount(user: u, password: seedDemoPassword),
    ];

    return SeedData._(
      now: now,
      users: List.unmodifiable(users),
      accounts: List.unmodifiable(accounts),
      demoAccounts: List.unmodifiable(demoAccounts),
      complaints: List.unmodifiable(complaints),
      notifications: List.unmodifiable(notifications),
      lastSequenceByYear: Map.unmodifiable(sequences),
    );
  }

  Complaint _buildComplaint(_Spec s, int seq) {
    final created = now.subtract(_hours(s.ageH));
    DateTime at(double h) => created.add(_hours(h));
    final id = _ids.next(created);
    final reporter = _reporters[s.reporter];
    final identity = ReporterIdentity(
      userId: reporter.user.id,
      fullName: reporter.user.displayName,
      idNumber: reporter.user.idNumber,
      email: reporter.user.email,
      phone: reporter.phone,
    );
    final safetyFlag = s.safety || s.category == ProblemCategory.safety;
    final target = s.status;
    bool reached(ComplaintStatus st) => target.order >= st.order;

    final events = <StatusEvent>[];
    final emits = <_Emit>[];
    var status = ComplaintStatus.reported;

    void add(
      _Kind kind,
      ComplaintStatus st,
      AppUser actor,
      DateTime when, {
      String? note,
      Department? from,
      Department? to,
    }) {
      if (events.isNotEmpty && when.isBefore(events.last.at)) {
        throw StateError('Seed $id: event times go backwards at $kind.');
      }
      if (when.isAfter(now)) {
        throw StateError('Seed $id: event at $kind is in the future.');
      }
      final event = StatusEvent(
        id: 'ev-${_seqText(seq)}-${(events.length + 1).toString().padLeft(2, '0')}',
        status: st,
        actorId: actor.id,
        actorRole: actor.role,
        note: note,
        at: when,
      );
      events.add(event);
      emits.add(_Emit(kind, event, from: from, to: to));
      status = st;
    }

    // Photos.
    final catNo = (_photoCounters[s.category] =
        (_photoCounters[s.category] ?? 0) + 1);
    final stem =
        '${_photoPrefix[s.category]}_${catNo.toString().padLeft(2, '0')}';
    final beforePhotos = [
      for (var i = 1; i <= s.beforePhotos; i++)
        Attachment(
          id: 'att-${_seqText(seq)}-b$i',
          kind: AttachmentKind.beforePhoto,
          ref: 'assets/seed/${stem}_before${i == 1 ? '' : '_$i'}.jpg',
          caption: i == 1 ? 'Problem location' : null,
          createdAt: created,
        ),
    ];
    final afterPhotos = <Attachment>[];
    void addAfterPhotos(int count, DateTime resolvedAt) {
      for (var i = 0; i < count; i++) {
        final n = afterPhotos.length + 1;
        afterPhotos.add(
          Attachment(
            id: 'att-${_seqText(seq)}-a$n',
            kind: AttachmentKind.afterPhoto,
            ref: 'assets/seed/${stem}_after${n == 1 ? '' : '_$n'}.jpg',
            caption: i == 0 ? 'After repair' : null,
            createdAt: resolvedAt.subtract(Duration(minutes: 15 - i)),
          ),
        );
      }
    }

    // T0: creation (not a transition).
    add(_Kind.created, ComplaintStatus.reported, reporter.user, created);

    Assignment? assignment;
    Priority? override;
    String? resolutionNote;

    // T1 (+ auto T2): Review & Route.
    if (reached(ComplaintStatus.reviewed)) {
      final reviewer = _who(s.reviewer);
      final t = at(s.reviewH!);
      add(
        _Kind.review,
        ComplaintStatus.reviewed,
        reviewer,
        t,
        note: s.reviewNote,
      );
      if (s.reviewer == _Who.admin) override = s.priorityOverride;

      final route = routeToDepartment(s.category);
      if (route != null) {
        // Auto-routable: Review & Route is atomic (INV-2).
        final dept = s.assignDepartment ?? route;
        final manual = isManualAssignment(s.category, dept);
        if (manual && reviewer.role != UserRole.admin) {
          throw StateError('Seed $id: only an admin may route manually.');
        }
        if (s.pick != null && reviewer.role != UserRole.admin) {
          throw StateError('Seed $id: only an admin may pick an assignee.');
        }
        assignment = Assignment(
          department: dept,
          assigneeId: s.pick == null ? null : _staffOf(dept, s.pick!).id,
          assignedBy: reviewer.id,
          assignedAt: t,
          isManual: manual,
        );
        add(
          _Kind.assign,
          ComplaintStatus.assigned,
          reviewer,
          t,
          note: manual
              ? (s.assignNote ?? 'Assigned to ${dept.label}')
              : 'Auto-routed to ${dept.label}',
          to: dept,
        );
      } else if (reached(ComplaintStatus.assigned)) {
        // safety / other: only an admin can assign (P5).
        final dept = s.assignDepartment!;
        final t2 = at(s.assignH!);
        assignment = Assignment(
          department: dept,
          assigneeId: s.pick == null ? null : _staffOf(dept, s.pick!).id,
          assignedBy: _admin.id,
          assignedAt: t2,
          isManual: isManualAssignment(s.category, dept),
        );
        add(
          _Kind.assign,
          ComplaintStatus.assigned,
          _admin,
          t2,
          note: s.assignNote ?? 'Assigned to ${dept.label}',
          to: dept,
        );
      }
    }

    // Reassignment while still `assigned` (annotation event, not a transition).
    if (s.reassign != null) {
      if (target != ComplaintStatus.assigned) {
        throw StateError(
          'Seed $id: annotation reassign needs status assigned.',
        );
      }
      final r = s.reassign!;
      final old = assignment!.department;
      final t = at(r.atH);
      assignment = Assignment(
        department: r.department,
        assignedBy: _admin.id,
        assignedAt: t,
        isManual: isManualAssignment(s.category, r.department),
      );
      add(
        _Kind.reassign,
        ComplaintStatus.assigned,
        _admin,
        t,
        note: 'Reassigned: ${old.label} -> ${r.department.label} — ${r.reason}',
        from: old,
        to: r.department,
      );
    }

    // T3: a department member starts (claims) the work.
    AppUser? worker;
    if (reached(ComplaintStatus.inProgress)) {
      worker = _staffOf(assignment!.department, s.worker);
      if (s.pick != null && s.pick != s.worker) {
        throw StateError('Seed $id: the picked assignee must start the work.');
      }
      assignment = assignment.copyWith(assigneeId: worker.id);
      add(_Kind.start, ComplaintStatus.inProgress, worker, at(s.startH!));

      // T8: admin pull-back to another department, then restart.
      final pb = s.pullBack;
      if (pb != null) {
        final old = assignment.department;
        final t = at(pb.atH);
        assignment = Assignment(
          department: pb.department,
          assignedBy: _admin.id,
          assignedAt: t,
          isManual: isManualAssignment(s.category, pb.department),
        );
        add(
          _Kind.pullBack,
          ComplaintStatus.assigned,
          _admin,
          t,
          note: pb.reason,
          from: old,
          to: pb.department,
        );
        worker = _staffOf(pb.department, pb.worker);
        assignment = assignment.copyWith(assigneeId: worker.id);
        add(_Kind.start, ComplaintStatus.inProgress, worker, at(pb.restartH));
      }
    }

    // T4 (and any T7 -> T4 rework loops).
    if (reached(ComplaintStatus.resolved) || s.rework.isNotEmpty) {
      final t = at(s.resolveH!);
      addAfterPhotos(s.afterPhotos, t);
      resolutionNote = s.resolution;
      add(
        _Kind.resolve,
        ComplaintStatus.resolved,
        worker!,
        t,
        note: s.resolution,
      );
      for (final rw in s.rework) {
        add(
          _Kind.reject,
          ComplaintStatus.inProgress,
          _who(rw.rejectBy),
          at(rw.rejectH),
          note: rw.note,
        );
        if (rw.resolveH != null) {
          final t2 = at(rw.resolveH!);
          addAfterPhotos(1, t2);
          resolutionNote = rw.resolution;
          add(
            _Kind.resolve,
            ComplaintStatus.resolved,
            worker,
            t2,
            note: rw.resolution,
          );
        }
      }
    }

    // T5 / T6.
    if (reached(ComplaintStatus.verified)) {
      add(
        _Kind.verify,
        ComplaintStatus.verified,
        _who(s.verifier),
        at(s.verifyH!),
      );
    }
    if (reached(ComplaintStatus.closed)) {
      add(_Kind.close, ComplaintStatus.closed, _admin, at(s.closeH!));
    }

    if (status != target) {
      throw StateError('Seed $id: ended in $status, expected $target.');
    }

    // Priority (priority-engine-spec §6): unresolved complaints are
    // recomputed on read with the aged waiting time; resolved / verified /
    // closed ones are frozen at the last recompute (the last event that left
    // the complaint unresolved).
    final Duration waiting;
    if (status.order < ComplaintStatus.resolved.order) {
      waiting = now.difference(created);
    } else {
      waiting = events
          .lastWhere((e) => e.status.order < ComplaintStatus.resolved.order)
          .at
          .difference(created);
    }
    final priority = computePriority(
      PriorityInputs(
        category: s.category,
        safetyFlag: safetyFlag,
        severity: s.severity,
        peopleAffected: s.people,
        waitingTime: waiting,
      ),
    );

    final complaint = Complaint(
      id: id,
      category: s.category,
      title: s.title,
      description: s.description,
      building: s.building,
      floor: s.floor,
      room: s.room,
      reporter: identity,
      beforePhotos: beforePhotos,
      afterPhotos: afterPhotos,
      priority: priority,
      priorityOverride: override,
      status: status,
      assignment: assignment,
      timeline: events,
      resolutionNote: resolutionNote,
      safetyFlag: safetyFlag,
      severity: s.severity,
      peopleAffected: s.people,
      createdAt: created,
      updatedAt: events.last.at,
    );
    for (final e in emits) {
      _notify(complaint, e);
    }
    return complaint;
  }

  // -------------------------------------------------------------------------
  // Notifications (status-machine-spec §5.1; messages are PII-free, LK-1).
  // Admins have no mobile notification feed in v1, so only the owner, the
  // department's staff and the verifiers receive items.
  // -------------------------------------------------------------------------

  void _notify(Complaint c, _Emit e) {
    final owner = c.reporter.userId;
    final id = c.id;
    final at = e.event.at;

    void send(
      Iterable<String> recipients,
      NotificationType type,
      String title,
      String body,
    ) {
      for (final r in recipients) {
        _drafts.add(_Draft(at, id, r, type, title, body, _drafts.length));
      }
    }

    Iterable<String> deptStaff(Department d) => [
      for (final u in _maintenance)
        if (u.department == d) u.id,
    ];
    final verifiers = [for (final v in _verifiers) v.id];
    final where = '${c.building}, ${_floorLabel(c.floor)}, ${c.room}';
    String newWork() => 'New work: $id — ${c.category.label}, $where.';

    switch (e.kind) {
      case _Kind.created:
        send(
          [owner],
          NotificationType.submission,
          'Complaint submitted',
          'Complaint $id submitted.',
        );
      case _Kind.review:
        send(
          [owner],
          NotificationType.statusChange,
          'Complaint reviewed',
          '$id has been reviewed.',
        );
      case _Kind.assign:
        send(
          [owner],
          NotificationType.assignment,
          'Complaint assigned',
          '$id assigned to ${e.to!.label}.',
        );
        send(
          deptStaff(e.to!),
          NotificationType.assignment,
          'New work assigned',
          newWork(),
        );
      case _Kind.reassign:
      case _Kind.pullBack:
        send(
          [owner],
          NotificationType.assignment,
          'Complaint reassigned',
          '$id reassigned to ${e.to!.label}.',
        );
        send(
          deptStaff(e.from!),
          NotificationType.statusChange,
          'Removed from your queue',
          '$id removed from your queue.',
        );
        send(
          deptStaff(e.to!),
          NotificationType.assignment,
          'New work assigned',
          newWork(),
        );
      case _Kind.start:
        send(
          [owner],
          NotificationType.statusChange,
          'Work started',
          'Work has started on $id.',
        );
      case _Kind.resolve:
        send(
          [owner],
          NotificationType.completion,
          'Repair completed',
          'Repair completed on $id; awaiting verification.',
        );
        send(
          verifiers,
          NotificationType.completion,
          'Ready to verify',
          '$id is ready to verify.',
        );
      case _Kind.verify:
        send(
          [owner],
          NotificationType.statusChange,
          'Repair verified',
          '$id repair verified.',
        );
        send(
          deptStaff(c.assignment!.department),
          NotificationType.statusChange,
          'Repair verified',
          '$id repair verified.',
        );
      case _Kind.close:
        send(
          [owner],
          NotificationType.closure,
          'Complaint closed',
          '$id is closed.',
        );
      case _Kind.reject:
        send(
          deptStaff(c.assignment!.department),
          NotificationType.statusChange,
          'Rework needed',
          'Rework needed on $id: ${_sentence(e.event.note!)}',
        );
        send(
          [owner],
          NotificationType.statusChange,
          'Work resumed',
          '$id needs more work; work resumed.',
        );
    }
  }
}

/// `"Floor 2"` for numeric floors, `"Ground floor"` for ground, otherwise the
/// floor name as is.
String _floorLabel(String floor) {
  if (int.tryParse(floor) != null) return 'Floor $floor';
  if (floor == 'Ground') return 'Ground floor';
  return floor;
}

/// [text] with a closing full stop unless it already ends in `.`, `!` or `?`.
String _sentence(String text) {
  final t = text.trim();
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
