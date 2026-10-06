import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

// ---------------------------------------------------------------------------
// Aliases
// ---------------------------------------------------------------------------

const reported = ComplaintStatus.reported;
const reviewed = ComplaintStatus.reviewed;
const assigned = ComplaintStatus.assigned;
const inProgress = ComplaintStatus.inProgress;
const resolved = ComplaintStatus.resolved;
const verified = ComplaintStatus.verified;
const closed = ComplaintStatus.closed;

const maintenance = UserRole.maintenance;
const verifier = UserRole.verifier;
const admin = UserRole.admin;
// `reporter` is the ReporterIdentity fixture, so the role is spelled out.
const reporterRole = UserRole.reporter;

typedef Tuple = (ComplaintStatus, ComplaintStatus, UserRole);

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

const reporterUser = AppUser(
  id: 'u-100',
  idNumber: 'S2024-0042',
  displayName: 'Asha',
  role: UserRole.reporter,
  email: 'asha@campus.edu',
);
const elecA = AppUser(
  id: 'm-1',
  idNumber: 'E-1',
  displayName: 'Electrician A',
  role: UserRole.maintenance,
  email: 'ea@campus.edu',
  department: Department.electrician,
);
const plumberC = AppUser(
  id: 'm-3',
  idNumber: 'P-1',
  displayName: 'Plumber C',
  role: UserRole.maintenance,
  email: 'pc@campus.edu',
  department: Department.plumber,
);
const verifierUser = AppUser(
  id: 'v-1',
  idNumber: 'V-1',
  displayName: 'Verifier',
  role: UserRole.verifier,
  email: 'v@campus.edu',
);
const adminUser = AppUser(
  id: 'a-1',
  idNumber: 'A-1',
  displayName: 'Admin',
  role: UserRole.admin,
  email: 'a@campus.edu',
);

/// One user per role, for loops.
const userByRole = <UserRole, AppUser>{
  UserRole.reporter: reporterUser,
  UserRole.maintenance: elecA,
  UserRole.verifier: verifierUser,
  UserRole.admin: adminUser,
};

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

Attachment photo(
  String id,
  DateTime at, {
  AttachmentKind kind = AttachmentKind.afterPhoto,
}) => Attachment(id: id, kind: kind, ref: 'assets/mock/$id.jpg', createdAt: at);

/// An after-photo comfortably newer than `t0` (the complaint's creation).
final freshPhoto = photo('fresh', t0.add(const Duration(days: 3)));

Assignment elecAssignment({
  String by = 'v-1',
  String? assigneeId,
  bool isManual = false,
}) => Assignment(
  department: Department.electrician,
  assigneeId: assigneeId,
  assignedBy: by,
  assignedAt: t0.add(const Duration(hours: 2)),
  isManual: isManual,
);

StatusEvent ev(
  String id,
  ComplaintStatus status,
  DateTime at, {
  UserRole role = UserRole.admin,
  String? note,
}) => StatusEvent(
  id: id,
  status: status,
  actorId: 'x',
  actorRole: role,
  note: note,
  at: at,
);

/// A complaint in [status] (no timeline unless given).
Complaint build(
  ComplaintStatus status, {
  ProblemCategory category = ProblemCategory.electrical,
  Assignment? assignment,
  List<Attachment> afterPhotos = const [],
  String? resolutionNote,
  List<StatusEvent>? timeline,
}) => minimalComplaint().copyWith(
  category: category,
  status: status,
  assignment: assignment,
  afterPhotos: afterPhotos,
  resolutionNote: resolutionNote,
  timeline: timeline,
);

TransitionRequest rq(
  ComplaintStatus expectedFrom, {
  String? note,
  String? resolutionNote,
  List<Attachment> afterPhotos = const [],
  Assignment? assignment,
  Priority? priorityOverride,
}) => TransitionRequest(
  expectedFrom: expectedFrom,
  note: note,
  resolutionNote: resolutionNote,
  afterPhotos: afterPhotos,
  assignment: assignment,
  priorityOverride: priorityOverride,
);

ValidationResult validate(
  Complaint c,
  ComplaintStatus to,
  AppUser actor,
  TransitionRequest req,
) => StatusMachine.validateTransition(c, to, actor, req);

String longNote(int length) => 'x' * length;

// ---------------------------------------------------------------------------
// The 15 legal (from, to, role) tuples (spec §2 / §3)
// ---------------------------------------------------------------------------

final Set<Tuple> legalTuples = {
  // T1
  (reported, reviewed, verifier), (reported, reviewed, admin),
  // T2
  (reviewed, assigned, verifier), (reviewed, assigned, admin),
  // T3
  (assigned, inProgress, maintenance), (assigned, inProgress, admin),
  // T4
  (inProgress, resolved, maintenance), (inProgress, resolved, admin),
  // T5
  (resolved, verified, verifier), (resolved, verified, admin),
  // T6
  (verified, closed, verifier), (verified, closed, admin),
  // T7
  (resolved, inProgress, verifier), (resolved, inProgress, admin),
  // T8
  (inProgress, assigned, admin),
};

/// A valid single-step attempt used by positives and by derived negatives.
class Scenario {
  const Scenario(this.name, this.complaint, this.to, this.actor, this.request);
  final String name;
  final Complaint complaint;
  final ComplaintStatus to;
  final AppUser actor;
  final TransitionRequest request;

  Tuple get tuple => (complaint.status, to, actor.role);
}

