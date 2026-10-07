import 'package:campusfix_admin/app.dart' show noAutoRetry;
import 'package:campusfix_admin/providers/providers.dart';
// The barrel deliberately hides the raw complaint repository; tests reach it
// (to mutate data and to simulate failures) through its own library.
import 'package:campusfix_admin/providers/repositories.dart'
    show complaintRepositoryProvider;
import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/settled.dart';

Future<AppUser> signIn(
  ProviderContainer container,
  UserRole role, {
  SignInOutcome expected = SignInOutcome.success,
}) async {
  final MockAccount account = demoAccount(role);
  final SignInOutcome outcome = await container
      .read(sessionProvider.notifier)
      .signIn(account.user.idNumber, account.password);
  expect(outcome, expected);
  return account.user;
}

/// Shows the state of `allComplaintsProvider` and a Retry that calls the
/// public `refreshComplaints`, like a screen's error state will.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(allComplaintsProvider);
    return Column(
      children: <Widget>[
        Text(
          state.when(
            data: (all) => 'count ${all.length}',
            error: (e, _) => 'error',
            loading: () => 'loading',
          ),
        ),
        TextButton(
          onPressed: () => refreshComplaints(ref),
          child: const Text('retry'),
        ),
      ],
    );
  }
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

    test('an admin and a verifier get a console session', () async {
      for (final role in <UserRole>[UserRole.admin, UserRole.verifier]) {
        final container = testContainer();
        final user = await signIn(container, role);
        expect(container.read(sessionProvider), user);
        expect(mayUseConsole(role), isTrue);
      }
    });

    test(
      'reporter and maintenance are authenticated but not authorized',
      () async {
        for (final role in <UserRole>[
          UserRole.reporter,
          UserRole.maintenance,
        ]) {
          final container = testContainer();
          final user = await signIn(
            container,
            role,
            expected: SignInOutcome.notAuthorized,
          );
          // The session is kept so E-403 can offer Sign out (AC-45).
          expect(container.read(sessionProvider), user);
          expect(mayUseConsole(role), isFalse);
        }
        expect(kConsoleRoles, {UserRole.admin, UserRole.verifier});
      },
    );

    test('sign out ends the session', () async {
      final container = testContainer();
      await signIn(container, UserRole.admin);
      expect(container.read(sessionProvider), isNotNull);
      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(sessionProvider), isNull);
      expect(container.read(authRepositoryProvider).currentUser, isNull);
    });
  });

  group('allComplaintsProvider (public views only)', () {
    test('admin and verifier get every complaint as a public view', () async {
      for (final role in <UserRole>[UserRole.admin, UserRole.verifier]) {
        final container = testContainer();
        await signIn(container, role);

        final List<PublicComplaintView> all = await settled(
          container,
          allComplaintsProvider,
        );
        expect(all, hasLength(testSeed.complaints.length));
        expect(
          {for (final c in all) c.id},
          {for (final c in testSeed.complaints) c.id},
        );
        // The projection is the core's, and carries no identity.
        expect(all, toPublicViews(testSeed.complaints));
      }
    });

    test('other roles and signed-out sessions see no complaints', () async {
      final signedOut = testContainer();
      expect(await settled(signedOut, allComplaintsProvider), isEmpty);

      for (final role in <UserRole>[UserRole.reporter, UserRole.maintenance]) {
        final container = testContainer();
        await signIn(container, role, expected: SignInOutcome.notAuthorized);
        expect(await settled(container, allComplaintsProvider), isEmpty);
      }
    });

    test('the feed follows the session', () async {
      final container = testContainer();
      await signIn(container, UserRole.admin);
      expect(
        await settled(container, allComplaintsProvider),
        hasLength(testSeed.complaints.length),
      );
      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(allComplaintsProvider).requireValue, isEmpty);
    });

    test('is live: a repository change reaches the public views', () async {
      final container = testContainer();
      await signIn(container, UserRole.admin);
      final all = await settled(container, allComplaintsProvider);

      final Complaint raw = testSeed.complaints.firstWhere(
        (c) => c.effectivePriority != Priority.critical,
      );
      expect(
        all.firstWhere((c) => c.id == raw.id).effectivePriority,
        raw.effectivePriority,
      );

      await container
          .read(complaintRepositoryProvider)
          .update(raw.copyWith(priorityOverride: Priority.critical));
      await Future<void>.delayed(Duration.zero);

      final updated = container.read(allComplaintsProvider).requireValue;
      expect(
        updated.firstWhere((c) => c.id == raw.id).effectivePriority,
        Priority.critical,
      );
    });
  });

  group('complaintViewProvider', () {
    test('resolves a known ID to its public view', () async {
      final container = testContainer();
      await signIn(container, UserRole.verifier);
      final Complaint raw = testSeed.complaints.first;

      final view = await settled(container, complaintViewProvider(raw.id));
      expect(view, toPublicView(raw));
    });

    test('an unknown ID loads as null (E-404)', () async {
      final container = testContainer();
      await signIn(container, UserRole.admin);

      expect(
        await settled(container, complaintViewProvider('CF-2026-99999')),
        isNull,
      );
    });

    test(
      'a non-console session resolves nothing, not even a real ID',
      () async {
        final container = testContainer();
        await signIn(
          container,
          UserRole.reporter,
          expected: SignInOutcome.notAuthorized,
        );

        expect(
          await settled(
            container,
            complaintViewProvider(testSeed.complaints.first.id),
          ),
          isNull,
        );
      },
    );
  });

  group('load states', () {
    Future<ProviderContainer> adminContainer(
      ComplaintRepository repository,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          complaintRepositoryProvider.overrideWithValue(repository),
        ],
        retry: noAutoRetry,
      );
      addTearDown(container.dispose);
      await signIn(container, UserRole.admin);
      return container;
    }

    testWidgets('error surfaces as AsyncError and Retry recovers', (
      tester,
    ) async {
      final container = await tester.runAsync(
        () => adminContainer(
          FlakyComplaintRepository(initial: testSeed.complaints),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container!,
          child: const MaterialApp(home: Scaffold(body: _Probe())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('error'), findsOneWidget);

      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();
      expect(find.text('count ${testSeed.complaints.length}'), findsOneWidget);
    });

    testWidgets('a read that never completes stays loading', (tester) async {
      final container = await tester.runAsync(
        () => adminContainer(StalledComplaintRepository()),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container!,
          child: const MaterialApp(home: Scaffold(body: _Probe())),
        ),
      );
      await tester.pump();
      expect(find.text('loading'), findsOneWidget);
    });
  });

  group('services', () {
    test('the transition executor and notification service are wired', () {
      final container = testContainer();
      expect(container.read(complaintServiceProvider), isA<ComplaintService>());
      expect(
        container.read(notificationServiceProvider),
        isA<NotificationService>(),
      );
    });
  });
}
