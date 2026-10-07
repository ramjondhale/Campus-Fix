import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/app.dart' show noAutoRetry;
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/work_fixtures.dart';

/// A container wired like the app with [repository] as the complaint store,
/// the demo maintenance worker signed in and the write controller kept alive (it is
/// auto-disposed, so something must listen).
Future<ProviderContainer> workContainer({
  ComplaintRepository? repository,
  UserRole role = UserRole.maintenance,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      ...testOverrides(),
      complaintRepositoryProvider.overrideWithValue(
        repository ?? workRepository(),
      ),
    ],
    retry: noAutoRetry,
  );
  addTearDown(container.dispose);
  final MockAccount account = demoAccount(role);
  await container
      .read(sessionProvider.notifier)
      .signIn(account.user.idNumber, account.password);
  container.listen<WorkActionState>(workActionProvider, (_, _) {});
  return container;
}

Attachment afterPhoto(String id, {DateTime? at}) => Attachment(
  id: id,
  kind: AttachmentKind.afterPhoto,
  ref: 'assets/samples/after_sample_1.jpg',
  createdAt: at ?? DateTime.now(),
);

Future<Complaint> stored(ProviderContainer c, String id) async =>
    (await c.read(complaintRepositoryProvider).byId(id))!;

void main() {
  group('Start work (T3)', () {
    test('claims the job: inProgress, one maintenance event, note kept '
        '(AC-35)', () async {
      final ProviderContainer container = await workContainer();
      final Complaint before = await stored(container, toStartA);

      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .startWork(toStartA, note: '  On my way  ');

      expect(result!.ok, isTrue);
      expect(result.messages, isEmpty);
      expect(container.read(workActionProvider).status, WorkActionStatus.idle);
      final Complaint after = await stored(container, toStartA);
      expect(after.status, ComplaintStatus.inProgress);
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.actorRole, UserRole.maintenance);
      expect(after.timeline.last.note, 'On my way');
      expect(after.assignment!.assigneeId, meId, reason: 'CL-1 claims it');
    });

    test('a colleague already holds it: blocked with the P7 message, '
        'nothing changed (AC-36)', () async {
      final ProviderContainer container = await workContainer();
      final Complaint before = await stored(container, assignedToColleague);

      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .startWork(assignedToColleague);

      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(result.messages, contains('Already claimed by a colleague.'));
      final WorkActionState state = container.read(workActionProvider);
      expect(
        state.failedFor(assignedToColleague, WorkActionKind.startWork),
        isTrue,
      );
      expect(state.blocked, isTrue);
      expect(await stored(container, assignedToColleague), before);
    });

    test('another department\'s job is blocked (P6)', () async {
      final ProviderContainer container = await workContainer();
      // A plumber's job, put back to `assigned`, is not the demo worker's.
      final Complaint plumbing = (await stored(
        container,
        plumberJob,
      )).copyWith(status: ComplaintStatus.assigned);
      await container.read(complaintRepositoryProvider).update(plumbing);

      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .startWork(plumberJob);

      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(
        result.messages,
        contains('This work belongs to another department.'),
      );
    });

    test('an unknown id is a friendly block, not a crash', () async {
      final ProviderContainer container = await workContainer();
      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .startWork('CF-2026-99999');
      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(result.messages, <String>["We couldn't find that complaint."]);
    });

    test('only maintenance staff can act', () async {
      final ProviderContainer container = await workContainer(
        role: UserRole.reporter,
      );
      final Complaint before = await stored(container, toStartA);
      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .startWork(toStartA);
      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(result.messages, <String>['Only maintenance staff can do this.']);
      expect(await stored(container, toStartA), before);
    });

    test('a failed write is reported generically and can be dismissed '
        '(G-4)', () async {
      final ProviderContainer container = await workContainer(
        repository: FlakyWriteComplaintRepository(initial: workSeed()),
      );
      final WorkActionNotifier controller = container.read(
        workActionProvider.notifier,
      );

      final WorkActionResult? failed = await controller.startWork(toStartA);
      expect(failed!.outcome, WorkActionOutcome.failed);
      expect(failed.messages.single, contains("couldn't start the work"));
      expect(failed.messages.single, isNot(contains('StateError')));
      expect(
        container
            .read(workActionProvider)
            .failedFor(toStartA, WorkActionKind.startWork),
        isTrue,
      );
      expect(container.read(workActionProvider).blocked, isFalse);

      controller.clearError();
      expect(container.read(workActionProvider).status, WorkActionStatus.idle);

      // The retry goes through (the outage was one write).
      expect((await controller.startWork(toStartA))!.ok, isTrue);
    });

    test('a second tap while one is in flight is ignored (G-3)', () async {
      final SlowWriteComplaintRepository slow = SlowWriteComplaintRepository(
        initial: workSeed(),
      );
      final ProviderContainer container = await workContainer(repository: slow);
      final WorkActionNotifier controller = container.read(
        workActionProvider.notifier,
      );

      final Future<WorkActionResult?> first = controller.startWork(toStartA);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(workActionProvider)
            .runningFor(toStartA, WorkActionKind.startWork),
        isTrue,
      );
      expect(await controller.startWork(toStartA), isNull);
      expect(await controller.startWork(toStartB), isNull);

      slow.release();
      expect((await first)!.ok, isTrue);
      expect(slow.writes, 1);
    });
  });

  group('Mark resolved (T4)', () {
    test('stores the note and photos and appends one event whose note is '
        'the resolution note (AC-39)', () async {
      final ProviderContainer container = await workContainer();
      final Complaint before = await stored(container, inProgressJob);

      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .resolve(
            inProgressJob,
            resolutionNote: '  Replaced the fitting.  ',
            afterPhotos: <Attachment>[afterPhoto('after-test-1')],
          );

      expect(result!.ok, isTrue);
      final Complaint after = await stored(container, inProgressJob);
      expect(after.status, ComplaintStatus.resolved);
      expect(after.resolutionNote, 'Replaced the fitting.');
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.status, ComplaintStatus.resolved);
      expect(after.timeline.last.note, 'Replaced the fitting.');
      expect(after.timeline.last.actorRole, UserRole.maintenance);
      expect(after.afterPhotos.map((a) => a.id), contains('after-test-1'));
    });

    test('without a photo or a note it is blocked with the P1 / P2 '
        'messages (AC-37 backstop)', () async {
      final ProviderContainer container = await workContainer();
      final Complaint before = await stored(container, inProgressJob);

      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .resolve(
            inProgressJob,
            resolutionNote: '   ',
            afterPhotos: const <Attachment>[],
          );

      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(
        result.messages,
        containsAll(<String>[
          'Add at least one after-repair photo.',
          'Add a resolution note.',
        ]),
      );
      expect(await stored(container, inProgressJob), before);
    });

    test('after a reject only photos taken after it count (AC-38)', () async {
      final ProviderContainer container = await workContainer();
      final Complaint rework = await stored(container, reworkJob);
      final DateTime rejectedAt = rework.timeline.last.at;

      final WorkActionResult? stale = await container
          .read(workActionProvider.notifier)
          .resolve(
            reworkJob,
            resolutionNote: 'Fixed again.',
            afterPhotos: <Attachment>[
              afterPhoto(
                'after-old',
                at: rejectedAt.subtract(const Duration(hours: 1)),
              ),
            ],
          );
      expect(stale!.outcome, WorkActionOutcome.blocked);
      expect(stale.messages, contains('Add at least one after-repair photo.'));

      container.read(workActionProvider.notifier).clearError();
      final WorkActionResult? fresh = await container
          .read(workActionProvider.notifier)
          .resolve(
            reworkJob,
            resolutionNote: 'Fixed again.',
            afterPhotos: <Attachment>[afterPhoto('after-new')],
          );
      expect(fresh!.ok, isTrue);
      expect(
        (await stored(container, reworkJob)).status,
        ComplaintStatus.resolved,
      );
    });

    test('a colleague\'s claim blocks the resolve (P7)', () async {
      final ProviderContainer container = await workContainer();
      final WorkActionResult? result = await container
          .read(workActionProvider.notifier)
          .resolve(
            colleagueInProgress,
            resolutionNote: 'Done.',
            afterPhotos: <Attachment>[afterPhoto('after-x')],
          );
      expect(result!.outcome, WorkActionOutcome.blocked);
      expect(result.messages, contains('Already claimed by a colleague.'));
    });

    test('a failed write keeps everything and can be retried', () async {
      final ProviderContainer container = await workContainer(
        repository: FlakyWriteComplaintRepository(initial: workSeed()),
      );
      final WorkActionNotifier controller = container.read(
        workActionProvider.notifier,
      );
      final List<Attachment> photos = <Attachment>[afterPhoto('after-r')];

      final WorkActionResult? failed = await controller.resolve(
        inProgressJob,
        resolutionNote: 'Done.',
        afterPhotos: photos,
      );
      expect(failed!.outcome, WorkActionOutcome.failed);
      expect(failed.messages.single, contains('photos and note were kept'));
      expect(
        (await stored(container, inProgressJob)).status,
        ComplaintStatus.inProgress,
      );

      expect(
        (await controller.resolve(
          inProgressJob,
          resolutionNote: 'Done.',
          afterPhotos: photos,
        ))!.ok,
        isTrue,
      );
    });
  });

  group('AfterRepairDraft', () {
    ProviderContainer draftContainer() {
      final ProviderContainer container = testContainer();
      container.listen<AfterRepairDraft>(
        afterRepairDraftProvider('CF-2026-00020'),
        (_, _) {},
      );
      return container;
    }

    AfterRepairDraftNotifier notifier(ProviderContainer c) =>
        c.read(afterRepairDraftProvider('CF-2026-00020').notifier);
    AfterRepairDraft draft(ProviderContainer c) =>
        c.read(afterRepairDraftProvider('CF-2026-00020'));

    test('Mark resolved needs a photo AND a non-empty note (AC-37)', () {
      final ProviderContainer c = draftContainer();
      expect(draft(c).canSubmit, isFalse);
      expect(draft(c).hasInput, isFalse);

      notifier(c).setNote('Replaced the fitting');
      expect(draft(c).noteValid, isTrue);
      expect(draft(c).canSubmit, isFalse, reason: 'no photo yet');

      notifier(c).addPhoto();
      expect(draft(c).canSubmit, isTrue);

      notifier(c).setNote('   ');
      expect(draft(c).canSubmit, isFalse, reason: 'a blank note');

      notifier(c).setNote('x' * (ResolveLimits.noteMax + 1));
      expect(draft(c).canSubmit, isFalse, reason: 'over 500 characters');
      notifier(c).setNote('x' * ResolveLimits.noteMax);
      expect(draft(c).canSubmit, isTrue);

      notifier(c).removePhoto(draft(c).photos.single.id);
      expect(draft(c).canSubmit, isFalse);
      expect(draft(c).hasInput, isTrue);
    });

    test('photos are after-photos stamped now, at most five, with unique '
        'ids and clipped captions', () {
      final ProviderContainer c = draftContainer();
      final DateTime start = DateTime.now();
      for (int i = 0; i < ResolveLimits.maxPhotos; i++) {
        expect(notifier(c).addPhoto(), isTrue);
      }
      expect(notifier(c).addPhoto(), isFalse, reason: 'the sixth is ignored');

      final List<Attachment> photos = draft(c).photos;
      expect(photos, hasLength(5));
      expect(photos.map((a) => a.id).toSet(), hasLength(5));
      for (final Attachment a in photos) {
        expect(a.kind, AttachmentKind.afterPhoto);
        expect(a.createdAt.isBefore(start), isFalse);
      }

      notifier(c).setCaption(photos.first.id, 'y' * 120);
      expect(
        draft(c).photos.first.caption,
        hasLength(ResolveLimits.captionMax),
      );
      notifier(c).setCaption(photos.first.id, '   ');
      expect(draft(c).photos.first.caption, isNull);
    });

    test('drafts of different complaints are independent', () {
      final ProviderContainer c = draftContainer();
      c.listen<AfterRepairDraft>(
        afterRepairDraftProvider('CF-2026-00011'),
        (_, _) {},
      );
      notifier(c).setNote('mine');
      expect(c.read(afterRepairDraftProvider('CF-2026-00011')).note, isEmpty);
    });
  });

  group('workJobProvider', () {
    Future<WorkJob?> job(ProviderContainer c, String id) async {
      final Completer<WorkJob?> done = Completer<WorkJob?>();
      final ProviderSubscription<AsyncValue<WorkJob?>> sub = c
          .listen<AsyncValue<WorkJob?>>(workJobProvider(id), (_, next) {
            if (next.hasValue && !done.isCompleted) done.complete(next.value);
          }, fireImmediately: true);
      addTearDown(sub.close);
      return done.future.timeout(const Duration(seconds: 5));
    }

    test('what the worker may do with each job', () async {
      final ProviderContainer c = await workContainer();

      final WorkJob start = (await job(c, toStartA))!;
      expect(start.mine, isTrue);
      expect(start.canStart, isTrue);
      expect(start.canResolve, isFalse);

      final WorkJob progress = (await job(c, inProgressJob))!;
      expect(progress.canResolve, isTrue);
      expect(progress.canStart, isFalse);
      expect(progress.rework, isFalse);
      expect(progress.reworkNote, isNull);

      final WorkJob rework = (await job(c, reworkJob))!;
      expect(rework.canResolve, isTrue);
      expect(rework.rework, isTrue);
      expect(rework.reworkNote, isNotEmpty);

      final WorkJob theirs = (await job(c, colleagueInProgress))!;
      expect(theirs.claimedByColleague, isTrue);
      expect(theirs.canResolve, isFalse);
      expect(theirs.canStart, isFalse);

      // Claimed by a colleague but still `assigned`: Start is offered and the
      // P7 message answers it (AC-36).
      final WorkJob held = (await job(c, assignedToColleague))!;
      expect(held.mine, isFalse);
      expect(held.canStart, isTrue);
    });

    test('another department\'s job and unknown ids are not found '
        '(E-404)', () async {
      final ProviderContainer c = await workContainer();
      expect(await job(c, plumberJob), isNull);
      expect(await job(c, 'CF-2026-99999'), isNull);
    });
  });
}
