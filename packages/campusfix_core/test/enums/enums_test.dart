import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProblemCategory', () {
    test('has the 8 spec values in order', () {
      expect(ProblemCategory.values.map((c) => c.name), [
        'electrical',
        'plumbing',
        'civil',
        'furniture',
        'cleanliness',
        'it',
        'safety',
        'other',
      ]);
    });

    test(
      'labels, default departments and autoRoutable match the spec table',
      () {
        const expected = {
          ProblemCategory.electrical: ('Electrical', Department.electrician),
          ProblemCategory.plumbing: (
            'Plumbing / Water / Washroom',
            Department.plumber,
          ),
          ProblemCategory.civil: (
            'Civil / Building',
            Department.civilMaintenance,
          ),
          ProblemCategory.furniture: ('Furniture', Department.carpenter),
          ProblemCategory.cleanliness: (
            'Cleanliness / Sanitation',
            Department.housekeeping,
          ),
          ProblemCategory.it: (
            'IT / Network / Projector / Computer',
            Department.itTeam,
          ),
          ProblemCategory.safety: ('Safety', null),
          ProblemCategory.other: ('Other', null),
        };
        expect(expected.keys, unorderedEquals(ProblemCategory.values));
        expected.forEach((category, meta) {
          expect(category.label, meta.$1, reason: category.name);
          expect(category.defaultDepartment, meta.$2, reason: category.name);
          expect(category.autoRoutable, meta.$2 != null, reason: category.name);
        });
      },
    );

    test('only safety and other need manual triage', () {
      final manual = ProblemCategory.values.where((c) => !c.autoRoutable);
      expect(manual, [ProblemCategory.safety, ProblemCategory.other]);
    });
  });

  group('Priority', () {
    test('weights run critical=4 .. low=1', () {
      expect(Priority.critical.weight, 4);
      expect(Priority.high.weight, 3);
      expect(Priority.medium.weight, 2);
      expect(Priority.low.weight, 1);
    });

    test('rank sorts most-urgent first and is consistent with weight', () {
      final sorted = [...Priority.values]
        ..sort((a, b) => a.rank.compareTo(b.rank));
      expect(sorted, [
        Priority.critical,
        Priority.high,
        Priority.medium,
        Priority.low,
      ]);
      for (final p in Priority.values) {
        expect(p.rank + p.weight, 4, reason: p.name);
      }
    });

    test('labels', () {
      expect(Priority.values.map((p) => p.label), [
        'Critical',
        'High',
        'Medium',
        'Low',
      ]);
    });
  });

  group('ComplaintStatus', () {
    test('is ordered reported..closed with order 0..6', () {
      expect(ComplaintStatus.values.map((s) => s.name), [
        'reported',
        'reviewed',
        'assigned',
        'inProgress',
        'resolved',
        'verified',
        'closed',
      ]);
      expect(ComplaintStatus.values.map((s) => s.order), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('labels', () {
      expect(ComplaintStatus.inProgress.label, 'In Progress');
      expect(ComplaintStatus.reported.label, 'Reported');
      expect(ComplaintStatus.closed.label, 'Closed');
    });

    test('only closed is terminal', () {
      expect(ComplaintStatus.values.where((s) => s.isTerminal), [
        ComplaintStatus.closed,
      ]);
    });
  });

  group('UserRole', () {
    test('has the 4 spec values', () {
      expect(UserRole.values.map((r) => r.name), [
        'reporter',
        'maintenance',
        'verifier',
        'admin',
      ]);
    });

    test('only admin can see reporter identity', () {
      expect(UserRole.admin.canSeeReporterIdentity, isTrue);
      expect(UserRole.reporter.canSeeReporterIdentity, isFalse);
      expect(UserRole.maintenance.canSeeReporterIdentity, isFalse);
      expect(UserRole.verifier.canSeeReporterIdentity, isFalse);
    });
  });

  group('Department', () {
    test('has the 6 spec values with labels', () {
      expect(Department.values.map((d) => d.name), [
        'electrician',
        'plumber',
        'carpenter',
        'civilMaintenance',
        'itTeam',
        'housekeeping',
      ]);
      expect(Department.civilMaintenance.label, 'Civil Maintenance');
      expect(Department.itTeam.label, 'IT Team');
      for (final d in Department.values) {
        expect(d.label, isNotEmpty);
      }
    });

    test(
      'every auto-routable category maps to a distinct-per-category dept',
      () {
        final depts = ProblemCategory.values
            .map((c) => c.defaultDepartment)
            .whereType<Department>()
            .toSet();
        expect(depts, Department.values.toSet());
      },
    );
  });

  group('Severity', () {
    test('weights are 1/2/3', () {
      expect(Severity.values.map((s) => s.name), [
        'minor',
        'moderate',
        'severe',
      ]);
      expect(Severity.values.map((s) => s.weight), [1, 2, 3]);
    });
  });

  group('PeopleAffected', () {
    test('weights are 1..4', () {
      expect(PeopleAffected.values.map((p) => p.name), [
        'individual',
        'small',
        'many',
        'campusWide',
      ]);
      expect(PeopleAffected.values.map((p) => p.weight), [1, 2, 3, 4]);
    });
  });

  group('AttachmentKind', () {
    test('has the 3 spec values', () {
      expect(AttachmentKind.values.map((k) => k.name), [
        'beforePhoto',
        'afterPhoto',
        'other',
      ]);
      for (final k in AttachmentKind.values) {
        expect(k.label, isNotEmpty);
      }
    });
  });
}
