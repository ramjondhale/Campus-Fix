import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

AppNotification note(
  String id, {
  String recipient = 'u-1',
  Duration after = Duration.zero,
  bool read = false,
}) => AppNotification(
  id: id,
  recipientId: recipient,
  complaintId: 'CF-2026-00001',
  type: NotificationType.statusChange,
  title: 'Title $id',
  body: 'Body $id',
  createdAt: t0.add(after),
  read: read,
);

void main() {
  final seed = SeedData.build();

  group('MockNotificationRepository', () {
    test('all() and byRecipient() are newest first', () async {
      final repo = MockNotificationRepository(
        initial: [
          note('a', after: const Duration(hours: 1)),
          note('b', after: const Duration(hours: 3)),
          note('c', after: const Duration(hours: 2), recipient: 'u-2'),
          note('d', after: const Duration(hours: 2)),
        ],
      );
      expect((await repo.all()).map((n) => n.id), ['b', 'd', 'c', 'a']);
      expect((await repo.byRecipient('u-1')).map((n) => n.id), ['b', 'd', 'a']);
      expect((await repo.byRecipient('u-2')).map((n) => n.id), ['c']);
      expect(await repo.byRecipient('nobody'), isEmpty);
    });

    test('ties on createdAt are broken by id, descending', () async {
      final repo = MockNotificationRepository(
        initial: [note('a'), note('c'), note('b')],
      );
      expect((await repo.all()).map((n) => n.id), ['c', 'b', 'a']);
    });

    test('add stores and returns the notification', () async {
      final repo = MockNotificationRepository();
      final n = note('x');
      expect(await repo.add(n), n);
      expect(await repo.all(), [n]);
      expect(await repo.byRecipient('u-1'), [n]);
    });

    test('add rejects a duplicate id', () async {
      final repo = MockNotificationRepository(initial: [note('x')]);
      await expectLater(repo.add(note('x')), throwsStateError);
      expect(await repo.all(), hasLength(1));
    });

    test('constructor rejects duplicate ids', () {
      expect(
        () => MockNotificationRepository(initial: [note('x'), note('x')]),
        throwsArgumentError,
      );
    });

    test('markRead returns the updated copy and persists it', () async {
      final repo = MockNotificationRepository(initial: [note('x')]);
      final updated = await repo.markRead('x');
      expect(updated, note('x', read: true));
      expect((await repo.byRecipient('u-1')).single.read, isTrue);
    });

    test('markRead is idempotent and null for unknown ids', () async {
      final repo = MockNotificationRepository(initial: [note('x')]);
      await repo.markRead('x');
      expect(await repo.markRead('x'), note('x', read: true));
      expect(await repo.markRead('missing'), isNull);
    });

    test('markAllRead touches only that recipient', () async {
      final repo = MockNotificationRepository(
        initial: [
          note('a'),
          note('b'),
          note('c', recipient: 'u-2'),
        ],
      );
      await repo.markAllRead('u-1');
      expect((await repo.byRecipient('u-1')).every((n) => n.read), isTrue);
      expect((await repo.byRecipient('u-2')).single.read, isFalse);
      await repo.markAllRead('nobody'); // no-op, no throw
    });

    test('seeded repository serves the seed notifications', () async {
      final repo = MockNotificationRepository.seeded(seed: seed);
      expect(await repo.all(), hasLength(seed.notifications.length));
      for (final u in seed.users) {
        final mine = await repo.byRecipient(u.id);
        expect(
          mine.map((n) => n.id).toSet(),
          seed.notifications
              .where((n) => n.recipientId == u.id)
              .map((n) => n.id)
              .toSet(),
        );
      }
    });
  });

  group('watchByRecipient', () {
    test('emits now, then on add / markRead / markAllRead', () async {
      final repo = MockNotificationRepository(initial: [note('a')]);
      final emissions = <List<String>>[];
      final sub = repo
          .watchByRecipient('u-1')
          .listen(
            (l) => emissions.add([for (final n in l) '${n.id}:${n.read}']),
          );
      await pumpEventQueue();
      expect(emissions, [
        ['a:false'],
      ]);

      await repo.add(note('b', after: const Duration(hours: 1)));
      await pumpEventQueue();
      expect(emissions.last, ['b:false', 'a:false']);

      await repo.markRead('a');
      await pumpEventQueue();
      expect(emissions.last, ['b:false', 'a:true']);

      await repo.markAllRead('u-1');
      await pumpEventQueue();
      expect(emissions.last, ['b:true', 'a:true']);

      await sub.cancel();
      await repo.add(note('c'));
      await pumpEventQueue();
      expect(emissions, hasLength(4));
    });

    test('only ever contains that recipient\'s notifications', () async {
      final repo = MockNotificationRepository();
      final seen = <List<String>>[];
      final sub = repo
          .watchByRecipient('u-2')
          .listen((l) => seen.add([for (final n in l) n.id]));
      await repo.add(note('a'));
      await repo.add(note('b', recipient: 'u-2'));
      await pumpEventQueue();
      expect(seen.every((l) => !l.contains('a')), isTrue);
      expect(seen.last, ['b']);
      await sub.cancel();
    });

    test('markRead of an already-read notification does not emit', () async {
      final repo = MockNotificationRepository(initial: [note('a', read: true)]);
      final counts = <int>[];
      final sub = repo
          .watchByRecipient('u-1')
          .listen((l) => counts.add(l.length));
      await pumpEventQueue();
      await repo.markRead('a');
      await repo.markRead('missing');
      await pumpEventQueue();
      expect(counts, [1]);
      await sub.cancel();
    });
  });

  test('latency delays calls', () async {
    final repo = MockNotificationRepository(
      latency: const Duration(milliseconds: 40),
    );
    final sw = Stopwatch()..start();
    await repo.all();
    await repo.byRecipient('u-1');
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));
  });
}
