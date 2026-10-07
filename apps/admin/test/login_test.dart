import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/settled.dart';

const String _forbiddenTitle = "You don't have access to this page";

/// Taps the Login quick-fill for [role], then Sign in, and settles.
Future<void> quickSignIn(WidgetTester tester, UserRole role) async {
  await tester.tap(find.byKey(ValueKey<String>('demo-${role.name}')));
  await tester.pump();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to Login when signed out', (tester) async {
    await pumpAdmin(tester);

    expect(find.text('CampusFix Admin'), findsOneWidget);
    expect(find.text('Sign in to the admin console'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(2)); // ID + password
    expect(find.text('Demo accounts'), findsOneWidget);
    // Nothing of the console is reachable.
    expect(find.byType(AdminSideNav), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('the demo accounts are the admin and the verifier only', (
    tester,
  ) async {
    await pumpAdmin(tester);

    expect(find.byKey(const ValueKey<String>('demo-admin')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('demo-verifier')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('demo-reporter')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('demo-maintenance')),
      findsNothing,
    );
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Verifier'), findsOneWidget);
    expect(find.text('Reporter'), findsNothing);
    expect(find.text('Maintenance'), findsNothing);
  });

  testWidgets('a demo account fills the form', (tester) async {
    await pumpAdmin(tester);
    final MockAccount admin = demoAccount(UserRole.admin);

    await tester.tap(find.byKey(const ValueKey<String>('demo-admin')));
    await tester.pump();

    final List<EditableText> fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields[0].controller.text, admin.user.idNumber);
    expect(fields[1].controller.text, admin.password);
  });

  testWidgets('AC-01 Sign in stays disabled until both fields are filled', (
    tester,
  ) async {
    await pumpAdmin(tester);

    Future<void> tapSignIn() async {
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }

    await tapSignIn();
    expect(find.text('ID or password is incorrect'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, '1234');
    await tester.pump();
    await tapSignIn();
    // Password still empty: the tap did nothing (no error, still on Login).
    expect(find.text('ID or password is incorrect'), findsNothing);
    expect(find.text('Sign in to the admin console'), findsOneWidget);
  });

  testWidgets('AC-02 wrong password shows the generic error and clears it', (
    tester,
  ) async {
    await pumpAdmin(tester);
    final String id = demoAccount(UserRole.admin).user.idNumber;

    await tester.enterText(find.byType(EditableText).at(0), id);
    await tester.enterText(find.byType(EditableText).at(1), 'not-the-password');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('ID or password is incorrect'), findsOneWidget);
    expect(find.text('Sign in to the admin console'), findsOneWidget);
    final EditableText password = tester.widget(
      find.byType(EditableText).at(1),
    );
    expect(password.controller.text, isEmpty);

    // Editing a field dismisses the error.
    await tester.enterText(find.byType(EditableText).at(1), 'x');
    await tester.pump();
    expect(find.text('ID or password is incorrect'), findsNothing);
  });

  testWidgets('G-3 sign-in shows a loading state and locks the form', (
    tester,
  ) async {
    await pumpAdmin(tester, latency: const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey<String>('demo-admin')));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    final Finder signIn = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Sign in',
    );
    expect(tester.widget<AppButton>(signIn).loading, isTrue);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey<String>('demo-admin')))
          .onPressed,
      isNull,
      reason: 'quick-fill is disabled while signing in',
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSideNav), findsOneWidget);

    // The dashboard behind it now loads the complaints (400 ms of latency).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('an unexpected failure keeps the input and offers Retry', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(ThrowingAuthRepository()),
      ],
    );

    await tester.tap(find.byKey(const ValueKey<String>('demo-admin')));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't sign you in. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    final EditableText id = tester.widget(find.byType(EditableText).at(0));
    expect(id.controller.text, demoAccount(UserRole.admin).user.idNumber);
  });

  testWidgets('an admin signs in and lands on the dashboard', (tester) async {
    final container = await pumpAdmin(tester);
    await quickSignIn(tester, UserRole.admin);

    final AppUser user = demoAccount(UserRole.admin).user;
    expect(container.read(sessionProvider), user);
    expect(find.text('Sign in to the admin console'), findsNothing);
    expect(find.text('Status breakdown'), findsOneWidget);
    expect(find.byType(AdminSideNav), findsOneWidget);
    expect(find.text(user.displayName), findsOneWidget);
  });

  testWidgets('a verifier signs in and lands on the dashboard', (tester) async {
    final container = await pumpAdmin(tester);
    await quickSignIn(tester, UserRole.verifier);

    final AppUser user = demoAccount(UserRole.verifier).user;
    expect(container.read(sessionProvider), user);
    expect(find.text('Status breakdown'), findsOneWidget);
    expect(find.text(user.displayName), findsOneWidget);
    expect(find.text('Verifier'), findsWidgets);
  });

  for (final UserRole role in <UserRole>[
    UserRole.reporter,
    UserRole.maintenance,
  ]) {
    testWidgets('AC-45 a ${role.label} sign-in is rejected with E-403', (
      tester,
    ) async {
      final container = await pumpAdmin(tester);
      await signInAs(tester, role);

      expect(find.text(_forbiddenTitle), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      // None of the console is shown, and no console data is exposed.
      expect(find.byType(AdminSideNav), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Sign in to the admin console'), findsNothing);
      expect(
        await tester.runAsync(() => settled(container, allComplaintsProvider)),
        isEmpty,
        reason: 'the session of a non-console role sees no complaints',
      );

      // Sign out is the way out: back to a clean Login, no session.
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider), isNull);
      expect(find.text('Sign in to the admin console'), findsOneWidget);
      expect(find.text(_forbiddenTitle), findsNothing);
    });
  }
}
