import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// Waits for the first data value of an async provider.
Future<T> settled<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  final Completer<T> done = Completer<T>();
  final ProviderSubscription<AsyncValue<T>> sub = container
      .listen<AsyncValue<T>>(provider, (_, next) {
        if (next.hasValue && !done.isCompleted) {
          done.complete(next.requireValue);
        }
      }, fireImmediately: true);
  addTearDown(sub.close);
  return done.future.timeout(const Duration(seconds: 5));
}

Future<AppUser> signIn(ProviderContainer container, UserRole role) async {
  final MockAccount account = demoAccount(role);
  final SignInOutcome outcome = await container
      .read(sessionProvider.notifier)
      .signIn(account.user.idNumber, account.password);
  expect(outcome, SignInOutcome.success);
  return account.user;
}

void main() {
  group('session', () {
    test('starts signed out; wrong credentials start no session', () async {
      final container = testContainer();
      expect(container.read(sessionProvider), isNull);

      final outcome = await container
          .read(sessionProvider.notifier)
          .signIn('nobody', 'wrong');
      expect(outcome, SignInOutcome.invalidCredentials);
      expect(container.read(sessionProvider), isNull);
    });

    test('an admin sign-in starts no session on mobile', () async {
      final container = testContainer();
      final admin = testSeed.demoAccounts.firstWhere(
        (a) => a.user.role == UserRole.admin,
      );
      final outcome = await container
          .read(sessionProvider.notifier)
          .signIn(admin.user.idNumber, admin.password);

      expect(outcome, SignInOutcome.adminUsesWeb);
      expect(container.read(sessionProvider), isNull);
      expect(container.read(authRepositoryProvider).currentUser, isNull);
    });

    test('sign out ends the session', () async {
      final container = testContainer();
      await signIn(container, UserRole.reporter);
      expect(container.read(sessionProvider), isNotNull);
      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(sessionProvider), isNull);
    });
  });

  group('public-view providers (privacy boundary)', () {
    test(
      'AC-23 My Complaints holds only the session reporter\'s own',
      () async {
        final container = testContainer();
        final user = await signIn(container, UserRole.reporter);

        final List<PublicComplaintView> mine = await settled(
          container,
          myComplaintsProvider,
        );
        final Set<String> expectedIds = {
          for (final c in testSeed.complaints)
            if (c.reporter.userId == user.id) c.id,
        };
        expect(expectedIds, isNotEmpty);
        expect({for (final c in mine) c.id}, expectedIds);
        for (int i = 1; i < mine.length; i++) {
          expect(
            mine[i - 1].updatedAt.isBefore(mine[i].updatedAt),
            isFalse,
            reason: 'updatedAt descending',
          );
        }
      },
    );

    test('My Complaints is empty for a non-reporter', () async {
      final container = testContainer();
      await signIn(container, UserRole.verifier);
      expect(await settled(container, myComplaintsProvider), isEmpty);
    });

    test('Home: at most 3 active complaints, none closed', () async {
      final container = testContainer();
      await signIn(container, UserRole.reporter);
      final active = await settled(container, myActiveComplaintsProvider);
      expect(active.length, lessThanOrEqualTo(3));
      expect(active.any((c) => c.status == ComplaintStatus.closed), isFalse);
    });

    test('Home: board highlights are open critical/high, at most 3', () async {
      final container = testContainer();
      await signIn(container, UserRole.reporter);
      final highlights = await settled(container, boardHighlightsProvider);
      expect(highlights.length, lessThanOrEqualTo(3));
      for (final c in highlights) {
        expect(c.status, isNot(ComplaintStatus.closed));
        expect(c.effectivePriority.weight, greaterThanOrEqualTo(3));
      }
    });

    test(
      'AC-33 the work queue is the worker\'s department, claim-aware',
      () async {
        final container = testContainer();
        final user = await signIn(container, UserRole.maintenance);
        final WorkQueue queue = await settled(container, workQueueProvider);

        final byId = {for (final c in testSeed.complaints) c.id: c};
        for (final v in [
          ...queue.toStart,
          ...queue.inProgress,
          ...queue.rework,
        ]) {
          expect(byId[v.id]!.assignment!.department, user.department);
        }
        for (final v in queue.toStart) {
          expect(v.status, ComplaintStatus.assigned);
          final claimedBy = byId[v.id]!.assignment!.assigneeId;
          expect(claimedBy == null || claimedBy == user.id, isTrue);
        }
        for (final v in [...queue.inProgress, ...queue.rework]) {
          expect(v.status, ComplaintStatus.inProgress);
          expect(byId[v.id]!.assignment!.assigneeId, user.id);
        }
        final ids = [
          for (final v in [
            ...queue.toStart,
            ...queue.inProgress,
            ...queue.rework,
          ])
            v.id,
        ];
        expect(ids.toSet().length, ids.length, reason: 'lists are disjoint');
      },
    );

    test(
      'AC-40 the verification queue holds only resolved complaints',
      () async {
        final container = testContainer();
        await signIn(container, UserRole.verifier);
        final queue = await settled(container, verificationQueueProvider);

        final resolved = {
          for (final c in testSeed.complaints)
            if (c.status == ComplaintStatus.resolved) c.id,
        };
        expect({for (final c in queue) c.id}, resolved);
      },
    );

    test('the board source is every complaint as a public view', () async {
      final container = testContainer();
      final board = await settled(container, boardComplaintsProvider);
      expect(board.length, testSeed.complaints.length);
    });
  });
}
