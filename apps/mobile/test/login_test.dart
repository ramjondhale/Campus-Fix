import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('boots to Login when signed out', (tester) async {
    await pumpCampusFix(tester);

    expect(find.text('Sign in with your ID number'), findsOneWidget);
    expect(find.text('ID number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Demo accounts'), findsOneWidget);
    for (final role in <UserRole>[
      UserRole.reporter,
      UserRole.maintenance,
      UserRole.verifier,
    ]) {
      expect(find.byKey(ValueKey<String>('demo-${role.name}')), findsOneWidget);
    }
    // Nothing of the signed-in app is reachable.
    expect(find.text('Report a Problem'), findsNothing);
  });

  testWidgets('AC-01 Sign in stays disabled until both fields are filled', (
    tester,
  ) async {
    await pumpCampusFix(tester);

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
    expect(find.text('Sign in with your ID number'), findsOneWidget);
  });

  testWidgets('AC-02 wrong password shows the generic error and clears it', (
    tester,
  ) async {
    await pumpCampusFix(tester);
    final String id = demoAccount(UserRole.reporter).user.idNumber;

    await tester.enterText(find.byType(EditableText).at(0), id);
    await tester.enterText(find.byType(EditableText).at(1), 'not-the-password');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('ID or password is incorrect'), findsOneWidget);
    expect(find.text('Sign in with your ID number'), findsOneWidget);
    final EditableText password = tester.widget(
      find.byType(EditableText).at(1),
    );
    expect(password.controller.text, isEmpty);
  });

  testWidgets('AC-04 an admin sign-in shows the web-console notice, no session',
      (tester) async {
    final container = await pumpCampusFix(tester);
    final admin = testSeed.demoAccounts.firstWhere(
      (a) => a.user.role == UserRole.admin,
    );

    await tester.enterText(
      find.byType(EditableText).at(0),
      admin.user.idNumber,
    );
    await tester.enterText(find.byType(EditableText).at(1), admin.password);
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Admins use the web console'), findsOneWidget);
    expect(find.text('Sign in with your ID number'), findsOneWidget);
    expect(container.read(sessionProvider), isNull);
    expect(container.read(authRepositoryProvider).currentUser, isNull);
  });
}
