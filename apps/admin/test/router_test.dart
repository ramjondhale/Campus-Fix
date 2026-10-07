import 'package:campusfix_admin/features/complaint_detail/complaint_detail_screen.dart';
import 'package:campusfix_admin/features/complaints/complaint_list_screen.dart';
import 'package:campusfix_admin/features/errors/error_screens.dart';
import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_admin/router/app_router.dart';
import 'package:campusfix_admin/router/role_guard.dart';
import 'package:campusfix_admin/router/routes.dart';
import 'package:campusfix_admin/shell/admin_nav.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const String _forbiddenTitle = "You don't have access to this page";
const String _loginSubtitle = 'Sign in to the admin console';

/// A session notifier that starts signed in as [user].
class _FixedSession extends SessionNotifier {
  _FixedSession(this.user);

  final AppUser? user;

  @override
  AppUser? build() => user;
}

void main() {
  group('route policy (screens-spec section 5)', () {
    test('admin and verifier open the dashboard, the list and the detail', () {
      for (final role in <UserRole>[UserRole.admin, UserRole.verifier]) {
        expect(roleMayOpen(role, AppRoutes.dashboard), isTrue, reason: '$role');
        expect(
          roleMayOpen(role, AppRoutes.complaints),
          isTrue,
          reason: '$role',
        );
        expect(
          roleMayOpen(role, AppRoutes.complaint('CF-2026-00001')),
          isTrue,
          reason: '$role',
        );
        // Filter state travels as a query on the list.
        expect(roleMayOpen(role, '/complaints?status=resolved'), isTrue);
      }
    });

    test('reporter and maintenance open nothing in the console', () {
      for (final role in <UserRole>[UserRole.reporter, UserRole.maintenance]) {
        expect(
          roleMayOpen(role, AppRoutes.dashboard),
          isFalse,
          reason: '$role',
        );
        expect(
          roleMayOpen(role, AppRoutes.complaints),
          isFalse,
          reason: '$role',
        );
        expect(
          roleMayOpen(role, AppRoutes.complaint('CF-2026-00001')),
          isFalse,
          reason: '$role',
        );
      }
    });

    test('unknown paths and other origins are never open', () {
      expect(roleMayOpen(UserRole.admin, '/nope'), isFalse);
      expect(roleMayOpen(UserRole.admin, '/'), isFalse);
      expect(roleMayOpen(UserRole.admin, AppRoutes.forbidden), isFalse);
      expect(roleMayOpen(UserRole.admin, AppRoutes.login), isFalse);
      // A return-to target is an in-app path, never another origin.
      expect(roleMayOpen(UserRole.admin, '//evil.example/dashboard'), isFalse);
      expect(
        roleMayOpen(UserRole.admin, 'https://evil.example/dashboard'),
        isFalse,
      );
    });

    test('every console role lands on the dashboard', () {
      expect(homeFor(UserRole.admin), AppRoutes.dashboard);
      expect(homeFor(UserRole.verifier), AppRoutes.dashboard);
    });
  });

  group('nav selection', () {
    test('the list and the detail belong to Complaints', () {
      expect(navIndexFor(AppRoutes.dashboard), 0);
      expect(navIndexFor(AppRoutes.complaints), 1);
      expect(navIndexFor('/complaints?status=resolved'), 1);
      expect(navIndexFor(AppRoutes.complaint('CF-2026-00001')), 1);
      expect(navIndexFor('/'), 0);
      expect(navIndexFor('/nope'), 0);
    });

    test('the destinations match the nav paths', () {
      expect(kAdminNavPaths.length, AdminSideNav.defaultDestinations.length);
    });

    test('page titles', () {
      expect(pageTitleFor(AppRoutes.dashboard), 'Dashboard');
      expect(pageTitleFor(AppRoutes.complaints), 'Complaints');
      expect(
        pageTitleFor(AppRoutes.complaint('CF-2026-00001')),
        'Complaint details',
      );
    });
  });

  testWidgets('boots to Login; the landing route does not carry a return-to', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);

    expect(find.text(_loginSubtitle), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.login);
    expect(router.state.uri.queryParameters, isEmpty);
  });

  testWidgets('G-1 signed-out deep link goes to Login, then returns to it', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);
    final String id = testSeed.complaints.first.id;

    router.go(AppRoutes.complaint(id));
    await tester.pumpAndSettle();
    expect(find.text(_loginSubtitle), findsOneWidget);
    expect(
      router.state.uri.queryParameters[kReturnToParam],
      AppRoutes.complaint(id),
    );

    await signInAs(tester, UserRole.admin);
    expect(router.state.uri.path, AppRoutes.complaint(id));
    expect(
      find.byType(ComplaintDetailScreen),
      findsOneWidget,
    );
    expect(find.text(_loginSubtitle), findsNothing);
  });

  testWidgets('G-1 the deep link keeps its filter query through login', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);

    router.go('/complaints?status=resolved');
    await tester.pumpAndSettle();
    expect(find.text(_loginSubtitle), findsOneWidget);

    await signInAs(tester, UserRole.verifier);
    expect(router.state.uri.path, AppRoutes.complaints);
    expect(router.state.uri.queryParameters['status'], 'resolved');
  });

  testWidgets('G-1 a return-to the role may not open lands on the dashboard', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);

    for (final String from in <String>['/nope', '//evil.example/dashboard']) {
      router.go(
        Uri(
          path: AppRoutes.login,
          queryParameters: <String, String>{kReturnToParam: from},
        ).toString(),
      );
      await tester.pumpAndSettle();
      await signInAs(tester, UserRole.admin);
      expect(router.state.uri.path, AppRoutes.dashboard, reason: from);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text(_loginSubtitle), findsOneWidget);
    }
  });

  testWidgets('signed out, every console route redirects to Login', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);

    for (final String path in <String>[
      AppRoutes.dashboard,
      AppRoutes.complaints,
      AppRoutes.complaint('CF-2026-00001'),
      AppRoutes.forbidden,
      '/',
      '/definitely/not/a/route',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text(_loginSubtitle), findsOneWidget, reason: path);
      expect(router.state.uri.path, AppRoutes.login, reason: path);
    }
  });

  testWidgets('G-2 admin and verifier are admitted to all three screens', (
    tester,
  ) async {
    for (final UserRole role in <UserRole>[UserRole.admin, UserRole.verifier]) {
      final container = await pumpAdmin(tester);
      final router = container.read(appRouterProvider);
      await signInAs(tester, role);

      final String id = testSeed.complaints.first.id;
      for (final (String path, Finder body) in <(String, Finder)>[
        (AppRoutes.dashboard, find.text('Status breakdown')),
        (AppRoutes.complaints, find.byType(ComplaintListScreen)),
        (
          AppRoutes.complaint(id),
          find.byType(ComplaintDetailScreen),
        ),
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, path, reason: '$role $path');
        expect(body, findsOneWidget, reason: '$role $path');
        expect(find.byType(AdminSideNav), findsOneWidget);
        expect(find.text(_forbiddenTitle), findsNothing);
      }
      // Tear the app down so the next role boots from a clean session.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'G-2 / AC-45 reporter and maintenance never reach a console route',
    (tester) async {
      for (final UserRole role in <UserRole>[
        UserRole.reporter,
        UserRole.maintenance,
      ]) {
        final container = await pumpAdmin(tester);
        final router = container.read(appRouterProvider);
        await signInAs(tester, role);
        expect(router.state.uri.path, AppRoutes.forbidden, reason: '$role');

        for (final String path in <String>[
          AppRoutes.dashboard,
          AppRoutes.complaints,
          AppRoutes.complaint('CF-2026-00001'),
          AppRoutes.login,
          '/',
          '/definitely/not/a/route',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            router.state.uri.path,
            AppRoutes.forbidden,
            reason: '$role $path',
          );
          expect(
            find.text(_forbiddenTitle),
            findsOneWidget,
            reason: '$role $path',
          );
          expect(
            find.byType(AdminSideNav),
            findsNothing,
            reason: '$role $path',
          );
          // The unknown path is not reported as "not found": nothing is revealed.
          expect(find.text('Page not found'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('a signed-in admin on / or Login lands on the dashboard', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    final router = container.read(appRouterProvider);
    await signInAs(tester, UserRole.admin);

    router.go('/');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.dashboard);

    router.go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.dashboard);

    router.go(AppRoutes.forbidden);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.dashboard);
  });

  testWidgets('an unknown route shows E-404 for a console role', (
    tester,
  ) async {
    final container = await pumpAdmin(tester);
    await signInAs(tester, UserRole.admin);

    container.read(appRouterProvider).go('/definitely/not/a/route');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Status breakdown'), findsOneWidget);
  });

  testWidgets(
    'the detail route resolves inside the shell for any complaint ID',
    (tester) async {
      final container = await pumpAdmin(tester);
      final router = container.read(appRouterProvider);
      await signInAs(tester, UserRole.admin);

      router.go(AppRoutes.complaint('CF-2026-99999'));
      await tester.pumpAndSettle();

      // The detail screen owns the unknown-ID E-404 (S5.4); here the route
      // itself resolves, with the shell around it.
      expect(router.state.uri.path, AppRoutes.complaint('CF-2026-99999'));
      expect(find.byType(AdminSideNav), findsOneWidget);
    },
  );

  testWidgets('RoleGuard shows E-403 to a role that is not listed', (
    tester,
  ) async {
    final AppUser reporter = demoAccount(UserRole.reporter).user;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...testOverrides(),
          sessionProvider.overrideWith(() => _FixedSession(reporter)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RoleGuard(
            roles: kConsoleRoles,
            child: Text('console content'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotAuthorizedScreen), findsOneWidget);
    expect(find.text('console content'), findsNothing);
  });

  testWidgets('RoleGuard admits a console role', (tester) async {
    final AppUser verifier = demoAccount(UserRole.verifier).user;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...testOverrides(),
          sessionProvider.overrideWith(() => _FixedSession(verifier)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RoleGuard(
            roles: kConsoleRoles,
            child: Text('console content'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('console content'), findsOneWidget);
    expect(find.byType(NotAuthorizedScreen), findsNothing);
  });
}
