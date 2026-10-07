import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';
import 'support/verify_fixtures.dart';

void main() {
  group('Verify (T5)', () {
    test('verifies the repair: `verified`, one verifier event, never '
        '`closed` (the verifier does not close)', () async {
      final ProviderContainer container = await verifyContainer();
      final Complaint before = await stored(container, criticalElectrical);

      final VerifyActionResult? result = await container
          .read(verifyActionProvider.notifier)
          .verify(criticalElectrical, note: '  Checked on site.  ');

      expect(result!.ok, isTrue);
      expect(result.messages, isEmpty);
      expect(
        container.read(verifyActionProvider).status,
        VerifyActionStatus.idle,
      );
      final Complaint after = await stored(container, criticalElectrical);
      expect(after.status, ComplaintStatus.verified);
      expect(after.status, isNot(ComplaintStatus.closed));
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.status, ComplaintStatus.verified);
      expect(after.timeline.last.actorRole, UserRole.verifier);
      expect(after.timeline.last.note, 'Checked on site.');
    });

    test('the note is optional: blank means no note', () async {
      final ProviderContainer container = await verifyContainer();
      final VerifyActionNotifier controller = container.read(
        verifyActionProvider.notifier,
      );

      expect((await controller.verify(highIt))!.ok, isTrue);
      expect((await controller.verify(highPlumbing, note: '   '))!.ok, isTrue);

      expect((await stored(container, highIt)).timeline.last.note, isNull);
      expect(
        (await stored(container, highPlumbing)).timeline.last.note,
        isNull,
      );
    });

    test(
      'a complaint that is not `resolved` is blocked, nothing changes',
      () async {
        final ProviderContainer container = await verifyContainer();
        for (final String id in <String>[
          verifiedJob,
          closedJob,
          inProgressJob,
          reportedJob,
        ]) {
          final Complaint before = await stored(container, id);
          final VerifyActionResult? result = await container
              .read(verifyActionProvider.notifier)
              .verify(id);

          expect(result!.outcome, VerifyActionOutcome.blocked, reason: id);
          expect(result.messages, isNotEmpty, reason: id);
          expect(await stored(container, id), before, reason: id);
          container.read(verifyActionProvider.notifier).clearError();
        }
      },
    );

    test('an unknown id is a friendly block, not a crash', () async {
      final ProviderContainer container = await verifyContainer();
      final VerifyActionResult? result = await container
          .read(verifyActionProvider.notifier)
          .verify('CF-2026-99999');
      expect(result!.outcome, VerifyActionOutcome.blocked);
      expect(result.messages, <String>["We couldn't find that complaint."]);
    });

    test('only verifiers can act', () async {
      for (final UserRole role in <UserRole>[
        UserRole.reporter,
        UserRole.maintenance,
        UserRole.admin,
      ]) {
        final ProviderContainer container = await verifyContainer(role: role);
        final Complaint before = await stored(container, criticalElectrical);

        final VerifyActionResult? result = await container
            .read(verifyActionProvider.notifier)
            .verify(criticalElectrical);

        expect(result!.outcome, VerifyActionOutcome.blocked, reason: '$role');
        expect(result.messages, <String>['Only verifiers can do this.']);
        expect(await stored(container, criticalElectrical), before);
      }
    });

    test('a failed write is reported generically and can be dismissed '
        '(G-4)', () async {
      final ProviderContainer container = await verifyContainer(
        repository: FlakyWriteComplaintRepository(initial: testSeed.complaints),
      );
      final VerifyActionNotifier controller = container.read(
        verifyActionProvider.notifier,
      );

      final VerifyActionResult? failed = await controller.verify(highIt);
      expect(failed!.outcome, VerifyActionOutcome.failed);
      expect(failed.messages.single, contains("couldn't verify the repair"));
      expect(failed.messages.single, isNot(contains('StateError')));
      final VerifyActionState state = container.read(verifyActionProvider);
      expect(state.failedFor(highIt, VerifyActionKind.verify), isTrue);
      expect(state.failedFor(highIt, VerifyActionKind.reject), isFalse);
      expect(state.anyFailedFor(highIt), isTrue);
      expect(state.blocked, isFalse);
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.resolved,
      );

      controller.clearError();
      expect(
        container.read(verifyActionProvider).status,
        VerifyActionStatus.idle,
      );

      // The retry goes through (the outage was one write).
      expect((await controller.verify(highIt))!.ok, isTrue);
    });

    test('a second tap while one is in flight is ignored (G-3)', () async {
      final SlowWriteComplaintRepository slow = SlowWriteComplaintRepository(
        initial: testSeed.complaints,
      );
      final ProviderContainer container = await verifyContainer(
        repository: slow,
      );
      final VerifyActionNotifier controller = container.read(
        verifyActionProvider.notifier,
      );

      final Future<VerifyActionResult?> first = controller.verify(highIt);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(verifyActionProvider)
            .runningFor(highIt, VerifyActionKind.verify),
        isTrue,
      );
      expect(container.read(verifyActionProvider).busy, isTrue);
      expect(await controller.verify(highIt), isNull);
      expect(
        await controller.reject(highPlumbing, note: 'Still leaking'),
        isNull,
      );

      slow.release();
      expect((await first)!.ok, isTrue);
      expect(slow.writes, 1);
    });
  });

  group('Reject (T7)', () {
    test('sends the job back: `inProgress`, one verifier event carrying the '
        'reason (AC-44)', () async {
      final ProviderContainer container = await verifyContainer();
      final Complaint before = await stored(container, criticalElectrical);

      final VerifyActionResult? result = await container
          .read(verifyActionProvider.notifier)
          .reject(criticalElectrical, note: '  Still sparking.  ');

      expect(result!.ok, isTrue);
      final Complaint after = await stored(container, criticalElectrical);
      expect(after.status, ComplaintStatus.inProgress);
      expect(after.timeline, hasLength(before.timeline.length + 1));
      expect(after.timeline.last.status, ComplaintStatus.inProgress);
      expect(after.timeline.last.actorRole, UserRole.verifier);
      expect(after.timeline.last.note, 'Still sparking.');
      // The earlier repair evidence stays as history.
      expect(after.afterPhotos, before.afterPhotos);
    });

    test('a rejected job reappears in the maintenance worker\'s Rework tab '
        'and leaves the verification queue (AC-44)', () async {
      final MockComplaintRepository repository =
          verifyRepositoryWithDemoWorkerJob();
      final ProviderContainer verifier = await verifyContainer(
        repository: repository,
      );
      expect(
        (await settled(verifier, verificationQueueProvider)).map((v) => v.id),
        contains(criticalElectrical),
      );

      final VerifyActionResult? result = await verifier
          .read(verifyActionProvider.notifier)
          .reject(criticalElectrical, note: 'Still sparking.');
      expect(result!.ok, isTrue);

      // The maintenance worker holding the job (the demo worker, see
      // verifyRepositoryWithDemoWorkerJob) sees it under Rework, with the
      // verifier's reason as the latest public timeline note.
      final ProviderContainer maintenance = await verifyContainer(
        repository: repository,
        role: UserRole.maintenance,
      );
      final WorkQueue queue = await settled(maintenance, workQueueProvider);
      expect(
        queue.rework.map((PublicComplaintView v) => v.id),
        contains(criticalElectrical),
      );
      final PublicComplaintView sentBack = queue.rework.firstWhere(
        (PublicComplaintView v) => v.id == criticalElectrical,
      );
      expect(sentBack.timeline.last.note, 'Still sparking.');
      expect(sentBack.timeline.last.actorRole, UserRole.verifier);

      // And it has left the verifier's queue.
      expect(
        (await settled(verifier, verificationQueueProvider)).map((v) => v.id),
        isNot(contains(criticalElectrical)),
      );
    });

    test('a blank reason is blocked with "Add a reason." and changes '
        'nothing (AC-43)', () async {
      final ProviderContainer container = await verifyContainer();
      final Complaint before = await stored(container, criticalElectrical);
      final VerifyActionNotifier controller = container.read(
        verifyActionProvider.notifier,
      );

      for (final String blank in <String>['', '   ', '\n\t']) {
        final VerifyActionResult? result = await controller.reject(
          criticalElectrical,
          note: blank,
        );
        expect(
          result!.outcome,
          VerifyActionOutcome.blocked,
          reason: 'a blank reason',
        );
        expect(result.messages, contains('Add a reason.'));
        expect(await stored(container, criticalElectrical), before);
        final VerifyActionState state = container.read(verifyActionProvider);
        expect(
          state.failedFor(criticalElectrical, VerifyActionKind.reject),
          isTrue,
        );
        expect(state.blocked, isTrue);
        controller.clearError();
      }
    });

    test('a reason over 500 characters is blocked', () async {
      final ProviderContainer container = await verifyContainer();
      final VerifyActionResult? result = await container
          .read(verifyActionProvider.notifier)
          .reject(highIt, note: 'x' * (VerifyLimits.noteMax + 1));
      expect(result!.outcome, VerifyActionOutcome.blocked);
      expect(result.messages, contains('Note too long (500 max).'));
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.resolved,
      );

      // Exactly 500 is fine.
      final VerifyActionResult? ok = await container
          .read(verifyActionProvider.notifier)
          .reject(highIt, note: 'x' * VerifyLimits.noteMax);
      expect(ok!.ok, isTrue);
    });

    test('only verifiers can act', () async {
      final ProviderContainer container = await verifyContainer(
        role: UserRole.maintenance,
      );
      final Complaint before = await stored(container, highIt);
      final VerifyActionResult? result = await container
          .read(verifyActionProvider.notifier)
          .reject(highIt, note: 'Not good');
      expect(result!.outcome, VerifyActionOutcome.blocked);
      expect(result.messages, <String>['Only verifiers can do this.']);
      expect(await stored(container, highIt), before);
    });

    test('a failed write keeps the reason retryable (G-4)', () async {
      final ProviderContainer container = await verifyContainer(
        repository: FlakyWriteComplaintRepository(initial: testSeed.complaints),
      );
      final VerifyActionNotifier controller = container.read(
        verifyActionProvider.notifier,
      );

      final VerifyActionResult? failed = await controller.reject(
        highIt,
        note: 'Paint is peeling already',
      );
      expect(failed!.outcome, VerifyActionOutcome.failed);
      expect(failed.messages.single, contains("couldn't send the job back"));
      expect(
        container
            .read(verifyActionProvider)
            .failedFor(highIt, VerifyActionKind.reject),
        isTrue,
      );
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.resolved,
      );

      final VerifyActionResult? retry = await controller.reject(
        highIt,
        note: 'Paint is peeling already',
      );
      expect(retry!.ok, isTrue);
      expect(
        (await stored(container, highIt)).status,
        ComplaintStatus.inProgress,
      );
    });
  });

  group('verifyJobProvider', () {
    Future<VerifyJob?> job(ProviderContainer c, String id) =>
        settled(c, verifyJobProvider(id));

    test(
      'a resolved complaint offers Verify and Reject, and no close',
      () async {
        final ProviderContainer c = await verifyContainer();
        final VerifyJob j = (await job(c, criticalElectrical))!;
        expect(j.status, ComplaintStatus.resolved);
        expect(j.canVerify, isTrue);
        expect(j.canReject, isTrue);
        expect(j.evidenceProblems, isEmpty);
        // The verifier's L1 moves from `resolved` are exactly these two.
        expect(
          StatusMachine.nextStatuses(
            ComplaintStatus.resolved,
            UserRole.verifier,
          ),
          <ComplaintStatus>[
            ComplaintStatus.inProgress,
            ComplaintStatus.verified,
          ],
        );
      },
    );

    test('a complaint that is not `resolved`, and unknown ids, are not found '
        '(E-404)', () async {
      final ProviderContainer c = await verifyContainer();
      for (final String id in <String>[
        verifiedJob,
        closedJob,
        inProgressJob,
        sentBackJob,
        reportedJob,
        'CF-2026-99999',
      ]) {
        expect(await job(c, id), isNull, reason: id);
      }
    });

    test('other roles are not found either', () async {
      for (final UserRole role in <UserRole>[
        UserRole.reporter,
        UserRole.maintenance,
        UserRole.admin,
      ]) {
        final ProviderContainer c = await verifyContainer(role: role);
        expect(await job(c, criticalElectrical), isNull, reason: '$role');
      }
    });

    test('missing repair evidence disables Verify, not Reject', () async {
      final ProviderContainer c = await verifyContainer(
        repository: MockComplaintRepository(initial: noEvidenceSeed()),
      );
      final VerifyJob j = (await job(c, lowFurniture))!;
      expect(j.canVerify, isFalse);
      expect(j.canReject, isTrue);
      expect(j.evidenceProblems, <String>[
        'Add at least one after-repair photo.',
        'Add a resolution note.',
      ]);
    });
  });
}
