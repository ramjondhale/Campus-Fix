import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_core/logic/assignment_router.dart';
import 'package:test/test.dart';

void main() {
  group('routeToDepartment - category table (spec §2)', () {
    const table = <ProblemCategory, Department?>{
      ProblemCategory.electrical: Department.electrician,
      ProblemCategory.plumbing: Department.plumber,
      ProblemCategory.civil: Department.civilMaintenance,
      ProblemCategory.furniture: Department.carpenter,
      ProblemCategory.cleanliness: Department.housekeeping,
      ProblemCategory.it: Department.itTeam,
      ProblemCategory.safety: null,
      ProblemCategory.other: null,
    };

    test('table covers all 8 categories', () {
      expect(table.keys.toSet(), ProblemCategory.values.toSet());
      expect(ProblemCategory.values, hasLength(8));
    });

    for (final entry in table.entries) {
      test('${entry.key.name} -> ${entry.value?.name ?? 'null'}', () {
        expect(routeToDepartment(entry.key), entry.value);
      });
    }

    test('route labels match the spec table', () {
      const labels = <ProblemCategory, String>{
        ProblemCategory.electrical: 'Electrician',
        ProblemCategory.plumbing: 'Plumber',
        ProblemCategory.civil: 'Civil Maintenance',
        ProblemCategory.furniture: 'Carpenter',
        ProblemCategory.cleanliness: 'Housekeeping',
        ProblemCategory.it: 'IT Team',
      };
      for (final entry in labels.entries) {
        expect(routeToDepartment(entry.key)!.label, entry.value);
      }
    });

    test('null (manual triage) exactly for safety and other', () {
      final manualTriage = ProblemCategory.values
          .where((c) => routeToDepartment(c) == null)
          .toSet();
      expect(manualTriage, {ProblemCategory.safety, ProblemCategory.other});
    });

    test('is pure and total: repeated calls agree and never throw', () {
      for (final c in ProblemCategory.values) {
        expect(() => routeToDepartment(c), returnsNormally);
        expect(routeToDepartment(c), routeToDepartment(c));
      }
    });
  });

  group('routeToDepartment - consistency (spec §1, AR-OI-4)', () {
    test('equals ProblemCategory.defaultDepartment for every category', () {
      for (final c in ProblemCategory.values) {
        expect(routeToDepartment(c), c.defaultDepartment, reason: c.name);
      }
    });

    test('autoRoutable == (defaultDepartment != null) for every category', () {
      for (final c in ProblemCategory.values) {
        expect(c.autoRoutable, c.defaultDepartment != null, reason: c.name);
      }
    });

    test('autoRoutable == (routeToDepartment != null) for every category', () {
      for (final c in ProblemCategory.values) {
        expect(c.autoRoutable, routeToDepartment(c) != null, reason: c.name);
      }
    });

    test('coverage: each Department is the route of exactly one category', () {
      expect(Department.values, hasLength(6));
      for (final d in Department.values) {
        final routedHere = ProblemCategory.values
            .where((c) => routeToDepartment(c) == d)
            .toList();
        expect(routedHere, hasLength(1), reason: d.name);
      }
    });

    test('no two categories share a department', () {
      final routed = ProblemCategory.values
          .map(routeToDepartment)
          .whereType<Department>()
          .toList();
      expect(routed.toSet(), hasLength(routed.length));
      expect(routed.toSet(), Department.values.toSet());
    });
  });

  group('isManualAssignment - truth table (MA-2)', () {
    test(
      'auto-route department is NOT manual, for every routable category',
      () {
        for (final c in ProblemCategory.values.where((c) => c.autoRoutable)) {
          expect(
            isManualAssignment(c, routeToDepartment(c)!),
            isFalse,
            reason: c.name,
          );
        }
      },
    );

    test('any other department IS manual, for every routable category', () {
      for (final c in ProblemCategory.values.where((c) => c.autoRoutable)) {
        final route = routeToDepartment(c)!;
        for (final d in Department.values.where((d) => d != route)) {
          expect(
            isManualAssignment(c, d),
            isTrue,
            reason: '${c.name} -> ${d.name}',
          );
        }
      }
    });

    test('any department for safety/other IS manual (route is null)', () {
      for (final c in [ProblemCategory.safety, ProblemCategory.other]) {
        for (final d in Department.values) {
          expect(
            isManualAssignment(c, d),
            isTrue,
            reason: '${c.name} -> ${d.name}',
          );
        }
      }
    });

    test('full matrix: manual <=> chosen != route, all 8 x 6 pairs', () {
      var manual = 0;
      var auto = 0;
      for (final c in ProblemCategory.values) {
        for (final d in Department.values) {
          final expected = c.defaultDepartment != d;
          expect(isManualAssignment(c, d), expected);
          expected ? manual++ : auto++;
        }
      }
      // 6 routable categories each have exactly one auto pair.
      expect(auto, 6);
      expect(manual, 8 * 6 - 6);
    });
  });

  group('spec §8 worked scenarios (pure parts)', () {
    test('W1: electrical, auto-route -> electrician, isManual false', () {
      expect(
        routeToDepartment(ProblemCategory.electrical),
        Department.electrician,
      );
      expect(
        isManualAssignment(ProblemCategory.electrical, Department.electrician),
        isFalse,
      );
    });

    test('W2: plumbing, admin chooses carpenter -> isManual true', () {
      expect(routeToDepartment(ProblemCategory.plumbing), Department.plumber);
      expect(
        isManualAssignment(ProblemCategory.plumbing, Department.carpenter),
        isTrue,
      );
    });

    test(
      'W3: plumbing, admin chooses plumber explicitly -> isManual false',
      () {
        expect(
          isManualAssignment(ProblemCategory.plumbing, Department.plumber),
          isFalse,
        );
      },
    );

    test('W4: safety has no route (stops at reviewed, manual triage)', () {
      expect(routeToDepartment(ProblemCategory.safety), isNull);
      expect(ProblemCategory.safety.autoRoutable, isFalse);
    });

    test('W6: safety, admin assigns civilMaintenance -> isManual true', () {
      expect(
        isManualAssignment(ProblemCategory.safety, Department.civilMaintenance),
        isTrue,
      );
    });

    test('W7: other, admin assigns itTeam -> isManual true', () {
      expect(routeToDepartment(ProblemCategory.other), isNull);
      expect(
        isManualAssignment(ProblemCategory.other, Department.itTeam),
        isTrue,
      );
    });

    test('W11: electrical reassigned to itTeam -> isManual true (RA-8)', () {
      expect(
        isManualAssignment(ProblemCategory.electrical, Department.itTeam),
        isTrue,
      );
    });

    test('W12: civil reassigned to electrician -> isManual true (RA-8)', () {
      expect(
        routeToDepartment(ProblemCategory.civil),
        Department.civilMaintenance,
      );
      expect(
        isManualAssignment(ProblemCategory.civil, Department.electrician),
        isTrue,
      );
    });

    test(
      'RA-8: reassigning back to the routed department re-derives false',
      () {
        expect(
          isManualAssignment(
            ProblemCategory.civil,
            Department.civilMaintenance,
          ),
          isFalse,
        );
      },
    );

    // W5, W8-W10, W13, W14 depend on roles, status and assignee state; they
    // are enforced by the transition guard / ComplaintService (S2.3 / S2.7),
    // not by these pure functions.
  });
}
