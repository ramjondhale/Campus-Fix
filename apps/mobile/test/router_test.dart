import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:campusfix_mobile/router/routes.dart';
import 'package:campusfix_mobile/shell/role_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  group('route policy (screens-spec section 5)', () {
    test('reporter opens the report flow and own complaints, not work/verify',
        () {
      const r = UserRole.reporter;
      expect(roleMayOpen(r, AppRoutes.home), isTrue);
      expect(roleMayOpen(r, AppRoutes.reportCategory), isTrue);
      expect(roleMayOpen(r, AppRoutes.reportDone('CF-2026-00001')), isTrue);
      expect(roleMayOpen(r, AppRoutes.complaint('CF-2026-00001')), isTrue);
      expect(roleMayOpen(r, AppRoutes.boardItem('CF-2026-00001')), isTrue);
      expect(roleMayOpen(r, AppRoutes.work), isFalse);
      expect(roleMayOpen(r, AppRoutes.verify), isFalse);
    });

    test('maintenance opens work, board, notifications only', () {
      const m = UserRole.maintenance;
      expect(roleMayOpen(m, AppRoutes.work), isTrue);
      expect(roleMayOpen(m, AppRoutes.workResolve('CF-2026-00001')), isTrue);
      expect(roleMayOpen(m, AppRoutes.board), isTrue);
      expect(roleMayOpen(m, AppRoutes.notifications), isTrue);
      expect(roleMayOpen(m, AppRoutes.complaints), isFalse);
      expect(roleMayOpen(m, AppRoutes.reportCategory), isFalse);
      expect(roleMayOpen(m, AppRoutes.verify), isFalse);
    });

    test('verifier opens verify, board, notifications only', () {
      const v = UserRole.verifier;
      expect(roleMayOpen(v, AppRoutes.verifyItem('CF-2026-00001')), isTrue);
      expect(roleMayOpen(v, AppRoutes.work), isFalse);
      expect(roleMayOpen(v, AppRoutes.complaints), isFalse);
    });

    test('admin and unknown paths are never open on mobile', () {
      expect(roleMayOpen(UserRole.admin, AppRoutes.home), isFalse);
      expect(roleMayOpen(UserRole.reporter, '/nope'), isFalse);
      expect(roleMayOpen(UserRole.reporter, '/'), isFalse);
    });
  });

  group('bottom-nav selection (G-9)', () {
    test('reporter tabs', () {
      const r = UserRole.reporter;
      expect(navPathsFor(r), [
        AppRoutes.home,
        AppRoutes.complaints,
        AppRoutes.board,
        AppRoutes.notifications,
      ]);
      expect(navIndexFor(r, AppRoutes.home), 0);
      expect(navIndexFor(r, AppRoutes.complaints), 1);
      expect(navIndexFor(r, AppRoutes.board), 2);
      expect(navIndexFor(r, AppRoutes.notifications), 3);
    });

    test('work and verify queues keep the first tab selected', () {
      expect(navIndexFor(UserRole.maintenance, AppRoutes.work), 0);
      expect(navIndexFor(UserRole.maintenance, AppRoutes.board), 1);
      expect(navIndexFor(UserRole.maintenance, AppRoutes.notifications), 2);
      expect(navIndexFor(UserRole.verifier, AppRoutes.verify), 0);
      expect(navIndexFor(UserRole.verifier, AppRoutes.notifications), 2);
    });
  });

  testWidgets('G-1 signed-out deep link goes to Login, then returns to it', (
    tester,
  ) async {
    final container = await pumpCampusFix(tester);
    final router = container.read(appRouterProvider);

    router.go(AppRoutes.board);
    await tester.pumpAndSettle();
    expect(find.text('Sign in with your ID number'), findsOneWidget);
    expect(router.state.uri.queryParameters[kReturnToParam], AppRoutes.board);

    await signInAs(tester, UserRole.reporter);
    expect(router.state.uri.path, AppRoutes.board);
    expect(find.text('Campus Board'), findsWidgets);
  });

  testWidgets('G-1 a return-to route the role may not open lands on its home', (
    tester,
  ) async {
    final container = await pumpCampusFix(tester);
    final router = container.read(appRouterProvider);

    router.go(AppRoutes.complaints); // reporter-only
    await tester.pumpAndSettle();
    await signInAs(tester, UserRole.maintenance);

    expect(router.state.uri.path, AppRoutes.home);
    expect(find.text('Open my work'), findsOneWidget);
  });

  testWidgets('G-2 a role opening a screen it is not listed for gets E-403', (
    tester,
  ) async {
    final container = await pumpCampusFix(tester);
    await signInAs(tester, UserRole.maintenance);

    container.read(appRouterProvider).go(AppRoutes.complaints);
    await tester.pumpAndSettle();

    expect(find.text("You don't have access to this page"), findsOneWidget);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.text('Open my work'), findsOneWidget);
  });

  testWidgets('an unknown route shows the not-found screen', (tester) async {
    final container = await pumpCampusFix(tester);
    await signInAs(tester, UserRole.reporter);

    container.read(appRouterProvider).go('/definitely/not/a/route');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('every stubbed route renders its Coming soon screen', (
    tester,
  ) async {
    final container = await pumpCampusFix(tester);
    final router = container.read(appRouterProvider);

    await signInAs(tester, UserRole.reporter);
    for (final path in <String>[
      AppRoutes.reportCategory,
      AppRoutes.reportLocation,
      AppRoutes.reportPhotos,
      AppRoutes.reportDetails,
      AppRoutes.reportReview,
      AppRoutes.reportDone('CF-2026-00001'),
      AppRoutes.complaints,
      AppRoutes.complaint('CF-2026-00001'),
      AppRoutes.board,
      AppRoutes.boardItem('CF-2026-00001'),
      AppRoutes.notifications,
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget, reason: path);
    }
  });
}
