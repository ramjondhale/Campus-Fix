// Seed integrity: counts, coverage, router-consistent assignments,
// replay-valid timelines (status-machine-spec §7: INV-1..5, TL-1..7),
// engine-computed priorities (priority-engine-spec §6), users and
// notifications.
import 'dart:convert';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

final SeedData seed = SeedData.build();
final Map<String, AppUser> usersById = {for (final u in seed.users) u.id: u};

bool isUnresolved(Complaint c) =>
    c.status.order < ComplaintStatus.resolved.order;

bool isResolvedOrBeyond(Complaint c) => !isUnresolved(c);

/// The priority the engine must have produced: aged waiting time for
/// unresolved complaints; frozen at the last pre-resolution event otherwise.
Priority expectedPriority(Complaint c, DateTime now) {
  final Duration waiting;
  if (isUnresolved(c)) {
    waiting = now.difference(c.createdAt);
  } else {
    waiting = c.timeline
        .lastWhere((e) => e.status.order < ComplaintStatus.resolved.order)
        .at
        .difference(c.createdAt);
  }
  return computePriority(
    PriorityInputs(
      category: c.category,
      safetyFlag: c.safetyFlag,
      severity: c.severity,
      peopleAffected: c.peopleAffected,
      waitingTime: waiting,
    ),
  );
}

