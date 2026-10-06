import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final seed = SeedData.build();

  /// A prepared draft, as `ComplaintService` would hand it over.
  Complaint draft({String id = 'CF-2026-90001'}) =>
      minimalComplaint().copyWith(id: id);

  group('MockComplaintRepository (seeded)', () {
    late MockComplaintRepository repo;
    setUp(() => repo = MockComplaintRepository.seeded(seed: seed));

    test('all() returns the seed complaints in order', () async {
      expect(await repo.all(), seed.complaints);
    });

    test(
      'all() returns a copy: mutating it does not change the repo',
      () async {
        final list = await repo.all();
        list.clear();
        expect(await repo.all(), hasLength(seed.complaints.length));
      },
    );

    test('byId finds a complaint and returns null for unknown ids', () async {
      final c = seed.complaints[3];
      expect(await repo.byId(c.id), c);
      expect(await repo.byId('CF-2026-99999'), isNull);
      expect(await repo.byId(''), isNull);
    });

    test('byReporter returns exactly that reporter\'s complaints', () async {
      for (final r in seed.usersWithRole(UserRole.reporter)) {
        final expected = seed.complaints
            .where((c) => c.reporter.userId == r.id)
            .toList();
        final got = await repo.byReporter(r.id);
        expect(got, expected, reason: r.id);
        expect(got.every((c) => c.reporter.userId == r.id), isTrue);
      }
      // Every demo reporter has something to show in "My Complaints".
      expect(
        await repo.byReporter(seed.demoAccounts.first.user.id),
        hasLength(greaterThanOrEqualTo(3)),
      );
      expect(await repo.byReporter('nobody'), isEmpty);
    });

    test('byDepartment returns only complaints assigned to it', () async {
      var total = 0;
      for (final d in Department.values) {
        final got = await repo.byDepartment(d);
        expect(got, isNotEmpty, reason: d.name);
        expect(got.every((c) => c.assignment?.department == d), isTrue);
        expect(
          got,
          seed.complaints.where((c) => c.assignment?.department == d).toList(),
        );
        total += got.length;
      }
      // Unassigned complaints (reported / reviewed) appear under no department.
      final unassigned = seed.complaints.where((c) => c.assignment == null);
      expect(unassigned, isNotEmpty);
      expect(total, seed.complaints.length - unassigned.length);
    });

    test('byStatus returns only complaints in that status', () async {
      var total = 0;
      for (final s in ComplaintStatus.values) {
        final got = await repo.byStatus(s);
        expect(got, isNotEmpty, reason: s.name);
        expect(got.every((c) => c.status == s), isTrue);
        total += got.length;
      }
      expect(total, seed.complaints.length);
    });

    test('queries on an empty repository return empty lists', () async {
      final empty = MockComplaintRepository();
      expect(await empty.all(), isEmpty);
      expect(await empty.byReporter(reporter.userId), isEmpty);
      expect(await empty.byDepartment(Department.plumber), isEmpty);
      expect(await empty.byStatus(ComplaintStatus.reported), isEmpty);
    });
  });

  group('submit / update', () {
    late MockComplaintRepository repo;
    setUp(() => repo = MockComplaintRepository.seeded(seed: seed));

    test('submit persists the draft as-is and returns it', () async {
      // A draft whose priority the engine would NOT produce: the repository
      // must neither recompute it nor touch the id (that is S2.7's job).
      final d = draft().copyWith(priority: Priority.low);
      final stored = await repo.submit(d);
      expect(stored, d);
      expect(stored.id, 'CF-2026-90001');
      expect(stored.priority, Priority.low);
      expect(await repo.byId(d.id), d);
      expect(await repo.all(), hasLength(seed.complaints.length + 1));
      expect((await repo.all()).last, d);
    });

    test(
      'submit does not generate ids: ids are whatever the draft has',
      () async {
        final a = await repo.submit(draft(id: 'X-1'));
        final b = await repo.submit(draft(id: 'X-2'));
        expect([a.id, b.id], ['X-1', 'X-2']);
      },
    );

    test('submit rejects an id that already exists', () async {
      await expectLater(repo.submit(seed.complaints.first), throwsStateError);
      expect(await repo.all(), hasLength(seed.complaints.length));
    });

    test('a submitted complaint shows up in the queries', () async {
      final d = draft();
      await repo.submit(d);
      expect(await repo.byReporter(d.reporter.userId), contains(d));
      expect(await repo.byStatus(ComplaintStatus.reported), contains(d));
      expect(await repo.byDepartment(Department.plumber), isNot(contains(d)));
    });

    test('update round-trips and keeps the complaint\'s position', () async {
      final original = seed.complaints[5];
      final changed = original.copyWith(
        priorityOverride: Priority.critical,
        updatedAt: original.updatedAt.add(const Duration(hours: 1)),
      );
      final stored = await repo.update(changed);
      expect(stored, changed);
      expect(await repo.byId(original.id), changed);
      final all = await repo.all();
      expect(all, hasLength(seed.complaints.length));
      expect(all[5], changed);
    });

    test(
      'update moves a complaint between status / department queries',
      () async {
        final c = seed.complaints.firstWhere(
          (c) => c.status == ComplaintStatus.reported,
        );
        await repo.update(c.copyWith(status: ComplaintStatus.reviewed));
        expect(
          await repo.byStatus(ComplaintStatus.reviewed),
          contains(predicate<Complaint>((x) => x.id == c.id)),
        );
        expect(
          (await repo.byStatus(ComplaintStatus.reported)).map((x) => x.id),
          isNot(contains(c.id)),
        );
      },
    );

    test('update rejects an unknown complaint', () async {
      await expectLater(repo.update(draft()), throwsStateError);
      expect(await repo.all(), hasLength(seed.complaints.length));
    });

    test('constructor rejects duplicate ids', () {
      expect(
        () => MockComplaintRepository(initial: [draft(), draft()]),
        throwsArgumentError,
      );
    });
  });

  group('watchAll', () {
    test('emits the current list on listen, then after every change', () async {
      final repo = MockComplaintRepository(initial: [draft(id: 'A-1')]);
      final emissions = <List<String>>[];
      final sub = repo.watchAll().listen(
        (l) => emissions.add([for (final c in l) '${c.id}:${c.status.name}']),
      );
      await pumpEventQueue();
      expect(emissions, [
        ['A-1:reported'],
      ]);

      await repo.submit(draft(id: 'A-2'));
      await pumpEventQueue();
      expect(emissions.last, ['A-1:reported', 'A-2:reported']);

      await repo.update(
        draft(id: 'A-1').copyWith(status: ComplaintStatus.reviewed),
      );
      await pumpEventQueue();
      expect(emissions.last, ['A-1:reviewed', 'A-2:reported']);
      expect(emissions, hasLength(3));

      await sub.cancel();
      await repo.submit(draft(id: 'A-3'));
      await pumpEventQueue();
      expect(emissions, hasLength(3), reason: 'no emission after cancel');
    });

    test('works with expectLater and take()', () async {
      final repo = MockComplaintRepository();
      final done = expectLater(
        repo.watchAll().take(3).map((l) => l.length),
        emitsInOrder([0, 1, 2]),
      );
      await repo.submit(draft(id: 'B-1'));
      await repo.submit(draft(id: 'B-2'));
      await done;
    });

    test('every call is an independent stream', () async {
      final repo = MockComplaintRepository();
      final a = <int>[];
      final b = <int>[];
      final subA = repo.watchAll().listen((l) => a.add(l.length));
      await repo.submit(draft(id: 'C-1'));
      final subB = repo.watchAll().listen((l) => b.add(l.length));
      await repo.submit(draft(id: 'C-2'));
      await pumpEventQueue();
      expect(a, [0, 1, 2]);
      expect(b, [1, 2]);
      await subA.cancel();
      await repo.submit(draft(id: 'C-3'));
      await pumpEventQueue();
      expect(a, [0, 1, 2]);
      expect(b, [1, 2, 3]);
      await subB.cancel();
    });

    test('a failed write does not emit', () async {
      final repo = MockComplaintRepository(initial: [draft(id: 'D-1')]);
      final emissions = <int>[];
      final sub = repo.watchAll().listen((l) => emissions.add(l.length));
      await pumpEventQueue();
      await expectLater(repo.submit(draft(id: 'D-1')), throwsStateError);
      await expectLater(repo.update(draft(id: 'nope')), throwsStateError);
      await pumpEventQueue();
      expect(emissions, [1]);
      await sub.cancel();
    });
  });

  group('latency', () {
    test('a non-zero latency delays calls (screens-spec G-3)', () async {
      final repo = MockComplaintRepository(
        initial: [draft()],
        latency: const Duration(milliseconds: 40),
      );
      final sw = Stopwatch()..start();
      await repo.all();
      await repo.byId('CF-2026-90001');
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));
    });
  });
}
