import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';

import 'pump_app.dart';

/// Seed complaints re-purposed as the demo maintenance worker's work. The stock
/// seed gives that account a small queue of its own (and whichever worker the
/// demo login points at can change), so [workSeed] re-homes the fixtures below
/// into the demo worker's department and moves any other open job of that
/// department out of the way. The queue shape is then the same for any demo
/// worker.
///
/// To start (two, sorted priority then oldest first): [toStartA], [toStartB].
/// In progress: [inProgressJob]. Rework: [reworkJob].
/// Not the demo user's: [colleagueInProgress] (claimed by [colleagueId]),
/// [assignedToColleague] (`assigned` to [colleagueId]).
const String toStartA = 'CF-2026-00014';
const String toStartB = 'CF-2026-00010';
const String inProgressJob = 'CF-2026-00020';
const String reworkJob = 'CF-2026-00017';
const String colleagueInProgress = 'CF-2026-00011';
const String assignedToColleague = 'CF-2026-00019';

/// A plumber's job in the seed: never visible to the demo worker (AC-33).
/// ([workSeed] keeps it in a department the demo worker is not in.)
const String plumberJob = 'CF-2026-00018';

/// The demo maintenance worker (the account behind the Maintenance quick-fill).
String get meId => demoAccount(UserRole.maintenance).user.id;

/// The demo worker's department, and its human-readable name as the app shows
/// it (for example in `No work assigned to <department>`).
Department get meDepartment =>
    demoAccount(UserRole.maintenance).user.department!;
String get meDepartmentLabel => meDepartment.label;

/// The other maintenance worker of the demo worker's department.
String get colleagueId => testSeed.users
    .firstWhere(
      (AppUser u) =>
          u.role == UserRole.maintenance &&
          u.department == meDepartment &&
          u.id != meId,
    )
    .id;

/// A problem category routed to [meDepartment] by default.
ProblemCategory get _meCategory => ProblemCategory.values.firstWhere(
  (ProblemCategory c) => c.defaultDepartment == meDepartment,
);

/// A department the demo worker is not in.
Department get _otherDepartment => meDepartment == Department.plumber
    ? Department.electrician
    : Department.plumber;

Complaint _rehomed(
  Complaint c,
  Department department, {
  ProblemCategory? category,
  String? assigneeId,
}) => c.copyWith(
  category: category,
  assignment: c.assignment!.copyWith(
    department: department,
    assigneeId: assigneeId,
    clearAssigneeId: assigneeId == null,
  ),
);

/// The whole seed with the demo worker's fixtures swapped in.
List<Complaint> workSeed() {
  Complaint byId(String id) =>
      testSeed.complaints.firstWhere((Complaint c) => c.id == id);
  Complaint mine(String id, {String? assigneeId}) => _rehomed(
    byId(id),
    meDepartment,
    category: _meCategory,
    assigneeId: assigneeId,
  );

  final Map<String, Complaint> swapped = <String, Complaint>{
    toStartA: mine(toStartA),
    toStartB: mine(toStartB),
    inProgressJob: mine(inProgressJob, assigneeId: meId),
    reworkJob: mine(reworkJob, assigneeId: meId),
    colleagueInProgress: mine(colleagueInProgress, assigneeId: colleagueId),
    assignedToColleague: mine(assignedToColleague, assigneeId: colleagueId),
    plumberJob: _rehomed(
      byId(plumberJob),
      _otherDepartment,
      assigneeId: byId(plumberJob).assignment!.assigneeId,
    ),
  };
  return <Complaint>[
    for (final Complaint c in testSeed.complaints)
      swapped[c.id] ?? _clearedOfOpenWork(c),
  ];
}

/// [c], moved out of the demo worker's department when it is open work there
/// (`assigned` or `inProgress`), so that only the fixtures above make up the
/// queue. Everything else is returned unchanged.
Complaint _clearedOfOpenWork(Complaint c) {
  final Assignment? a = c.assignment;
  final bool open =
      c.status == ComplaintStatus.assigned ||
      c.status == ComplaintStatus.inProgress;
  if (a == null || a.department != meDepartment || !open) return c;
  return _rehomed(c, _otherDepartment, assigneeId: a.assigneeId);
}

/// A repository holding [workSeed].
MockComplaintRepository workRepository() =>
    MockComplaintRepository(initial: workSeed());

/// A [MockComplaintRepository] whose first [failures] writes throw (a failed
/// Start work / Mark resolved), after which it behaves normally.
class FlakyWriteComplaintRepository extends MockComplaintRepository {
  FlakyWriteComplaintRepository({required super.initial, this.failures = 1});

  int failures;

  @override
  Future<Complaint> update(Complaint c) async {
    if (failures > 0) {
      failures--;
      throw StateError('simulated outage');
    }
    return super.update(c);
  }
}

/// A repository whose writes wait until [release] is called (an action stays
/// in flight, to show the in-progress state and the double-submit guard).
class SlowWriteComplaintRepository extends MockComplaintRepository {
  SlowWriteComplaintRepository({required super.initial});

  final Completer<void> gate = Completer<void>();
  int writes = 0;

  void release() => gate.complete();

  @override
  Future<Complaint> update(Complaint c) async {
    writes++;
    await gate.future;
    return super.update(c);
  }
}
