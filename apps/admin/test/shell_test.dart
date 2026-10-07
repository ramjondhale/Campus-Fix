import 'package:campusfix_admin/features/complaint_detail/complaint_detail_screen.dart';
import 'package:campusfix_admin/features/complaints/complaint_list_screen.dart';
import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_admin/router/app_router.dart';
import 'package:campusfix_admin/router/routes.dart';
import 'package:campusfix_admin/shell/admin_top_bar.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

const String _loginSubtitle = 'Sign in to the admin console';

Finder inNav(String text) =>
    find.descendant(of: find.byType(AdminSideNav), matching: find.text(text));

Finder inTopBar(String text) => find.descendant(
  of: find.byType(AdminShellTopBar),
  matching: find.text(text),
);

AdminSideNav sideNav(WidgetTester tester) =>
    tester.widget<AdminSideNav>(find.byType(AdminSideNav));

void main() {
  group('desktop shell (1440 px)', () {
    testWidgets(
      'renders the side nav, the top bar and the signed-in identity',
      (tester) async {
        await pumpAdmin(tester);
        await signInAs(tester, UserRole.admin);
        final AppUser user = demoAccount(UserRole.admin).user;

        // Persistent, expanded side nav with both destinations and the brand.
        expect(sideNav(tester).rail, isFalse);
        expect(inNav('Dashboard'), findsOneWidget);
        expect(inNav('Complaints'), findsOneWidget);
        expect(inNav('CampusFix'), findsOneWidget);
        expect(sideNav(tester).selectedIndex, 0);

        // Top bar: page title, the signed-in user's name, role and Sign out.
        expect(inTopBar('Dashboard'), findsOneWidget);
        expect(inTopBar(user.displayName), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AdminShellTopBar),
            matching: find.byType(RolePill),
          ),
          findsOneWidget,
        );
        expect(inTopBar('Admin'), findsOneWidget);
        expect(inTopBar('Sign out'), findsOneWidget);
        // The side nav footer repeats the role (never a name).
        expect(inNav('Admin'), findsOneWidget);
        expect(inNav(user.displayName), findsNothing);

        // The routed screen fills the content area.
        expect(find.text('Status breakdown'), findsOneWidget);
      },
    );

    testWidgets('shows a verifier their own name and role', (tester) async {
      await pumpAdmin(tester);
      await signInAs(tester, UserRole.verifier);
      final AppUser user = demoAccount(UserRole.verifier).user;

      expect(inTopBar(user.displayName), findsOneWidget);
      expect(inTopBar('Verifier'), findsOneWidget);
      expect(inNav('Dashboard'), findsOneWidget);
      expect(inNav('Complaints'), findsOneWidget);
    });

    testWidgets('nav switches the routed content and the highlight', (
      tester,
    ) async {
      final container = await pumpAdmin(tester);
      final router = container.read(appRouterProvider);
      await signInAs(tester, UserRole.admin);

      await tester.tap(inNav('Complaints'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.complaints);
      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(find.text('Status breakdown'), findsNothing);
      expect(sideNav(tester).selectedIndex, 1);
      expect(inTopBar('Complaints'), findsOneWidget);

      await tester.tap(inNav('Dashboard'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.dashboard);
      expect(find.text('Status breakdown'), findsOneWidget);
      expect(sideNav(tester).selectedIndex, 0);
      expect(inTopBar('Dashboard'), findsOneWidget);
    });

    testWidgets('the detail opens inside the shell with Complaints selected', (
      tester,
    ) async {
      final container = await pumpAdmin(tester);
      await signInAs(tester, UserRole.verifier);

      await openRoute(
        tester,
        container,
        AppRoutes.complaint(testSeed.complaints.first.id),
      );

      expect(find.byType(AdminSideNav), findsOneWidget);
      expect(sideNav(tester).selectedIndex, 1);
      expect(inTopBar('Complaint details'), findsOneWidget);
      expect(find.byType(ComplaintDetailScreen), findsOneWidget);

      // The side nav still navigates away from the detail.
      await tester.tap(inNav('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Status breakdown'), findsOneWidget);
    });

    testWidgets('Sign out returns to Login and closes the session', (
      tester,
    ) async {
      final container = await pumpAdmin(tester);
      final router = container.read(appRouterProvider);
      await signInAs(tester, UserRole.admin);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider), isNull);
      expect(container.read(authRepositoryProvider).currentUser, isNull);
      expect(find.text(_loginSubtitle), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.login);
      expect(router.state.uri.queryParameters, isEmpty);
      expect(find.byType(AdminSideNav), findsNothing);

      // The console is closed again.
      router.go(AppRoutes.complaints);
      await tester.pumpAndSettle();
      expect(find.text(_loginSubtitle), findsOneWidget);
    });

    testWidgets('the shell is a fixed frame around the scrolling content', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await signInAs(tester, UserRole.admin);

      // The shell is a fixed frame: the nav and the top bar do not scroll.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final Rect nav = tester.getRect(find.byType(AdminSideNav));
      expect(nav.height, 900);
      expect(nav.width, AppLayout.sideNavWidthExpanded);
      expect(
        tester.getSize(find.byType(AdminShellTopBar)).height,
        AppLayout.appBarHeightAdmin,
      );
    });
  });

  group('below 1024 px (graceful fallback)', () {
    testWidgets('the window-class boundary: 1024 expanded, 1023 rail', (
      tester,
    ) async {
      await pumpAdmin(tester, size: const Size(1024, 800));
      await signInAs(tester, UserRole.admin);
      expect(sideNav(tester).rail, isFalse);
      expect(
        tester.getSize(find.byType(AdminSideNav)).width,
        AppLayout.sideNavWidthExpanded,
      );

      await resizeTo(tester, const Size(1023, 800));
      expect(sideNav(tester).rail, isTrue);
      expect(
        tester.getSize(find.byType(AdminSideNav)).width,
        AppLayout.sideNavWidthRail,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'medium window: the icon rail navigates and nothing overflows',
      (tester) async {
        final container = await pumpAdmin(tester, size: const Size(700, 900));
        final router = container.read(appRouterProvider);
        await signInAs(tester, UserRole.admin);

        expect(sideNav(tester).rail, isTrue);
        // Rail items carry their label as a tooltip, not as text.
        expect(inNav('Complaints'), findsNothing);
        expect(find.byTooltip('Complaints'), findsOneWidget);
        expect(inTopBar('Sign out'), findsOneWidget);

        await tester.tap(find.byTooltip('Complaints'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.complaints);
        expect(sideNav(tester).selectedIndex, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('compact window: a drawer holds the nav behind a menu button', (
      tester,
    ) async {
      final container = await pumpAdmin(tester, size: const Size(420, 800));
      final router = container.read(appRouterProvider);
      await signInAs(tester, UserRole.admin);

      // No persistent nav; the page and the top bar fit without overflow.
      expect(find.byType(AdminSideNav), findsNothing);
      expect(find.byTooltip('Open navigation'), findsOneWidget);
      expect(find.text('Status breakdown'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSideNav), findsOneWidget);
      expect(sideNav(tester).rail, isFalse);
      expect(inNav('Dashboard'), findsOneWidget);

      await tester.tap(inNav('Complaints'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.complaints);
      expect(find.byType(AdminSideNav), findsNothing, reason: 'drawer closed');
      expect(find.byType(ComplaintListScreen), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('compact window: Sign out is an icon button', (tester) async {
      final container = await pumpAdmin(tester, size: const Size(420, 800));
      await signInAs(tester, UserRole.admin);

      expect(find.text('Sign out'), findsNothing);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider), isNull);
      expect(find.text(_loginSubtitle), findsOneWidget);
    });

    testWidgets('resizing keeps the route and the session', (tester) async {
      final container = await pumpAdmin(tester);
      final router = container.read(appRouterProvider);
      await signInAs(tester, UserRole.admin);
      await tester.tap(inNav('Complaints'));
      await tester.pumpAndSettle();

      for (final Size size in <Size>[
        const Size(800, 700),
        const Size(480, 700),
        const Size(1440, 900),
      ]) {
        await resizeTo(tester, size);
        expect(router.state.uri.path, AppRoutes.complaints, reason: '$size');
        expect(
          find.byType(ComplaintListScreen),
          findsOneWidget,
          reason: '$size',
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
      expect(container.read(sessionProvider), isNotNull);
    });
  });
}
