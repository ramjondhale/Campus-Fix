import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  final seed = SeedData.build();
  late MockUserRepository repo;
  setUp(() => repo = MockUserRepository.seeded(seed: seed));

  group('MockUserRepository', () {
    test('all() returns every seeded user', () async {
      expect(await repo.all(), seed.users);
    });

    test(
      'byId resolves every seed id and returns null for unknown ones',
      () async {
        for (final u in seed.users) {
          expect(await repo.byId(u.id), u);
        }
        expect(await repo.byId('nobody'), isNull);
      },
    );

    test(
      'maintenanceByDepartment lists only that department\'s staff',
      () async {
        for (final d in Department.values) {
          final staff = await repo.maintenanceByDepartment(d);
          expect(staff, hasLength(2), reason: '${d.name}: one user + a peer');
          expect(staff.every((u) => u.role == UserRole.maintenance), isTrue);
          expect(staff.every((u) => u.department == d), isTrue);
        }
      },
    );

    test(
      'maintenanceByDepartment excludes other roles with a department',
      () async {
        final odd = [
          const AppUser(
            id: 'v-1',
            idNumber: 'V-1',
            displayName: 'Verifier With Dept',
            role: UserRole.verifier,
            email: 'v@campus.test',
            department: Department.plumber,
          ),
          const AppUser(
            id: 'm-1',
            idNumber: 'M-1',
            displayName: 'Plumber One',
            role: UserRole.maintenance,
            email: 'm@campus.test',
            department: Department.plumber,
          ),
        ];
        final r = MockUserRepository(odd);
        expect(
          (await r.maintenanceByDepartment(
            Department.plumber,
          )).map((u) => u.id),
          ['m-1'],
        );
        expect(await r.maintenanceByDepartment(Department.itTeam), isEmpty);
      },
    );

    test('constructor rejects duplicate ids', () {
      expect(
        () => MockUserRepository([seed.users.first, seed.users.first]),
        throwsArgumentError,
      );
    });

    test('latency delays calls', () async {
      final r = MockUserRepository(
        seed.users,
        latency: const Duration(milliseconds: 40),
      );
      final sw = Stopwatch()..start();
      await r.all();
      await r.byId('u-adm-01');
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));
    });
  });
}