/// One passing scenario for each of the 15 legal (edge, role) pairs.
List<Scenario> legalScenarios() {
  final unclaimed = elecAssignment();
  final claimed = elecAssignment(assigneeId: 'm-1');
  final inProgressC = build(inProgress, assignment: claimed);
  final resolvedC = build(
    resolved,
    assignment: claimed,
    afterPhotos: [freshPhoto],
    resolutionNote: 'Socket replaced',
  );
  final resolveReq = rq(
    inProgress,
    resolutionNote: 'Socket replaced',
    afterPhotos: [freshPhoto],
  );
  final autoRoute = elecAssignment(by: 'v-1');
  final manualByAdmin = Assignment(
    department: Department.civilMaintenance,
    assignedBy: 'a-1',
    assignedAt: t0.add(const Duration(hours: 2)),
    isManual: true,
  );
  final pullBack = Assignment(
    department: Department.itTeam,
    assignedBy: 'a-1',
    assignedAt: t0.add(const Duration(days: 1)),
    isManual: true,
  );
  return [
    // T1
    Scenario(
      'T1 verifier',
      build(reported),
      reviewed,
      verifierUser,
      rq(reported),
    ),
    Scenario(
      'T1 admin (with override)',
      build(reported),
      reviewed,
      adminUser,
      rq(reported, priorityOverride: Priority.high, note: 'Looks urgent'),
    ),
    // T2
    Scenario(
      'T2 verifier accepts auto-route',
      build(reviewed),
      assigned,
      verifierUser,
      rq(reviewed, assignment: autoRoute, note: 'Auto-routed to Electrician'),
    ),
    Scenario(
      'T2 admin manual on a manual-triage category',
      build(reviewed, category: ProblemCategory.safety),
      assigned,
      adminUser,
      rq(reviewed, assignment: manualByAdmin),
    ),
    // T3
    Scenario(
      'T3 maintenance claims',
      build(assigned, assignment: unclaimed),
      inProgress,
      elecA,
      rq(assigned),
    ),
    Scenario(
      'T3 admin on behalf',
      build(assigned, assignment: unclaimed),
      inProgress,
      adminUser,
      rq(assigned),
    ),
    // T4
    Scenario('T4 maintenance', inProgressC, resolved, elecA, resolveReq),
    Scenario(
      'T4 admin on behalf',
      inProgressC,
      resolved,
      adminUser,
      resolveReq,
    ),
    // T5
    Scenario('T5 verifier', resolvedC, verified, verifierUser, rq(resolved)),
    Scenario('T5 admin', resolvedC, verified, adminUser, rq(resolved)),
    // T6
    Scenario(
      'T6 verifier',
      build(verified, assignment: claimed),
      closed,
      verifierUser,
      rq(verified),
    ),
    Scenario(
      'T6 admin',
      build(verified, assignment: claimed),
      closed,
      adminUser,
      rq(verified),
    ),
    // T7
    Scenario(
      'T7 verifier rejects',
      resolvedC,
      inProgress,
      verifierUser,
      rq(resolved, note: 'Still sparking'),
    ),
    Scenario(
      'T7 admin rejects',
      resolvedC,
      inProgress,
      adminUser,
      rq(resolved, note: 'Still sparking'),
    ),
    // T8
    Scenario(
      'T8 admin pull-back',
      inProgressC,
      assigned,
      adminUser,
      rq(inProgress, note: 'Wrong team', assignment: pullBack),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Test-only L3 executor: just enough to replay sequences and check §7.
// ---------------------------------------------------------------------------

/// Validates, then applies a single transition the way ComplaintService
/// (S2.7) will: status, updatedAt, one appended event, and the §2 side
/// effects that matter to validation (assignment, claim, after-photos, note).
({Complaint? result, ValidationResult validation}) tryApply(
  Complaint c,
  ComplaintStatus to,
  AppUser actor, {
  required DateTime at,
  String? note,
  String? resolutionNote,
  List<Attachment> afterPhotos = const [],
  Assignment? assignment,
}) {
  final req = rq(
    c.status,
    note: note,
    resolutionNote: resolutionNote,
    afterPhotos: afterPhotos,
    assignment: assignment,
  );
  final validation = validate(c, to, actor, req);
  if (!validation.ok) return (result: null, validation: validation);

  var nextAssignment = c.assignment;
  var photos = c.afterPhotos;
  var resNote = c.resolutionNote;
  switch ((c.status, to)) {
    case (reviewed, assigned) || (inProgress, assigned):
      nextAssignment = assignment;
    case (assigned, inProgress):
      if (actor.role == maintenance && nextAssignment!.assigneeId == null) {
        nextAssignment = nextAssignment.copyWith(assigneeId: actor.id);
      }
    case (inProgress, resolved):
      resNote = resolutionNote ?? resNote;
      photos = [...photos, ...afterPhotos];
      if (actor.role == maintenance && nextAssignment!.assigneeId == null) {
        nextAssignment = nextAssignment.copyWith(assigneeId: actor.id);
      }
    default:
      break;
  }

  final event = StatusEvent(
    id: 'e-${c.timeline.length}',
    status: to,
    actorId: actor.id,
    actorRole: actor.role,
    note: to == resolved ? resolutionNote : note,
    at: at,
  );
  final next = c.copyWith(
    status: to,
    updatedAt: at,
    timeline: [...c.timeline, event],
    assignment: nextAssignment,
    afterPhotos: photos,
    resolutionNote: resNote,
  );
  return (result: next, validation: validation);
}

/// [tryApply] that fails the test with the blockers when validation fails.
Complaint apply(
  Complaint c,
  ComplaintStatus to,
  AppUser actor, {
  required DateTime at,
  String? note,
  String? resolutionNote,
  List<Attachment> afterPhotos = const [],
  Assignment? assignment,
}) {
  final out = tryApply(
    c,
    to,
    actor,
    at: at,
    note: note,
    resolutionNote: resolutionNote,
    afterPhotos: afterPhotos,
    assignment: assignment,
  );
  expect(
    out.validation.ok,
    isTrue,
    reason:
        '${c.status.name} -> ${to.name} by ${actor.role.name}: '
        '${out.validation.blockers}',
  );
  return out.result!;
}

/// A freshly submitted complaint: status `reported`, creation event only.
Complaint submitted({ProblemCategory category = ProblemCategory.electrical}) =>
    minimalComplaint().copyWith(
      category: category,
      timeline: [
        StatusEvent(
          id: 'e-0',
          status: reported,
          actorId: reporter.userId,
          actorRole: reporterRole,
          at: t0,
        ),
      ],
    );

/// Review & Route (T1, then T2 when the category is auto-routable).
Complaint reviewAndRoute(Complaint c, AppUser actor, {required DateTime at}) {
  final reviewedC = apply(c, reviewed, actor, at: at);
  final route = reviewedC.category.defaultDepartment;
  if (route == null) return reviewedC;
  return apply(
    reviewedC,
    assigned,
    actor,
    at: at,
    note: 'Auto-routed to ${route.label}',
    assignment: Assignment(
      department: route,
      assignedBy: actor.id,
      assignedAt: at,
      isManual: false,
    ),
  );
}

/// Start of the current repair cycle, computed independently of the
/// implementation (last reject event, else creation).
DateTime cycleStartOf(Complaint c) {
  var start = c.createdAt;
  for (var i = 1; i < c.timeline.length; i++) {
    if (c.timeline[i - 1].status == resolved &&
        c.timeline[i].status == inProgress) {
      start = c.timeline[i].at;
    }
  }
  return start;
}

/// Asserts the §7 invariants that are checkable on a complaint at rest.
void expectInvariants(Complaint c) {
  final s = c.status;

  // INV-1
  if (s.order >= assigned.order) {
    expect(c.assignment, isNotNull, reason: 'INV-1 ($s)');
  }
  // INV-2
  if (s == reviewed) {
    expect(c.category.defaultDepartment, isNull, reason: 'INV-2');
  }
  // INV-3
  if (s.order >= resolved.order) {
    final start = cycleStartOf(c);
    expect(
      c.afterPhotos.any(
        (p) =>
            p.kind == AttachmentKind.afterPhoto && p.createdAt.isAfter(start),
      ),
      isTrue,
      reason: 'INV-3 fresh after-photo ($s)',
    );
    expect(
      (c.resolutionNote ?? '').trim(),
      isNotEmpty,
      reason: 'INV-3 note ($s)',
    );
  }
  // INV-4: closed accepts no transition, for any actor and target.
  if (s == closed) {
    for (final role in UserRole.values) {
      for (final to in ComplaintStatus.values) {
        expect(
          validate(c, to, userByRole[role]!, rq(closed)).ok,
          isFalse,
          reason: 'INV-4 closed -> ${to.name} by ${role.name}',
        );
      }
    }
  }

  final tl = c.timeline;
  // TL-1
  expect(tl.first.status, reported, reason: 'TL-1');
  expect(tl.first.actorRole, reporterRole, reason: 'TL-1');
  expect(tl.first.at, c.createdAt, reason: 'TL-1');
  // TL-4
  expect(tl.last.status, s, reason: 'TL-4');
  expect(c.updatedAt, tl.last.at, reason: 'TL-4');

  for (var i = 1; i < tl.length; i++) {
    final prev = tl[i - 1];
    final next = tl[i];
    // TL-2
    expect(next.at.isBefore(prev.at), isFalse, reason: 'TL-2 at index $i');
    if (next.status == prev.status) continue; // annotation event
    // TL-3
    expect(
      StatusMachine.canTransition(prev.status, next.status, next.actorRole),
      isTrue,
      reason:
          'TL-3 ${prev.status.name} -> ${next.status.name} '
          'by ${next.actorRole.name}',
    );
    // TL-6 / TL-7
    final backward = next.status.order < prev.status.order;
    final isReject = prev.status == resolved && next.status == inProgress;
    final isPullBack = prev.status == inProgress && next.status == assigned;
    if (backward) {
      expect(isReject || isPullBack, isTrue, reason: 'TL-6 at index $i');
    }
    if (isReject || isPullBack) {
      expect((next.note ?? '').trim(), isNotEmpty, reason: 'TL-7 at index $i');
    }
  }
  // TL-5
  if (s == closed) {
    final statuses = [for (final e in tl) e.status];
    final r = statuses.indexOf(resolved);
    final v = statuses.indexOf(verified);
    final cl = statuses.indexOf(closed);
    expect(r, greaterThanOrEqualTo(0), reason: 'TL-5');
    expect(v, greaterThan(r), reason: 'TL-5');
    expect(cl, greaterThan(v), reason: 'TL-5');
  }
}

DateTime hours(int h) => t0.add(Duration(hours: h));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('L1 exhaustive (spec 6.1)', () {
    test('legal set has exactly 15 tuples out of 196', () {
      final all = [
        for (final f in ComplaintStatus.values)
          for (final t in ComplaintStatus.values)
            for (final r in UserRole.values) (f, t, r),
      ];
      expect(all, hasLength(196));
      expect(legalTuples, hasLength(15));
      expect(all.where(legalTuples.contains), hasLength(15));
      expect(
        all.where((t) => StatusMachine.canTransition(t.$1, t.$2, t.$3)),
        hasLength(15),
      );
    });

    for (final from in ComplaintStatus.values) {
      test('canTransition from ${from.name} matches the matrix for all '
          '(to, role)', () {
        for (final to in ComplaintStatus.values) {
          for (final role in UserRole.values) {
            expect(
              StatusMachine.canTransition(from, to, role),
              legalTuples.contains((from, to, role)),
              reason: '${from.name} -> ${to.name} as ${role.name}',
            );
          }
        }
      });
    }
  });

  group('nextStatuses (spec 3.1)', () {
    // Golden table: rows = from; columns = reporter, maintenance, verifier,
    // admin.
    const golden = <ComplaintStatus, List<List<ComplaintStatus>>>{
      reported: [
        [],
        [],
        [reviewed],
        [reviewed],
      ],
      reviewed: [
        [],
        [],
        [assigned],
        [assigned],
      ],
      assigned: [
        [],
        [inProgress],
        [],
        [inProgress],
      ],
      inProgress: [
        [],
        [resolved],
        [],
        [assigned, resolved],
      ],
      resolved: [
        [],
        [],
        [inProgress, verified],
        [inProgress, verified],
      ],
      verified: [
        [],
        [],
        [closed],
        [closed],
      ],
      closed: [[], [], [], []],
    };
    const roleOrder = [
      UserRole.reporter,
      UserRole.maintenance,
      UserRole.verifier,
      UserRole.admin,
    ];

    test('matches the golden table for all 28 (from, role) cells', () {
      var cells = 0;
      golden.forEach((from, perRole) {
        for (var i = 0; i < roleOrder.length; i++) {
          expect(
            StatusMachine.nextStatuses(from, roleOrder[i]),
            perRole[i],
            reason: '${from.name} as ${roleOrder[i].name}',
          );
          cells++;
        }
      });
      expect(cells, 28);
      expect(golden.keys, ComplaintStatus.values);
    });

    test('consistent with canTransition (invariant)', () {
      for (final from in ComplaintStatus.values) {
        for (final role in UserRole.values) {
          expect(
            StatusMachine.nextStatuses(from, role),
            ComplaintStatus.values
                .where((to) => StatusMachine.canTransition(from, to, role))
                .toList(),
            reason: '${from.name} as ${role.name}',
          );
        }
      }
    });

    test('sorted ascending by order with no duplicates', () {
      for (final from in ComplaintStatus.values) {
        for (final role in UserRole.values) {
          final next = StatusMachine.nextStatuses(from, role);
          final orders = [for (final s in next) s.order];
          expect(orders, [...orders]..sort(), reason: 'sorted');
          expect(orders.toSet(), hasLength(orders.length), reason: 'unique');
        }
      }
    });

    test('returns a fresh list (caller mutation cannot leak)', () {
      final first = StatusMachine.nextStatuses(inProgress, admin);
      first.clear();
      expect(StatusMachine.nextStatuses(inProgress, admin), [
        assigned,
        resolved,
      ]);
    });
  });

  group('named illegal cases (spec 6.2)', () {
    void expectIllegal(
      Iterable<(ComplaintStatus, ComplaintStatus)> pairs, {
      Iterable<UserRole> roles = UserRole.values,
    }) {
      for (final (from, to) in pairs) {
        for (final role in roles) {
          expect(
            StatusMachine.canTransition(from, to, role),
            isFalse,
            reason: '${from.name} -> ${to.name} as ${role.name}',
          );
        }
      }
    }

    test('I1 self-transitions (7), any role', () {
      expectIllegal([for (final s in ComplaintStatus.values) (s, s)]);
    });

    test('I2 reported cannot skip reviewed', () {
      expectIllegal([
        (reported, assigned),
        (reported, inProgress),
        (reported, resolved),
        (reported, verified),
        (reported, closed),
      ]);
    });

    test('I3 reviewed cannot skip assigned', () {
      expectIllegal([
        (reviewed, inProgress),
        (reviewed, resolved),
        (reviewed, verified),
        (reviewed, closed),
      ]);
    });

    test('I4 assigned cannot skip inProgress', () {
      expectIllegal([
        (assigned, resolved),
        (assigned, verified),
        (assigned, closed),
      ]);
    });

    test('I5 inProgress cannot skip resolved', () {
      expectIllegal([(inProgress, verified), (inProgress, closed)]);
    });

    test('I6 resolved cannot skip verified', () {
      expectIllegal([(resolved, closed)]);
    });

    test('I7 nothing goes backward from verified', () {
      expectIllegal([
        for (final to in ComplaintStatus.values)
          if (to.order < verified.order) (verified, to),
      ]);
    });

    test('I8 closed is terminal', () {
      expectIllegal([for (final to in ComplaintStatus.values) (closed, to)]);
    });

    test('I9 backward edges other than T7 and T8', () {
      expectIllegal([
        (reviewed, reported),
        (assigned, reviewed),
        (assigned, reported),
        (inProgress, reviewed),
        (inProgress, reported),
        (resolved, assigned),
        (resolved, reviewed),
        (resolved, reported),
      ]);
    });

    test(
      'I9b every backward move is illegal except T7 and T8 (admin/verifier)',
      () {
        for (final from in ComplaintStatus.values) {
          for (final to in ComplaintStatus.values) {
            if (to.order >= from.order) continue;
            for (final role in UserRole.values) {
              final isT7 = from == resolved && to == inProgress;
              final isT8 = from == inProgress && to == assigned;
              expect(
                StatusMachine.canTransition(from, to, role),
                legalTuples.contains((from, to, role)),
                reason: '${from.name} -> ${to.name} as ${role.name}',
              );
              if (!isT7 && !isT8) {
                expect(StatusMachine.canTransition(from, to, role), isFalse);
              }
            }
          }
        }
      },
    );

    test('I10 reporter has no legal transition at all', () {
      expectIllegal(
        [
          for (final f in ComplaintStatus.values)
            for (final t in ComplaintStatus.values) (f, t),
        ],
        roles: [reporterRole],
      );
      for (final from in ComplaintStatus.values) {
        expect(StatusMachine.nextStatuses(from, reporterRole), isEmpty);
      }
    });

    test('I11 maintenance cannot triage, assign, verify, close, reject or '
        'reassign', () {
      expectIllegal(
        [
          (reported, reviewed),
          (reviewed, assigned),
          (resolved, verified),
          (verified, closed),
          (resolved, inProgress),
          (inProgress, assigned),
        ],
        roles: [maintenance],
      );
    });

    test('I12 verifier cannot do the work or pull it back', () {
      expectIllegal(
        [
          (assigned, inProgress),
          (inProgress, resolved),
          (inProgress, assigned),
        ],
        roles: [verifier],
      );
    });

    test('I13 pull-back inProgress -> assigned is admin-only', () {
      expectIllegal([(inProgress, assigned)], roles: [maintenance, verifier]);
      expect(StatusMachine.canTransition(inProgress, assigned, admin), isTrue);
    });
  });

  group('validateTransition: result shape', () {
    test('ok is true iff there are no blockers', () {
      expect(ValidationResult().ok, isTrue);
      expect(ValidationResult().blockers, isEmpty);
      final bad = ValidationResult(
        blockers: [const TransitionBlocker(code: 'P8', message: 'm')],
      );
      expect(bad.ok, isFalse);
      expect(bad.codes, ['P8']);
    });

    test('blockers are unmodifiable and value-equal', () {
      final list = [const TransitionBlocker(code: 'P1', message: 'm')];
      final result = ValidationResult(blockers: list);
      list.add(const TransitionBlocker(code: 'P2', message: 'n'));
      expect(result.blockers, hasLength(1));
      expect(
        () => result.blockers.add(
          const TransitionBlocker(code: 'P3', message: 'o'),
        ),
        throwsUnsupportedError,
      );
      expect(
        result,
        ValidationResult(
          blockers: [const TransitionBlocker(code: 'P1', message: 'm')],
        ),
      );
      expect(result, isNot(ValidationResult()));
    });

    test('TransitionRequest defaults', () {
      const r = TransitionRequest(expectedFrom: reported);
      expect(r.note, isNull);
      expect(r.resolutionNote, isNull);
      expect(r.afterPhotos, isEmpty);
      expect(r.assignment, isNull);
      expect(r.priorityOverride, isNull);
    });

    test('is pure: inputs are not mutated and results are repeatable', () {
      final c = build(
        inProgress,
        assignment: elecAssignment(assigneeId: 'm-1'),
      );
      final snapshot = c.copyWith();
      final req = rq(
        inProgress,
        resolutionNote: 'done',
        afterPhotos: [freshPhoto],
      );
      final a = validate(c, resolved, elecA, req);
      final b = validate(c, resolved, elecA, req);
      expect(a, b);
      expect(c, snapshot);
      expect(c.status, inProgress);
      expect(c.timeline, isEmpty);
    });
  });

  group('L2 positives: every legal (edge, role) pair passes (T1-T8)', () {
    final scenarios = legalScenarios();

    test('scenarios cover exactly the 15 legal tuples', () {
      expect({for (final s in scenarios) s.tuple}, legalTuples);
      expect(scenarios, hasLength(15));
    });

    for (final s in scenarios) {
      test(s.name, () {
        final result = validate(s.complaint, s.to, s.actor, s.request);
        expect(result.ok, isTrue, reason: '${result.blockers}');
        expect(result.blockers, isEmpty);
      });
    }

    test('T3 maintenance who already owns the work may start it', () {
      final c = build(assigned, assignment: elecAssignment(assigneeId: 'm-1'));
      expect(validate(c, inProgress, elecA, rq(assigned)).ok, isTrue);
    });

    test('T2 admin may pick the router\'s own department (isManual false)', () {
      final c = build(reviewed);
      final req = rq(
        reviewed,
        assignment: elecAssignment(by: 'a-1', assigneeId: 'm-2'),
      );
      expect(validate(c, assigned, adminUser, req).ok, isTrue);
    });

    test('T4 counts photos already on the complaint plus the request', () {
      final claimed = elecAssignment(assigneeId: 'm-1');
      final onComplaint = build(
        inProgress,
        assignment: claimed,
        afterPhotos: [freshPhoto],
        resolutionNote: 'Fixed',
      );
      expect(validate(onComplaint, resolved, elecA, rq(inProgress)).ok, isTrue);
    });

    test('T4: a request note wins over the existing note', () {
      final c = build(
        inProgress,
        assignment: elecAssignment(assigneeId: 'm-1'),
        afterPhotos: [freshPhoto],
        resolutionNote: 'Fixed',
      );
      // Blank request note while a valid one exists: the request overwrites
      // the note, so it must itself be valid.
      final result = validate(
        c,
        resolved,
        elecA,
        rq(inProgress, resolutionNote: '   '),
      );
      expect(result.codes, ['P2']);
    });

    test('T8 same department but a different assignee is a change', () {
      final c = build(
        inProgress,
        assignment: elecAssignment(assigneeId: 'm-1'),
      );
      final req = rq(
        inProgress,
        note: 'Hand over',
        assignment: elecAssignment(by: 'a-1', assigneeId: 'm-2'),
      );
      expect(validate(c, assigned, adminUser, req).ok, isTrue);
    });

    test('notes of exactly 500 chars (and padded to 500 after trim) pass', () {
      final c = build(reported);
      for (final note in [longNote(500), '  ${longNote(500)}  ']) {
        expect(
          validate(c, reviewed, verifierUser, rq(reported, note: note)).ok,
          isTrue,
        );
      }
    });
  });

  group('L1 failures surface through validateTransition', () {
    test('every illegal tuple yields an L1 blocker, legal ones do not', () {
      for (final from in ComplaintStatus.values) {
        final c = build(from, assignment: elecAssignment(assigneeId: 'm-1'));
        for (final to in ComplaintStatus.values) {
          for (final role in UserRole.values) {
            final result = validate(c, to, userByRole[role]!, rq(from));
            expect(
              result.codes.contains('L1'),
              !legalTuples.contains((from, to, role)),
              reason: '${from.name} -> ${to.name} as ${role.name}',
            );
          }
        }
      }
    });

    test('an illegal edge never passes, even with perfect payload', () {
      final c = build(
        reviewed,
        assignment: elecAssignment(assigneeId: 'm-1'),
        afterPhotos: [freshPhoto],
        resolutionNote: 'ok',
      );
      final req = rq(
        reviewed,
        note: 'x',
        resolutionNote: 'x',
        afterPhotos: [freshPhoto],
        assignment: elecAssignment(by: 'a-1'),
      );
      // reviewed -> resolved skips states.
      final result = validate(c, resolved, adminUser, req);
      expect(result.ok, isFalse);
      expect(result.codes, ['L1']);
    });

    test('only the universal checks accompany L1', () {
      final c = build(closed);
      final result = validate(
        c,
        assigned,
        reporterUser,
        rq(reported, note: longNote(501)),
      );
      expect(result.codes, ['L1', 'P8', 'P9']);
    });

    test('role mismatch: maintenance cannot triage', () {
      final result = validate(build(reported), reviewed, elecA, rq(reported));
      expect(result.ok, isFalse);
      expect(result.codes, ['L1']);
    });
  });

  group('L2 negatives (spec 6.3)', () {
    final claimed = elecAssignment(assigneeId: 'm-1');
    Complaint inProgressC({
      List<Attachment> afterPhotos = const [],
      String? resolutionNote,
      List<StatusEvent>? timeline,
      Assignment? assignment,
    }) => build(
      inProgress,
      assignment: assignment ?? claimed,
      afterPhotos: afterPhotos,
      resolutionNote: resolutionNote,
      timeline: timeline,
    );

    test('N1 T4 with no after-photos -> P1', () {
      final r = validate(
        inProgressC(),
        resolved,
        elecA,
        rq(inProgress, resolutionNote: 'Fixed'),
      );
      expect(r.ok, isFalse);
      expect(r.codes, ['P1']);
      expect(r.blockers.single.message, 'Add at least one after-repair photo.');
    });

    test('N2 T4 with photos of the wrong kind -> P1', () {
      for (final kind in [AttachmentKind.beforePhoto, AttachmentKind.other]) {
        final r = validate(
          inProgressC(),
          resolved,
          elecA,
          rq(
            inProgress,
            resolutionNote: 'Fixed',
            afterPhotos: [
              photo('w', t0.add(const Duration(days: 3)), kind: kind),
            ],
          ),
        );
        expect(r.codes, ['P1'], reason: kind.name);
      }
    });

    test('N2b wrong-kind photo already on the complaint does not count', () {
      final c = inProgressC(
        afterPhotos: [
          photo(
            'w',
            t0.add(const Duration(days: 3)),
            kind: AttachmentKind.beforePhoto,
          ),
        ],
      );
      final r = validate(
        c,
        resolved,
        adminUser,
        rq(inProgress, resolutionNote: 'ok'),
      );
      expect(r.codes, ['P1']);
    });

    test(
      'N2c a photo created at/before the complaint was created is not fresh',
      () {
        final r = validate(
          inProgressC(),
          resolved,
          elecA,
          rq(
            inProgress,
            resolutionNote: 'Fixed',
            afterPhotos: [photo('same', t0)],
          ),
        );
        expect(r.codes, ['P1']);
      },
    );

    test('N3 T4 with blank / whitespace resolutionNote -> P2', () {
      for (final note in [null, '', '   ', '\n\t ']) {
        final r = validate(
          inProgressC(),
          resolved,
          elecA,
          rq(inProgress, resolutionNote: note, afterPhotos: [freshPhoto]),
        );
        expect(r.codes, ['P2'], reason: 'note=${note?.codeUnits}');
        expect(r.blockers.single.message, 'Add a resolution note.');
      }
    });

    group('N4 fresh evidence after a reject', () {
      // reported, reviewed, assigned, inProgress, resolved, then rejected.
      final rejectAt = t0.add(const Duration(days: 3));
      final timeline = [
        ev('e0', reported, t0, role: reporterRole),
        ev('e1', reviewed, hours(1)),
        ev('e2', assigned, hours(2)),
        ev('e3', inProgress, hours(3)),
        ev('e4', resolved, t0.add(const Duration(days: 1))),
        ev('e5', inProgress, rejectAt, note: 'Still sparking'),
      ];
      // Evidence from the first cycle: older than the reject event.
      final oldPhoto = after('a1'); // t0 + 2 days
      Complaint rejected() => inProgressC(
        afterPhotos: [oldPhoto],
        resolutionNote: 'Socket replaced',
        timeline: timeline,
      );

      test('only the pre-reject after-photo -> P1', () {
        final r = validate(rejected(), resolved, elecA, rq(inProgress));
        expect(r.codes, ['P1']);
      });

      test('a photo created exactly at the reject time is not fresh', () {
        final r = validate(
          rejected(),
          resolved,
          elecA,
          rq(inProgress, afterPhotos: [photo('edge', rejectAt)]),
        );
        expect(r.codes, ['P1']);
      });

      test('a photo created after the reject passes (old note retained)', () {
        final r = validate(
          rejected(),
          resolved,
          elecA,
          rq(
            inProgress,
            afterPhotos: [
              photo('new', rejectAt.add(const Duration(minutes: 1))),
            ],
          ),
        );
        expect(r.ok, isTrue, reason: '${r.blockers}');
      });

      test('uses the most recent of several rejects', () {
        final twoRejects = [
          ...timeline,
          ev('e6', resolved, rejectAt.add(const Duration(days: 1))),
          ev('e7', inProgress, rejectAt.add(const Duration(days: 2))),
        ];
        final c = inProgressC(
          afterPhotos: [
            oldPhoto,
            photo('mid', rejectAt.add(const Duration(days: 1))),
          ],
          resolutionNote: 'Socket replaced',
          timeline: twoRejects,
        );
        expect(validate(c, resolved, elecA, rq(inProgress)).codes, ['P1']);
      });

      test('a pull-back (T8) then restart does not reset the cycle', () {
        // inProgress after `assigned` is T3, not a reject.
        final withPullBack = [
          ...timeline,
          ev(
            'e6',
            assigned,
            rejectAt.add(const Duration(hours: 1)),
            note: 'Reassigned',
          ),
          ev('e7', inProgress, rejectAt.add(const Duration(hours: 2))),
        ];
        final c = inProgressC(
          afterPhotos: [oldPhoto],
          resolutionNote: 'Socket replaced',
          timeline: withPullBack,
        );
        expect(validate(c, resolved, elecA, rq(inProgress)).codes, ['P1']);
        // ...and a photo newer than the original reject satisfies it.
        final ok = validate(
          c,
          resolved,
          elecA,
          rq(
            inProgress,
            afterPhotos: [photo('n', rejectAt.add(const Duration(hours: 5)))],
          ),
        );
        expect(ok.ok, isTrue, reason: '${ok.blockers}');
      });
    });

    test('N5 T4 with a 501-char resolutionNote -> P2 and P9', () {
      final r = validate(
        inProgressC(),
        resolved,
        elecA,
        rq(
          inProgress,
          resolutionNote: longNote(501),
          afterPhotos: [freshPhoto],
        ),
      );
      expect(r.ok, isFalse);
      expect(r.codes, ['P2', 'P9']);
      expect(r.blockers.last.message, 'Note too long (500 max).');
    });

    group('N6 T5 over corrupt data', () {
      final claimedR = elecAssignment(assigneeId: 'm-1');
      test('afterPhotos cleared -> P1', () {
        final c = build(
          resolved,
          assignment: claimedR,
          resolutionNote: 'Fixed',
        );
        expect(validate(c, verified, verifierUser, rq(resolved)).codes, ['P1']);
      });

      test('resolutionNote cleared -> P2', () {
        final c = build(
          resolved,
          assignment: claimedR,
          afterPhotos: [freshPhoto],
        );
        expect(validate(c, verified, verifierUser, rq(resolved)).codes, ['P2']);
      });

      test('both cleared -> P1 and P2', () {
        final c = build(resolved, assignment: claimedR);
        expect(validate(c, verified, adminUser, rq(resolved)).codes, [
          'P1',
          'P2',
        ]);
      });

      test('T5 does not accept evidence supplied only in the request', () {
        // T5 stores nothing from the request, so INV-3 needs it persisted.
        final c = build(resolved, assignment: claimedR);
        final r = validate(
          c,
          verified,
          verifierUser,
          rq(resolved, resolutionNote: 'Fixed', afterPhotos: [freshPhoto]),
        );
        expect(r.codes, ['P1', 'P2']);
      });

      test('a stale (pre-reject) photo on a resolved complaint -> P1', () {
        final c = build(
          resolved,
          assignment: claimedR,
          afterPhotos: [photo('old', hours(5))],
          resolutionNote: 'Fixed',
          timeline: [
            ev('e0', reported, t0, role: reporterRole),
            ev('e1', inProgress, hours(6)),
            ev('e2', resolved, hours(7)),
            ev('e3', inProgress, hours(8), note: 'No'),
            ev('e4', resolved, hours(9)),
          ],
        );
        expect(validate(c, verified, verifierUser, rq(resolved)).codes, ['P1']);
      });
    });

    test('N7 T7 with a blank note -> P3', () {
      final c = build(
        resolved,
        assignment: claimed,
        afterPhotos: [freshPhoto],
        resolutionNote: 'Fixed',
      );
      for (final note in [null, '', '  \n']) {
        for (final actor in [verifierUser, adminUser]) {
          final r = validate(c, inProgress, actor, rq(resolved, note: note));
          expect(r.codes, ['P3'], reason: 'note=${note?.codeUnits}');
          expect(r.blockers.single.message, 'Add a reason.');
        }
      }
    });

    test('N7b T7 / T8 with a 501-char note -> P3 and P9', () {
      final resolvedC = build(
        resolved,
        assignment: claimed,
        afterPhotos: [freshPhoto],
        resolutionNote: 'Fixed',
      );
      expect(
        validate(
          resolvedC,
          inProgress,
          verifierUser,
          rq(resolved, note: longNote(501)),
        ).codes,
        ['P3', 'P9'],
      );
      final pull = elecAssignment(by: 'a-1', assigneeId: 'm-2');
      expect(
        validate(
          inProgressC(),
          assigned,
          adminUser,
          rq(inProgress, note: longNote(501), assignment: pull),
        ).codes,
        ['P3', 'P9'],
      );
    });

    group('N8 T8', () {
      final other = Assignment(
        department: Department.plumber,
        assignedBy: 'a-1',
        assignedAt: hours(30),
        isManual: true,
      );

      test('blank note -> P3', () {
        final r = validate(
          inProgressC(),
          assigned,
          adminUser,
          rq(inProgress, assignment: other),
        );
        expect(r.codes, ['P3']);
      });

      test('identical department and assignee -> P4', () {
        final same = claimed.copyWith(assignedBy: 'a-1');
        final r = validate(
          inProgressC(),
          assigned,
          adminUser,
          rq(inProgress, note: 'Reason', assignment: same),
        );
        expect(r.codes, ['P4']);
        expect(
          r.blockers.single.message,
          'Choose a different department or assignee.',
        );
      });

      test('blank note and identical assignment -> P3 and P4', () {
        final same = claimed.copyWith(assignedBy: 'a-1');
        final r = validate(
          inProgressC(),
          assigned,
          adminUser,
          rq(inProgress, assignment: same),
        );
        expect(r.codes, ['P3', 'P4']);
      });

      test('no assignment at all -> P4', () {
        final r = validate(
          inProgressC(),
          assigned,
          adminUser,
          rq(inProgress, note: 'Reason'),
        );
        expect(r.codes, ['P4']);
        expect(r.blockers.single.message, 'Choose a department.');
      });
    });

    group('N9 T3/T4 by maintenance of another department -> P6', () {
      final unclaimed = elecAssignment();
      test('T3', () {
        final r = validate(
          build(assigned, assignment: unclaimed),
          inProgress,
          plumberC,
          rq(assigned),
        );
        expect(r.codes, ['P6']);
        expect(
          r.blockers.single.message,
          'This work belongs to another department.',
        );
      });

      test('T4', () {
        final r = validate(
          inProgressC(assignment: unclaimed),
          resolved,
          plumberC,
          rq(inProgress, resolutionNote: 'x', afterPhotos: [freshPhoto]),
        );
        expect(r.codes, ['P6']);
      });

      test('maintenance without a department -> P6', () {
        final r = validate(
          build(assigned, assignment: unclaimed),
          inProgress,
          elecA.copyWith(clearDepartment: true),
          rq(assigned),
        );
        expect(r.codes, ['P6']);
      });

      test('no assignment on the complaint -> P6 for maintenance', () {
        final r = validate(build(assigned), inProgress, elecA, rq(assigned));
        expect(r.codes, ['P6']);
      });

      test('admin is not department-bound', () {
        final r = validate(
          build(assigned, assignment: unclaimed),
          inProgress,
          adminUser,
          rq(assigned),
        );
        expect(r.ok, isTrue);
      });
    });

    group('N10 T3/T4 by maintenance when claimed by someone else -> P7', () {
      test('T3', () {
        final r = validate(
          build(assigned, assignment: elecAssignment(assigneeId: 'm-2')),
          inProgress,
          elecA,
          rq(assigned),
        );
        expect(r.codes, ['P7']);
        expect(r.blockers.single.message, 'Already claimed by a colleague.');
      });

      test('T4', () {
        final r = validate(
          inProgressC(assignment: elecAssignment(assigneeId: 'm-2')),
          resolved,
          elecA,
          rq(inProgress, resolutionNote: 'x', afterPhotos: [freshPhoto]),
        );
        expect(r.codes, ['P7']);
      });

      test('other department and other claimant -> P6 and P7', () {
        final r = validate(
          build(assigned, assignment: elecAssignment(assigneeId: 'm-2')),
          inProgress,
          plumberC,
          rq(assigned),
        );
        expect(r.codes, ['P6', 'P7']);
      });

      test('admin may act on work claimed by anyone', () {
        final r = validate(
          build(assigned, assignment: elecAssignment(assigneeId: 'm-2')),
          inProgress,
          adminUser,
          rq(assigned),
        );
        expect(r.ok, isTrue);
      });
    });

    group('N11/N12 T2 manual assignment by a verifier -> P5', () {
      final onPlumber = Assignment(
        department: Department.plumber,
        assignedBy: 'v-1',
        assignedAt: hours(2),
        isManual: true,
      );

      test('N11 manual department on an auto-routable complaint', () {
        final r = validate(
          build(reviewed),
          assigned,
          verifierUser,
          rq(reviewed, assignment: onPlumber),
        );
        expect(r.codes, ['P5']);
        expect(
          r.blockers.single.message,
          'Only an admin can assign a custom department.',
        );
      });

      test('N12 safety / other have no route, so any assignment is manual', () {
        for (final category in [
          ProblemCategory.safety,
          ProblemCategory.other,
        ]) {
          final r = validate(
            build(reviewed, category: category),
            assigned,
            verifierUser,
            rq(reviewed, assignment: onPlumber),
          );
          expect(r.codes, ['P5'], reason: category.name);
        }
      });

      test('the same assignment is fine for an admin', () {
        final byAdmin = onPlumber.copyWith(assignedBy: 'a-1');
        final r = validate(
          build(reviewed, category: ProblemCategory.safety),
          assigned,
          adminUser,
          rq(reviewed, assignment: byAdmin),
        );
        expect(r.ok, isTrue);
      });

      test(
        'T8 manual pull-back also needs an admin (L1 blocks others first)',
        () {
          final manual = onPlumber.copyWith(assignedBy: 'a-1');
          expect(
            validate(
              inProgressC(),
              assigned,
              adminUser,
              rq(inProgress, note: 'r', assignment: manual),
            ).ok,
            isTrue,
          );
          expect(
            validate(
              inProgressC(),
              assigned,
              verifierUser,
              rq(inProgress, note: 'r', assignment: manual),
            ).codes,
            ['L1'],
          );
        },
      );
    });

    test('N13 any transition with a stale expectedFrom -> P8', () {
      for (final s in legalScenarios()) {
        for (final stale in ComplaintStatus.values) {
          if (stale == s.complaint.status) continue;
          final req = TransitionRequest(
            expectedFrom: stale,
            note: s.request.note,
            resolutionNote: s.request.resolutionNote,
            afterPhotos: s.request.afterPhotos,
            assignment: s.request.assignment,
          );
          final r = validate(s.complaint, s.to, s.actor, req);
          expect(r.codes, ['P8'], reason: '${s.name} expectedFrom=$stale');
          expect(
            r.blockers.single.message,
            'This complaint changed; refresh and retry.',
          );
        }
      }
    });

    group('N14 closed complaints accept no mutation (INV-4)', () {
      final closedC = build(
        closed,
        assignment: claimed,
        afterPhotos: [freshPhoto],
        resolutionNote: 'Fixed',
      );

      test('no target, no role, even with a matching expectedFrom', () {
        for (final to in ComplaintStatus.values) {
          for (final role in UserRole.values) {
            final r = validate(closedC, to, userByRole[role]!, rq(closed));
            expect(r.ok, isFalse, reason: '${to.name} as ${role.name}');
            expect(r.codes, containsAll(['L1', 'P8']));
          }
        }
      });

      test('with a priority override or a note it is still rejected', () {
        final r = validate(
          closedC,
          closed,
          adminUser,
          rq(closed, note: 'edit', priorityOverride: Priority.critical),
        );
        expect(r.ok, isFalse);
        expect(r.codes, containsAll(['L1', 'P8']));
      });
    });

    group('N15 T2 assignment structure (user-directory part deferred)', () {
      test('missing assignment -> P4', () {
        final r = validate(
          build(reviewed),
          assigned,
          verifierUser,
          rq(reviewed),
        );
        expect(r.codes, ['P4']);
        expect(r.blockers.single.message, 'Choose a department.');
      });

      test('assignedBy must be the acting user -> P4', () {
        final r = validate(
          build(reviewed),
          assigned,
          verifierUser,
          rq(reviewed, assignment: elecAssignment(by: 'someone-else')),
        );
        expect(r.codes, ['P4']);
      });

      test('admin cannot record an assignment under another id -> P4', () {
        final r = validate(
          build(reviewed),
          assigned,
          adminUser,
          rq(reviewed, assignment: elecAssignment(by: 'v-1')),
        );
        expect(r.codes, ['P4']);
      });

      test(
        'assigneeId that is not a maintenance user of that department',
        () {
          final bogus = elecAssignment(by: 'a-1', assigneeId: 'no-such-user');
          expect(
            validate(
              build(reviewed),
              assigned,
              adminUser,
              rq(reviewed, assignment: bogus),
            ).codes,
            ['P4'],
          );
        },
        skip:
            'User-existence / role / department check needs a user directory; '
            'enforced by ComplaintService (S2.7), not by the pure machine.',
      );
    });

    group('P9 note length (all transitions)', () {
      test('a 501-char optional note is rejected on every legal edge', () {
        for (final s in legalScenarios()) {
          final req = TransitionRequest(
            expectedFrom: s.request.expectedFrom,
            note: longNote(501),
            resolutionNote: s.request.resolutionNote,
            afterPhotos: s.request.afterPhotos,
            assignment: s.request.assignment,
          );
          final r = validate(s.complaint, s.to, s.actor, req);
          expect(r.codes, contains('P9'), reason: s.name);
        }
      });

      test('a whitespace-padded 500-char note is within the limit', () {
        final r = validate(
          build(reported),
          reviewed,
          verifierUser,
          rq(reported, note: ' ${longNote(500)} '),
        );
        expect(r.ok, isTrue);
      });

      test('blank notes are not "too long"', () {
        final r = validate(
          build(reported),
          reviewed,
          verifierUser,
          rq(reported, note: ' ' * 600),
        );
        expect(r.ok, isTrue);
      });
    });

    test('blockers accumulate in code order, never short-circuit', () {
      // T4 by the wrong department on claimed work with nothing supplied and
      // a stale expectedFrom and an over-long note.
      final r = validate(
        inProgressC(assignment: elecAssignment(assigneeId: 'm-2')),
        resolved,
        plumberC,
        rq(reported, note: longNote(501), resolutionNote: longNote(501)),
      );
      expect(r.codes, ['P1', 'P2', 'P6', 'P7', 'P8', 'P9']);
    });
  });

  group('replay sequences (spec 8.4-8.8)', () {
    test('happy path reported -> ... -> closed (TL-1..5, INV-1..4)', () {
      var c = submitted();
      expectInvariants(c);

      c = reviewAndRoute(c, verifierUser, at: hours(1));
      expect(c.status, assigned);
      expect(c.assignment!.department, Department.electrician);
      expect(c.assignment!.isManual, isFalse);
      expect(c.assignment!.assigneeId, isNull);
      expectInvariants(c);

      c = apply(c, inProgress, elecA, at: hours(2));
      expect(c.assignment!.assigneeId, 'm-1', reason: 'claim on T3');
      expectInvariants(c);

      c = apply(
        c,
        resolved,
        elecA,
        at: hours(3),
        resolutionNote: 'Socket replaced',
        afterPhotos: [photo('a1', hours(3))],
      );
      expectInvariants(c);

      c = apply(c, verified, verifierUser, at: hours(4));
      expectInvariants(c);

      c = apply(c, closed, adminUser, at: hours(5));
      expectInvariants(c);

      expect(
        [for (final e in c.timeline) e.status],
        [reported, reviewed, assigned, inProgress, resolved, verified, closed],
      );
      // Closed is immutable (INV-4): no further transition validates.
      for (final to in ComplaintStatus.values) {
        for (final u in userByRole.values) {
          expect(validate(c, to, u, rq(closed)).ok, isFalse);
        }
      }
    });

    test('maintenance cannot resolve without evidence mid-sequence', () {
      var c = reviewAndRoute(submitted(), verifierUser, at: hours(1));
      c = apply(c, inProgress, elecA, at: hours(2));
      final out = tryApply(
        c,
        resolved,
        elecA,
        at: hours(3),
        resolutionNote: 'Done',
      );
      expect(out.result, isNull);
      expect(out.validation.codes, ['P1']);
    });

    test('reject loop: resolved -> inProgress -> resolved -> verified -> '
        'closed (incl. N4)', () {
      var c = reviewAndRoute(submitted(), verifierUser, at: hours(1));
      c = apply(c, inProgress, elecA, at: hours(2));
      c = apply(
        c,
        resolved,
        elecA,
        at: hours(3),
        resolutionNote: 'First attempt',
        afterPhotos: [photo('a1', hours(3))],
      );
      expectInvariants(c);

      // Reject needs a reason (N7).
      expect(
        tryApply(c, inProgress, verifierUser, at: hours(4)).validation.codes,
        ['P3'],
      );
      c = apply(
        c,
        inProgress,
        verifierUser,
        at: hours(4),
        note: 'Still sparks',
      );
      expect(c.afterPhotos, hasLength(1), reason: 'history retained');
      expect(c.resolutionNote, 'First attempt', reason: 'history retained');

      // Re-resolve with only the old photo -> N4.
      final stale = tryApply(
        c,
        resolved,
        elecA,
        at: hours(5),
        resolutionNote: 'Second attempt',
      );
      expect(stale.result, isNull);
      expect(stale.validation.codes, ['P1']);
      // A photo taken before the reject is still not fresh evidence.
      final stillStale = tryApply(
        c,
        resolved,
        elecA,
        at: hours(5),
        resolutionNote: 'Second attempt',
        afterPhotos: [photo('older', hours(3))],
      );
      expect(stillStale.validation.codes, ['P1']);

      c = apply(
        c,
        resolved,
        elecA,
        at: hours(5),
        resolutionNote: 'Second attempt',
        afterPhotos: [photo('a2', hours(5))],
      );
      expectInvariants(c);
      expect(c.afterPhotos, hasLength(2));

      c = apply(c, verified, verifierUser, at: hours(6));
      c = apply(c, closed, verifierUser, at: hours(7));
      expectInvariants(c);
      expect(
        [for (final e in c.timeline) e.status],
        [
          reported,
          reviewed,
          assigned,
          inProgress,
          resolved,
          inProgress,
          resolved,
          verified,
          closed,
        ],
      );
    });

    test('verifier cannot verify a re-opened cycle without fresh evidence', () {
      // Corrupt scenario: after a reject, status is forced back to resolved
      // without new evidence; T5 must not pass (INV-3).
      var c = reviewAndRoute(submitted(), verifierUser, at: hours(1));
      c = apply(c, inProgress, elecA, at: hours(2));
      c = apply(
        c,
        resolved,
        elecA,
        at: hours(3),
        resolutionNote: 'First',
        afterPhotos: [photo('a1', hours(3))],
      );
      c = apply(c, inProgress, adminUser, at: hours(4), note: 'Redo');
      final forced = c.copyWith(
        status: resolved,
        timeline: [...c.timeline, ev('f', resolved, hours(5))],
      );
      expect(validate(forced, verified, verifierUser, rq(resolved)).codes, [
        'P1',
      ]);
    });

    test('pull-back: inProgress -> assigned -> inProgress with a new '
        'department', () {
      var c = reviewAndRoute(submitted(), verifierUser, at: hours(1));
      c = apply(c, inProgress, elecA, at: hours(2));
      expect(c.assignment!.assigneeId, 'm-1');

      final toPlumber = Assignment(
        department: Department.plumber,
        assignedBy: 'a-1',
        assignedAt: hours(3),
        isManual: true,
      );
      // Only an admin may pull back (I13) and a reason is required (N8).
      expect(
        tryApply(
          c,
          assigned,
          verifierUser,
          at: hours(3),
          note: 'x',
          assignment: toPlumber,
        ).validation.codes,
        ['L1'],
      );
      expect(
        tryApply(
          c,
          assigned,
          adminUser,
          at: hours(3),
          assignment: toPlumber,
        ).validation.codes,
        ['P3'],
      );

      c = apply(
        c,
        assigned,
        adminUser,
        at: hours(3),
        note: 'Pipe, not wiring',
        assignment: toPlumber,
      );
      expect(c.status, assigned);
      expect(c.assignment!.department, Department.plumber);
      expect(c.assignment!.assigneeId, isNull);
      expectInvariants(c);

      // Old department can no longer start it (P6); the new one can.
      expect(tryApply(c, inProgress, elecA, at: hours(4)).validation.codes, [
        'P6',
      ]);
      c = apply(c, inProgress, plumberC, at: hours(4));
      expect(c.assignment!.assigneeId, 'm-3');
      c = apply(
        c,
        resolved,
        plumberC,
        at: hours(5),
        resolutionNote: 'Pipe replaced',
        afterPhotos: [photo('p1', hours(5))],
      );
      c = apply(c, verified, adminUser, at: hours(6));
      c = apply(c, closed, adminUser, at: hours(7));
      expectInvariants(c);
      expect(c.timeline.where((e) => e.status == assigned), hasLength(2));
    });

    test('manual-triage path: safety stops at reviewed; admin assigns', () {
      var c = submitted(category: ProblemCategory.safety);
      c = reviewAndRoute(c, verifierUser, at: hours(1));
      expect(c.status, reviewed, reason: 'no auto-route for safety');
      expect(c.assignment, isNull);
      expectInvariants(c); // INV-2

      final manual = Assignment(
        department: Department.civilMaintenance,
        assignedBy: 'v-1',
        assignedAt: hours(2),
        isManual: true,
      );
      // W5: a verifier cannot assign any department (everything is manual).
      expect(
        tryApply(
          c,
          assigned,
          verifierUser,
          at: hours(2),
          assignment: manual,
        ).validation.codes,
        ['P5'],
      );

      c = apply(
        c,
        assigned,
        adminUser,
        at: hours(2),
        assignment: manual.copyWith(assignedBy: 'a-1'),
      );
      expect(c.status, assigned);
      expect(c.assignment!.isManual, isTrue);
      expectInvariants(c);
    });

    test('atomic composite: a failing second step leaves the complaint '
        'untouched', () {
      // Review & Route for a safety complaint where the actor tries to
      // auto-assign a manual department: T1 passes, T2 fails (P5).
      final c = submitted(category: ProblemCategory.safety);
      final snapshot = c.copyWith();

      final step1 = tryApply(c, reviewed, verifierUser, at: hours(1));
      expect(step1.validation.ok, isTrue);
      final step2 = tryApply(
        step1.result!,
        assigned,
        verifierUser,
        at: hours(1),
        assignment: Assignment(
          department: Department.civilMaintenance,
          assignedBy: 'v-1',
          assignedAt: hours(1),
          isManual: true,
        ),
      );
      expect(step2.result, isNull);
      expect(step2.validation.codes, ['P5']);

      // A caller that commits only if every step validates keeps `c`.
      final committed = step2.result ?? c;
      expect(committed, snapshot);
      expect(committed.status, reported);
      expect(committed.timeline, hasLength(1));
    });
  });
}