void main() {
  group('counts and coverage', () {
    test('has at least 24 complaints (29 in the default seed)', () {
      expect(seed.complaints.length, greaterThanOrEqualTo(24));
      expect(seed.complaints, hasLength(29));
    });

    test('every category, priority and status is represented', () {
      expect(
        seed.complaints.map((c) => c.category).toSet(),
        ProblemCategory.values.toSet(),
      );
      expect(
        seed.complaints.map((c) => c.effectivePriority).toSet(),
        Priority.values.toSet(),
      );
      expect(
        seed.complaints.map((c) => c.priority).toSet(),
        Priority.values.toSet(),
        reason: 'computed priorities cover all four bands too',
      );
      expect(
        seed.complaints.map((c) => c.status).toSet(),
        ComplaintStatus.values.toSet(),
      );
    });

    test('distribution snapshot (documented in the S2.6 report)', () {
      Map<T, int> count<T>(T Function(Complaint) key) {
        final m = <T, int>{};
        for (final c in seed.complaints) {
          m[key(c)] = (m[key(c)] ?? 0) + 1;
        }
        return m;
      }

      expect(count((c) => c.status), {
        ComplaintStatus.reported: 4,
        ComplaintStatus.reviewed: 3,
        ComplaintStatus.assigned: 4,
        ComplaintStatus.inProgress: 6,
        ComplaintStatus.resolved: 4,
        ComplaintStatus.verified: 3,
        ComplaintStatus.closed: 5,
      });
      expect(count((c) => c.category), {
        ProblemCategory.electrical: 4,
        ProblemCategory.plumbing: 4,
        ProblemCategory.civil: 3,
        ProblemCategory.furniture: 4,
        ProblemCategory.cleanliness: 3,
        ProblemCategory.it: 4,
        ProblemCategory.safety: 4,
        ProblemCategory.other: 3,
      });
      expect(count((c) => c.effectivePriority), {
        Priority.critical: 4,
        Priority.high: 12,
        Priority.medium: 8,
        Priority.low: 5,
      });
    });

    test('is deterministic and the lists are unmodifiable', () {
      expect(SeedData.build().complaints, seed.complaints);
      expect(SeedData.build().notifications, seed.notifications);
      expect(SeedData.build().users, seed.users);
      expect(
        () => seed.complaints.add(seed.complaints.first),
        throwsUnsupportedError,
      );
      expect(() => seed.users.clear(), throwsUnsupportedError);
      expect(() => seed.notifications.clear(), throwsUnsupportedError);
    });

    test('every complaint survives a real JSON round-trip', () {
      for (final c in seed.complaints) {
        final back = Complaint.fromJson(
          jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>,
        );
        expect(back, c, reason: c.id);
      }
    });
  });

  group('ids and dates', () {
    test(
      'ids are CF-YYYY-NNNNN, unique, gapless and ascend with createdAt',
      () {
        final ids = seed.complaints.map((c) => c.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
        for (final id in ids) {
          expect(id, matches(complaintIdPattern));
        }
        expect(ids.first, 'CF-2026-00001');
        expect(ids.last, 'CF-2026-00029');
        for (var i = 1; i < seed.complaints.length; i++) {
          expect(
            seed.complaints[i].createdAt.isAfter(
              seed.complaints[i - 1].createdAt,
            ),
            isTrue,
          );
        }
        expect(seed.lastSequenceByYear, {2026: 29});
      },
    );

    test('ID counters let the generator continue after the seed', () {
      final gen = ComplaintIdGenerator(
        initialCounters: seed.lastSequenceByYear,
      );
      expect(gen.next(seed.now), 'CF-2026-00030');
    });

    test('nothing is in the future and updatedAt is the last event', () {
      for (final c in seed.complaints) {
        expect(c.createdAt.isAfter(seed.now), isFalse, reason: c.id);
        expect(c.updatedAt.isAfter(seed.now), isFalse, reason: c.id);
        expect(c.timeline.last.at, c.updatedAt, reason: c.id);
      }
    });

    test('default reference time is the documented constant', () {
      expect(seed.now, seedReferenceTime);
      expect(seedReferenceTime, DateTime.utc(2026, 10, 6, 9));
    });

    test('build(now:) shifts every timestamp and re-derives the IDs', () {
      final later = DateTime.utc(2027, 1, 15, 12);
      final shifted = SeedData.build(now: later);
      final delta = later.difference(seed.now);
      expect(shifted.now, later);
      expect(shifted.complaints, hasLength(seed.complaints.length));
      for (var i = 0; i < seed.complaints.length; i++) {
        final a = seed.complaints[i];
        final b = shifted.complaints[i];
        expect(b.createdAt, a.createdAt.add(delta));
        expect(b.updatedAt, a.updatedAt.add(delta));
        expect(b.status, a.status);
        expect(b.priority, a.priority);
        expect(b.priorityOverride, a.priorityOverride);
        expect(b.timeline.length, a.timeline.length);
        expect(b.description, a.description);
        expect(b.id, matches(complaintIdPattern));
        expect(b.id.substring(3, 7), '${b.createdAt.year}');
      }
      // The window straddles New Year: the sequence restarts per year.
      expect(shifted.lastSequenceByYear.keys, containsAll([2026, 2027]));
      expect(
        shifted.lastSequenceByYear.values.fold<int>(0, (a, b) => a + b),
        seed.complaints.length,
      );
      expect(shifted.notifications, hasLength(seed.notifications.length));
    });
  });

  group('users and logins', () {
    test('a small fixed set across all roles and departments', () {
      expect(seed.usersWithRole(UserRole.reporter), hasLength(10));
      expect(seed.usersWithRole(UserRole.verifier), hasLength(2));
      expect(seed.usersWithRole(UserRole.admin), hasLength(1));
      final maintenance = seed.usersWithRole(UserRole.maintenance);
      expect(maintenance, hasLength(12));
      for (final d in Department.values) {
        expect(
          maintenance.where((u) => u.department == d),
          hasLength(2),
          reason: '${d.name}: one user and a peer',
        );
      }
    });

    test(
      'ids, ID numbers and emails are unique; only maintenance has a department',
      () {
        expect(usersById, hasLength(seed.users.length));
        expect(
          seed.users.map((u) => u.idNumber.toLowerCase()).toSet(),
          hasLength(seed.users.length),
        );
        expect(
          seed.users.map((u) => u.email).toSet(),
          hasLength(seed.users.length),
        );
        for (final u in seed.users) {
          expect(
            u.department != null,
            u.role == UserRole.maintenance,
            reason: u.id,
          );
          expect(u.displayName.trim(), isNotEmpty);
        }
      },
    );

    test('accounts mirror the users; demo accounts cover each role once', () {
      expect(seed.accounts.map((a) => a.user), seed.users);
      expect(seed.accounts.map((a) => a.password).toSet(), {seedDemoPassword});
      expect(seed.demoAccounts.map((a) => a.user.role), UserRole.values);
      expect(seed.demoAccounts.every((a) => seed.accounts.contains(a)), isTrue);
    });

    test(
      'every reporter on a complaint is a seeded reporter with matching identity',
      () {
        for (final c in seed.complaints) {
          final u = usersById[c.reporter.userId];
          expect(u, isNotNull, reason: c.id);
          expect(u!.role, UserRole.reporter);
          expect(c.reporter.fullName, u.displayName);
          expect(c.reporter.idNumber, u.idNumber);
          expect(c.reporter.email, u.email);
        }
        final used = seed.complaints.map((c) => c.reporter.userId).toSet();
        expect(
          used,
          hasLength(10),
          reason: 'every seeded reporter filed something',
        );
      },
    );

    test('some reporters have no phone (optional field exercised)', () {
      final phones = seed.complaints.map((c) => c.reporter.phone);
      expect(phones.any((p) => p == null), isTrue);
      expect(phones.any((p) => p != null), isTrue);
    });

    test('seed identities are clearly fictional (.test domain)', () {
      for (final u in seed.users) {
        expect(u.email, endsWith('@campus.test'), reason: u.id);
      }
    });
  });

  group('photos and content', () {
    test(
      'every complaint has before photos; resolved+ ones have after photos',
      () {
        for (final c in seed.complaints) {
          expect(c.beforePhotos, isNotEmpty, reason: c.id);
          expect(
            c.beforePhotos.every((a) => a.kind == AttachmentKind.beforePhoto),
            isTrue,
          );
          final everResolved = c.timeline.any(
            (e) => e.status == ComplaintStatus.resolved,
          );
          if (everResolved) {
            expect(c.afterPhotos, isNotEmpty, reason: c.id);
          } else {
            expect(c.afterPhotos, isEmpty, reason: c.id);
          }
          expect(
            c.afterPhotos.every((a) => a.kind == AttachmentKind.afterPhoto),
            isTrue,
          );
        }
      },
    );

    test('photo refs are placeholder seed assets and ids are unique', () {
      final ids = <String>{};
      for (final c in seed.complaints) {
        for (final a in [...c.beforePhotos, ...c.afterPhotos]) {
          expect(
            a.ref,
            matches(
              RegExp(r'^assets/seed/[a-z]+_\d{2}_(before|after)(_\d)?\.jpg$'),
            ),
          );
          expect(
            ids.add(a.id),
            isTrue,
            reason: 'duplicate attachment id ${a.id}',
          );
        }
      }
      final refs = [
        for (final c in seed.complaints)
          for (final a in [...c.beforePhotos, ...c.afterPhotos]) a.ref,
      ];
      expect(refs.toSet(), hasLength(refs.length), reason: 'refs are unique');
      expect(
        seed.complaints.first.beforePhotos.first.ref,
        'assets/seed/furn_01_before.jpg',
      );
    });

    test('where is a listed campus location', () {
      for (final c in seed.complaints) {
        expect(
          CampusDirectory.standard.contains(c.building, c.floor, c.room),
          isTrue,
          reason: '${c.id}: ${c.building} / ${c.floor} / ${c.room}',
        );
      }
    });

    test('text fields are present and within the form limits', () {
      for (final c in seed.complaints) {
        expect(c.description.trim(), isNotEmpty);
        expect(c.description.length, lessThanOrEqualTo(500));
        expect(c.room.length, lessThanOrEqualTo(60));
        if (c.title != null) expect(c.title!.trim(), isNotEmpty);
        for (final e in c.timeline) {
          expect((e.note ?? '').length, lessThanOrEqualTo(500));
        }
      }
      expect(seed.complaints.any((c) => c.title == null), isTrue);
    });

    test(
      'safety category is always flagged; some other categories are too',
      () {
        for (final c in seed.complaints) {
          if (c.category == ProblemCategory.safety) {
            expect(c.safetyFlag, isTrue);
          }
        }
        expect(
          seed.complaints.any(
            (c) => c.safetyFlag && c.category != ProblemCategory.safety,
          ),
          isTrue,
        );
        expect(seed.complaints.any((c) => !c.safetyFlag), isTrue);
      },
    );

    test('all severities and all people-affected levels occur', () {
      expect(
        seed.complaints.map((c) => c.severity).toSet(),
        Severity.values.toSet(),
      );
      expect(
        seed.complaints.map((c) => c.peopleAffected).toSet(),
        PeopleAffected.values.toSet(),
      );
    });
  });

  group('assignments', () {
    final assigned = seed.complaints
        .where((c) => c.assignment != null)
        .toList();

    test('isManual is router-consistent for every seed assignment', () {
      expect(assigned, isNotEmpty);
      for (final c in assigned) {
        final a = c.assignment!;
        expect(
          a.isManual,
          routeToDepartment(c.category) != a.department,
          reason: '${c.id} (${c.category.name} -> ${a.department.name})',
        );
        expect(a.isManual, isManualAssignment(c.category, a.department));
      }
    });

    test(
      'both auto and manual assignments occur; safety/other are always manual',
      () {
        expect(assigned.any((c) => c.assignment!.isManual), isTrue);
        expect(assigned.any((c) => !c.assignment!.isManual), isTrue);
        for (final c in assigned) {
          if (!c.category.autoRoutable) {
            expect(c.assignment!.isManual, isTrue, reason: c.id);
          }
        }
        // A routable category sent to a different department (override).
        expect(
          assigned.any(
            (c) => c.category.autoRoutable && c.assignment!.isManual,
          ),
          isTrue,
        );
      },
    );

    test('every department receives work', () {
      expect(
        assigned.map((c) => c.assignment!.department).toSet(),
        Department.values.toSet(),
      );
    });

    test('assignedBy is a verifier/admin and matches an assignment event', () {
      for (final c in assigned) {
        final a = c.assignment!;
        final by = usersById[a.assignedBy];
        expect(by, isNotNull, reason: c.id);
        expect(by!.role, anyOf(UserRole.verifier, UserRole.admin));
        expect(
          c.timeline.any(
            (e) => e.at == a.assignedAt && e.actorId == a.assignedBy,
          ),
          isTrue,
          reason: '${c.id}: no event by ${a.assignedBy} at ${a.assignedAt}',
        );
        if (a.isManual) {
          expect(
            by.role,
            UserRole.admin,
            reason: 'P5: only an admin goes manual',
          );
        }
      }
    });

    test('assignees are maintenance staff of the assigned department (P4)', () {
      for (final c in assigned) {
        final id = c.assignment!.assigneeId;
        if (id == null) continue;
        final u = usersById[id];
        expect(u, isNotNull, reason: c.id);
        expect(u!.role, UserRole.maintenance);
        expect(u.department, c.assignment!.department, reason: c.id);
      }
    });

    test('work in progress or beyond is claimed by a department member', () {
      for (final c in seed.complaints) {
        if (c.status.order < ComplaintStatus.inProgress.order) continue;
        expect(c.assignment!.assigneeId, isNotNull, reason: c.id);
      }
    });

    test(
      'maintenance actors belong to the department that owns the work (P6)',
      () {
        for (final c in seed.complaints) {
          final lastAssigned = c.timeline.lastIndexWhere(
            (e) => e.status == ComplaintStatus.assigned,
          );
          for (var i = 0; i < c.timeline.length; i++) {
            final e = c.timeline[i];
            if (e.actorRole != UserRole.maintenance) continue;
            final actor = usersById[e.actorId]!;
            expect(actor.role, UserRole.maintenance);
            if (i > lastAssigned) {
              expect(
                actor.department,
                c.assignment!.department,
                reason: '${c.id} #$i',
              );
            }
          }
        }
      },
    );

    test(
      'scenario coverage: auto-route, manual triage, pick, pull-back, annotation',
      () {
        // W1: auto-routed note.
        expect(
          seed.complaints.any(
            (c) => c.timeline.any(
              (e) => (e.note ?? '').startsWith('Auto-routed to '),
            ),
          ),
          isTrue,
        );
        // W4/W6: safety / other resting in `reviewed`, awaiting admin triage.
        final waiting = seed.complaints.where(
          (c) => c.status == ComplaintStatus.reviewed,
        );
        expect(waiting, hasLength(3));
        expect(
          waiting.every(
            (c) => !c.category.autoRoutable && c.assignment == null,
          ),
          isTrue,
        );
        // W7: admin picks a specific staff member before work starts.
        expect(
          seed.complaints.any(
            (c) =>
                c.status == ComplaintStatus.assigned &&
                c.assignment!.assigneeId != null,
          ),
          isTrue,
        );
        // Unclaimed assigned work exists (maintenance "To start").
        expect(
          seed.complaints.any(
            (c) =>
                c.status == ComplaintStatus.assigned &&
                c.assignment!.assigneeId == null,
          ),
          isTrue,
        );
        // W12: T8 pull-back (inProgress -> assigned).
        expect(
          seed.complaints.any((c) {
            for (var i = 1; i < c.timeline.length; i++) {
              if (c.timeline[i - 1].status == ComplaintStatus.inProgress &&
                  c.timeline[i].status == ComplaintStatus.assigned) {
                return true;
              }
            }
            return false;
          }),
          isTrue,
        );
        // W11: annotation reassign while `assigned`.
        expect(
          seed.complaints.any(
            (c) => c.timeline.any(
              (e) => (e.note ?? '').startsWith('Reassigned: '),
            ),
          ),
          isTrue,
        );
      },
    );
  });

  group('timelines (status-machine-spec §7)', () {
    test('TL-1: starts with the reporter creating the complaint', () {
      for (final c in seed.complaints) {
        final first = c.timeline.first;
        expect(first.status, ComplaintStatus.reported, reason: c.id);
        expect(first.actorRole, UserRole.reporter, reason: c.id);
        expect(first.actorId, c.reporter.userId, reason: c.id);
        expect(first.at, c.createdAt, reason: c.id);
      }
    });

    test('TL-2: timestamps never decrease', () {
      for (final c in seed.complaints) {
        for (var i = 1; i < c.timeline.length; i++) {
          expect(
            c.timeline[i].at.isBefore(c.timeline[i - 1].at),
            isFalse,
            reason: '${c.id} #$i',
          );
        }
      }
    });

    test('TL-3: every status change replays through canTransition', () {
      for (final c in seed.complaints) {
        for (var i = 1; i < c.timeline.length; i++) {
          final prev = c.timeline[i - 1];
          final next = c.timeline[i];
          if (next.status == prev.status) continue; // annotation event
          expect(
            StatusMachine.canTransition(
              prev.status,
              next.status,
              next.actorRole,
            ),
            isTrue,
            reason:
                '${c.id} #$i: ${prev.status.name} -> ${next.status.name} '
                'by ${next.actorRole.name}',
          );
        }
      }
    });

    test(
      'annotation events exist only as "Reassigned" notes while assigned',
      () {
        for (final c in seed.complaints) {
          for (var i = 1; i < c.timeline.length; i++) {
            final prev = c.timeline[i - 1];
            final next = c.timeline[i];
            if (next.status != prev.status) continue;
            expect(next.status, ComplaintStatus.assigned, reason: c.id);
            expect(next.actorRole, UserRole.admin, reason: c.id);
            expect(next.note, startsWith('Reassigned: '), reason: c.id);
          }
        }
      },
    );

    test('TL-4: the last event is the current status', () {
      for (final c in seed.complaints) {
        expect(c.timeline.last.status, c.status, reason: c.id);
        expect(c.updatedAt, c.timeline.last.at, reason: c.id);
      }
    });

    test('TL-5: closed complaints went through resolved, verified, closed', () {
      final closed = seed.complaints.where(
        (c) => c.status == ComplaintStatus.closed,
      );
      expect(closed, isNotEmpty);
      for (final c in closed) {
        final r = c.timeline.indexWhere(
          (e) => e.status == ComplaintStatus.resolved,
        );
        final v = c.timeline.indexWhere(
          (e) => e.status == ComplaintStatus.verified,
        );
        final k = c.timeline.indexWhere(
          (e) => e.status == ComplaintStatus.closed,
        );
        expect(r, greaterThanOrEqualTo(0), reason: c.id);
        expect(v, greaterThan(r), reason: c.id);
        expect(k, greaterThan(v), reason: c.id);
      }
    });

    test('TL-6: status only moves backward through T7 and T8', () {
      for (final c in seed.complaints) {
        for (var i = 1; i < c.timeline.length; i++) {
          final prev = c.timeline[i - 1].status;
          final next = c.timeline[i].status;
          if (next.order >= prev.order) continue;
          final isT7 =
              prev == ComplaintStatus.resolved &&
              next == ComplaintStatus.inProgress;
          final isT8 =
              prev == ComplaintStatus.inProgress &&
              next == ComplaintStatus.assigned;
          expect(
            isT7 || isT8,
            isTrue,
            reason: '${c.id} #$i: ${prev.name} -> ${next.name}',
          );
        }
      }
    });

    test('TL-7: every T7 / T8 event carries a note', () {
      var backward = 0;
      for (final c in seed.complaints) {
        for (var i = 1; i < c.timeline.length; i++) {
          if (c.timeline[i].status.order < c.timeline[i - 1].status.order) {
            backward++;
            expect((c.timeline[i].note ?? '').trim(), isNotEmpty, reason: c.id);
          }
        }
      }
      expect(
        backward,
        greaterThanOrEqualTo(3),
        reason: '2 rework loops + 1 pull-back',
      );
    });

    test(
      'rework loops: a rejected-and-resolved and a rejected-pending complaint exist',
      () {
        bool hasReject(Complaint c) {
          for (var i = 1; i < c.timeline.length; i++) {
            if (c.timeline[i - 1].status == ComplaintStatus.resolved &&
                c.timeline[i].status == ComplaintStatus.inProgress) {
              return true;
            }
          }
          return false;
        }

        final rejected = seed.complaints.where(hasReject).toList();
        expect(
          rejected.any((c) => c.status == ComplaintStatus.inProgress),
          isTrue,
        );
        expect(
          rejected.any((c) => c.status.order >= ComplaintStatus.resolved.order),
          isTrue,
        );
      },
    );

    test(
      'event ids are unique; every actor is a seeded user in the right role',
      () {
        final ids = <String>{};
        for (final c in seed.complaints) {
          for (final e in c.timeline) {
            expect(ids.add(e.id), isTrue, reason: 'duplicate event id ${e.id}');
            final actor = usersById[e.actorId];
            expect(actor, isNotNull, reason: '${c.id}: ${e.actorId}');
            expect(actor!.role, e.actorRole, reason: '${c.id}: ${e.id}');
          }
        }
      },
    );

    test('T4 events copy the resolution note onto the timeline', () {
      for (final c in seed.complaints) {
        final resolves = c.timeline
            .where((e) => e.status == ComplaintStatus.resolved)
            .toList();
        for (final e in resolves) {
          expect((e.note ?? '').trim(), isNotEmpty, reason: c.id);
        }
        if (resolves.isNotEmpty &&
            c.status.order >= ComplaintStatus.resolved.order) {
          expect(c.resolutionNote, resolves.last.note, reason: c.id);
        }
      }
    });

    test('closed complaints reject every transition (INV-4 / P8)', () {
      for (final c in seed.complaints.where(
        (c) => c.status == ComplaintStatus.closed,
      )) {
        for (final to in ComplaintStatus.values) {
          final r = StatusMachine.validateTransition(
            c,
            to,
            seed.usersWithRole(UserRole.admin).single,
            const TransitionRequest(expectedFrom: ComplaintStatus.closed),
          );
          expect(r.ok, isFalse, reason: '${c.id} -> ${to.name}');
        }
      }
    });
  });

  group('invariants (status-machine-spec §7)', () {
    test('INV-1: assigned and later statuses always have an assignment', () {
      for (final c in seed.complaints) {
        if (c.status.order >= ComplaintStatus.assigned.order) {
          expect(c.assignment, isNotNull, reason: c.id);
        } else {
          expect(
            c.assignment,
            isNull,
            reason: '${c.id}: AR-1, none before assigned',
          );
        }
      }
    });

    test('INV-2: an auto-routable complaint never rests in reviewed', () {
      for (final c in seed.complaints.where(
        (c) => c.status == ComplaintStatus.reviewed,
      )) {
        expect(routeToDepartment(c.category), isNull, reason: c.id);
      }
    });

    test(
      'INV-3: resolved / verified / closed have fresh after-photos and a note',
      () {
        final admin = seed.usersWithRole(UserRole.admin).single;
        final done = seed.complaints.where(isResolvedOrBeyond).toList();
        expect(done, hasLength(12));
        for (final c in done) {
          expect(c.afterPhotos, isNotEmpty, reason: c.id);
          expect((c.resolutionNote ?? '').trim(), isNotEmpty, reason: c.id);
          expect(c.resolutionNote!.length, lessThanOrEqualTo(500));
          // The real L2 check: P1 (fresh evidence) + P2 (note) hold. T5 re-checks
          // exactly these on the persisted complaint.
          final r = StatusMachine.validateTransition(
            c.copyWith(status: ComplaintStatus.resolved),
            ComplaintStatus.verified,
            admin,
            const TransitionRequest(expectedFrom: ComplaintStatus.resolved),
          );
          expect(r.ok, isTrue, reason: '${c.id}: ${r.codes}');
        }
      },
    );

    test('INV-3 negative control: the check is not vacuous', () {
      final admin = seed.usersWithRole(UserRole.admin).single;
      final c = seed.complaints.firstWhere(
        (c) => c.status == ComplaintStatus.resolved,
      );
      ValidationResult verify(Complaint x) => StatusMachine.validateTransition(
        x.copyWith(status: ComplaintStatus.resolved),
        ComplaintStatus.verified,
        admin,
        const TransitionRequest(expectedFrom: ComplaintStatus.resolved),
      );
      expect(verify(c).ok, isTrue);
      expect(verify(c.copyWith(afterPhotos: const [])).codes, contains('P1'));
      expect(
        verify(c.copyWith(clearResolutionNote: true)).codes,
        contains('P2'),
      );
    });

    test(
      'INV-3 (rework): a stale photo from before the reject does not count',
      () {
        // Complaints that were rejected and re-resolved carry fresh evidence.
        final admin = seed.usersWithRole(UserRole.admin).single;
        final reworked = seed.complaints.where((c) {
          if (c.status.order < ComplaintStatus.resolved.order) return false;
          for (var i = 1; i < c.timeline.length; i++) {
            if (c.timeline[i - 1].status == ComplaintStatus.resolved &&
                c.timeline[i].status == ComplaintStatus.inProgress) {
              return true;
            }
          }
          return false;
        }).toList();
        expect(reworked, isNotEmpty);
        for (final c in reworked) {
          expect(
            c.afterPhotos.length,
            greaterThanOrEqualTo(2),
            reason: 'history kept',
          );
          final firstPhotoOnly = c.copyWith(afterPhotos: [c.afterPhotos.first]);
          final r = StatusMachine.validateTransition(
            firstPhotoOnly.copyWith(status: ComplaintStatus.resolved),
            ComplaintStatus.verified,
            admin,
            const TransitionRequest(expectedFrom: ComplaintStatus.resolved),
          );
          expect(
            r.codes,
            contains('P1'),
            reason: '${c.id}: stale evidence rejected',
          );
        }
      },
    );

    test('INV-3 (verified -> closed): a verified complaint can be closed', () {
      final admin = seed.usersWithRole(UserRole.admin).single;
      for (final c in seed.complaints.where(
        (c) => c.status == ComplaintStatus.verified,
      )) {
        final r = StatusMachine.validateTransition(
          c,
          ComplaintStatus.closed,
          admin,
          const TransitionRequest(expectedFrom: ComplaintStatus.verified),
        );
        expect(r.ok, isTrue, reason: '${c.id}: ${r.codes}');
      }
    });

    test(
      'INV-5: priority is the engine output (aged while unresolved, frozen after)',
      () {
        for (final c in seed.complaints) {
          expect(c.priority, expectedPriority(c, seed.now), reason: c.id);
        }
      },
    );

    test(
      'aging (§6) is visible: old unresolved complaints outrank their fresh score',
      () {
        final aged = seed.complaints.where((c) {
          if (!isUnresolved(c)) return false;
          final fresh = computePriority(
            PriorityInputs(
              category: c.category,
              safetyFlag: c.safetyFlag,
              severity: c.severity,
              peopleAffected: c.peopleAffected,
            ),
          );
          return c.priority.weight > fresh.weight;
        }).toList();
        expect(aged, isNotEmpty);
        // At least one has waited beyond the 14-day "neglected" bucket.
        expect(
          aged.any((c) => c.waitingTime(seed.now) >= const Duration(days: 14)),
          isTrue,
        );
      },
    );

    test(
      'frozen priorities (INV-5) differ from a now-based recompute somewhere',
      () {
        // Proves the seed distinguishes freezing from recomputing on read.
        final differing = seed.complaints.where(isResolvedOrBeyond).where((c) {
          final nowBased = computePriority(
            PriorityInputs(
              category: c.category,
              safetyFlag: c.safetyFlag,
              severity: c.severity,
              peopleAffected: c.peopleAffected,
              waitingTime: c.waitingTime(seed.now),
            ),
          );
          return nowBased != c.priority;
        });
        expect(differing, isNotEmpty);
      },
    );

    test(
      'priority overrides: raised and lowered, set only by an admin reviewer',
      () {
        final overridden = seed.complaints
            .where((c) => c.priorityOverride != null)
            .toList();
        expect(
          overridden.any((c) => c.priorityOverride!.weight > c.priority.weight),
          isTrue,
        );
        expect(
          overridden.any((c) => c.priorityOverride!.weight < c.priority.weight),
          isTrue,
        );
        for (final c in overridden) {
          expect(c.effectivePriority, c.priorityOverride, reason: c.id);
          final review = c.timeline.firstWhere(
            (e) => e.status == ComplaintStatus.reviewed,
          );
          expect(review.actorRole, UserRole.admin, reason: c.id);
        }
      },
    );

    test('safety rules hold on the stored priorities', () {
      for (final c in seed.complaints) {
        if (c.safetyFlag) {
          expect(
            c.priority.weight,
            greaterThanOrEqualTo(Priority.high.weight),
            reason: c.id,
          );
          if (c.severity == Severity.severe ||
              c.peopleAffected == PeopleAffected.campusWide) {
            expect(c.priority, Priority.critical, reason: c.id);
          }
        }
      }
    });
  });

  group('notifications', () {
    final byId = {for (final c in seed.complaints) c.id: c};

    test('a realistic feed exists, covers every type, with unique ids', () {
      expect(seed.notifications, isNotEmpty);
      expect(
        seed.notifications.map((n) => n.type).toSet(),
        NotificationType.values.toSet(),
      );
      expect(
        seed.notifications.map((n) => n.id).toSet(),
        hasLength(seed.notifications.length),
      );
      expect(seed.notifications.any((n) => n.read), isTrue);
      expect(seed.notifications.any((n) => !n.read), isTrue);
    });

    test('recipients and complaints exist; sorted oldest first', () {
      for (var i = 0; i < seed.notifications.length; i++) {
        final n = seed.notifications[i];
        expect(usersById[n.recipientId], isNotNull, reason: n.id);
        expect(byId[n.complaintId], isNotNull, reason: n.id);
        expect(n.title.trim(), isNotEmpty);
        expect(n.body.trim(), isNotEmpty);
        expect(n.body, contains(n.complaintId), reason: n.id);
        expect(n.createdAt.isAfter(seed.now), isFalse);
        if (i > 0) {
          expect(
            n.createdAt.isBefore(seed.notifications[i - 1].createdAt),
            isFalse,
            reason: n.id,
          );
        }
      }
    });

    test('read flag: older than 36 hours is read, newer is unread', () {
      for (final n in seed.notifications) {
        expect(
          n.read,
          seed.now.difference(n.createdAt) > const Duration(hours: 36),
          reason: n.id,
        );
      }
    });

    test('every timeline event notifies the complaint owner exactly once', () {
      for (final c in seed.complaints) {
        final mine = seed.notifications
            .where(
              (n) =>
                  n.complaintId == c.id && n.recipientId == c.reporter.userId,
            )
            .toList();
        expect(mine, hasLength(c.timeline.length), reason: c.id);
        final times = mine.map((n) => n.createdAt).toList()..sort();
        expect(
          times,
          c.timeline.map((e) => e.at).toList()..sort(),
          reason: c.id,
        );
      }
    });

    test('an owner\'s items for a complaint appear in timeline order', () {
      for (final c in seed.complaints) {
        final mine = seed.notifications
            .where(
              (n) =>
                  n.complaintId == c.id && n.recipientId == c.reporter.userId,
            )
            .toList();
        expect(
          mine.map((n) => n.createdAt).toList(),
          c.timeline.map((e) => e.at).toList(),
          reason: c.id,
        );
        // Review & Route writes two events at the same instant; the feed
        // keeps them in event order.
        for (var i = 0; i + 1 < c.timeline.length; i++) {
          if (c.timeline[i].status == ComplaintStatus.reviewed &&
              c.timeline[i + 1].status == ComplaintStatus.assigned) {
            expect(mine[i].title, 'Complaint reviewed', reason: c.id);
            expect(mine[i + 1].title, 'Complaint assigned', reason: c.id);
          }
        }
      }
    });

    test('reporters only ever hear about their own complaints', () {
      for (final n in seed.notifications) {
        if (usersById[n.recipientId]!.role != UserRole.reporter) continue;
        expect(
          byId[n.complaintId]!.reporter.userId,
          n.recipientId,
          reason: n.id,
        );
      }
    });

    test(
      'AC-31: a resolution notifies owner and verifiers, never maintenance',
      () {
        for (final c in seed.complaints) {
          for (final e in c.timeline.where(
            (e) => e.status == ComplaintStatus.resolved,
          )) {
            final at = seed.notifications
                .where((n) => n.complaintId == c.id && n.createdAt == e.at)
                .toList();
            final recipients = at.map((n) => n.recipientId).toSet();
            expect(recipients, contains(c.reporter.userId));
            for (final v in seed.usersWithRole(UserRole.verifier)) {
              expect(recipients, contains(v.id), reason: c.id);
            }
            expect(
              recipients.map((id) => usersById[id]!.role),
              isNot(contains(UserRole.maintenance)),
              reason: c.id,
            );
            expect(
              at.every((n) => n.type == NotificationType.completion),
              isTrue,
              reason: c.id,
            );
          }
        }
      },
    );

    test('assignment sends the assigned department the work details', () {
      var checked = 0;
      for (final c in seed.complaints) {
        // The event that last put the work in front of its current department
        // (T2, a pull-back T8, or a reassignment annotation).
        final idx = c.timeline.lastIndexWhere(
          (e) => e.status == ComplaintStatus.assigned,
        );
        if (idx < 0) continue;
        final at = c.timeline[idx].at;
        final staff = seed.users.where(
          (u) =>
              u.role == UserRole.maintenance &&
              u.department == c.assignment!.department,
        );
        for (final u in staff) {
          final n = seed.notifications.singleWhere(
            (n) =>
                n.recipientId == u.id &&
                n.complaintId == c.id &&
                n.createdAt == at &&
                n.type == NotificationType.assignment,
            orElse: () => throw TestFailure('${c.id}: no item for ${u.id}'),
          );
          expect(n.body, startsWith('New work: ${c.id} \u2014 '));
          expect(n.body, contains(c.building));
          expect(n.body, contains(c.room));
          checked++;
        }
      }
      expect(checked, greaterThan(20));
    });

    test('rework notifies the department with the rejection note', () {
      var seen = 0;
      for (final c in seed.complaints) {
        for (var i = 1; i < c.timeline.length; i++) {
          final prev = c.timeline[i - 1];
          final e = c.timeline[i];
          if (prev.status != ComplaintStatus.resolved ||
              e.status != ComplaintStatus.inProgress) {
            continue;
          }
          seen++;
          final dept = c.assignment!.department;
          final staffIds = seed.users
              .where(
                (u) => u.role == UserRole.maintenance && u.department == dept,
              )
              .map((u) => u.id)
              .toSet();
          final deptNotes = seed.notifications.where(
            (n) =>
                n.complaintId == c.id &&
                n.createdAt == e.at &&
                staffIds.contains(n.recipientId),
          );
          expect(deptNotes, hasLength(staffIds.length), reason: c.id);
          for (final n in deptNotes) {
            expect(n.body, startsWith('Rework needed on ${c.id}: '));
            expect(n.body, contains(e.note!.replaceAll(RegExp(r'\.$'), '')));
          }
        }
      }
      expect(seen, 2);
    });

    test('verifiers only receive "ready to verify" items', () {
      final verifierIds = seed
          .usersWithRole(UserRole.verifier)
          .map((u) => u.id)
          .toSet();
      final theirs = seed.notifications.where(
        (n) => verifierIds.contains(n.recipientId),
      );
      expect(theirs, isNotEmpty);
      for (final n in theirs) {
        expect(n.body, endsWith('is ready to verify.'), reason: n.id);
      }
    });

    test('admins have no notification feed in v1', () {
      final adminId = seed.usersWithRole(UserRole.admin).single.id;
      expect(seed.notifications.any((n) => n.recipientId == adminId), isFalse);
    });

    test('every notification survives a JSON round-trip', () {
      for (final n in seed.notifications) {
        expect(
          AppNotification.fromJson(
            jsonDecode(jsonEncode(n.toJson())) as Map<String, Object?>,
          ),
          n,
        );
      }
    });
  });
}
