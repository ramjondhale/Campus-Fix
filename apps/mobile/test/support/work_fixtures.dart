import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';

import 'pump_app.dart';

/// Seed complaints re-purposed as the demo electrician's (u-mnt-ele-01) work,
/// because the stock seed gives that account an empty queue. Everything else in
/// the seed (other departments, a colleague's claim) stays as it is.
///
/// To start (two, sorted priority then oldest first): [toStartA], [toStartB].
/// In progress: [inProgressJob]. Rework: [reworkJob].
/// Not the demo user's: [colleagueInProgress] (claimed by u-mnt-ele-02),
/// [assignedToColleague] (`assigned` to u-mnt-ele-02).
const String toStartA = 'CF-2026-00014';
const String toStartB = 'CF-2026-00010';
const String inProgressJob = 'CF-2026-00020';
const String reworkJob = 'CF-2026-00017';
const String colleagueInProgress = 'CF-2026-00011';
const String assignedToColleague = 'CF-2026-00019';

/// A plumber's job in the seed: never visible to the electrician (AC-33).
const String plumberJob = 'CF-2026-00018';

/// The demo electrician and a colleague of the same department.
String get meId => demoAccount(UserRole.maintenance).user.id;
const String colleagueId = 'u-mnt-ele-02';

Complaint _asElectrician(String seedId, {String? assigneeId}) {
  final Complaint c = testSeed.complaints.firstWhere((c) => c.id == seedId);
  return c.copyWith(
    category: ProblemCategory.electrical,
    assignment: c.assignment!.copyWith(
      department: Department.electrician,
      assigneeId: assigneeId,
      clearAssigneeId: assigneeId == null,
    ),
  );
}

/// The whole seed with the electrician fixtures swapped in.
List<Complaint> workSeed() {
  final Map<String, Complaint> swapped = <String, Complaint>{
    toStartA: _asElectrician(toStartA),
    toStartB: _asElectrician(toStartB),
    inProgressJob: _asElectrician(inProgressJob, assigneeId: meId),
    reworkJob: _asElectrician(reworkJob, assigneeId: meId),
    assignedToColleague: _asElectrician(
      assignedToColleague,
      assigneeId: colleagueId,
    ),
  };
  return <Complaint>[
    for (final Complaint c in testSeed.complaints) swapped[c.id] ?? c,
  ];
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
