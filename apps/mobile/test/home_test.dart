import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('reporter demo sign-in reaches Home (AC-03)', (tester) async {
    final container = await pumpCampusFix(tester);
    await signInAs(tester, UserRole.reporter);

    final AppUser user = demoAccount(UserRole.reporter).user;
    expect(container.read(sessionProvider), user);
    expect(find.text('Sign in with your ID number'), findsNothing);

    // The header shows the signed-in user's own display name.
    expect(find.text(user.displayName), findsOneWidget);
    expect(find.text('Report a Problem'), findsOneWidget);
    expect(find.text('My active complaints'), findsOneWidget);
    expect(find.text('Campus board highlights'), findsOneWidget);

    // Reporter bottom nav: Home, My Complaints, Board, Alerts.
    expect(find.byType(AppBottomNav), findsOneWidget);
    for (final label in <String>['Home', 'My Complaints', 'Board', 'Alerts']) {
      expect(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('maintenance demo sign-in reaches its landing Home', (
    tester,
  ) async {
    await pumpCampusFix(tester);
    await signInAs(tester, UserRole.maintenance);

    expect(find.text('Open my work'), findsOneWidget);
    expect(find.text('Report a Problem'), findsNothing);
    final bar = find.byType(AppBottomNav);
    expect(find.descendant(of: bar, matching: find.text('Work')), findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('My Complaints')),
      findsNothing,
    );
  });

  testWidgets('verifier demo sign-in reaches its landing Home', (tester) async {
    await pumpCampusFix(tester);
    await signInAs(tester, UserRole.verifier);

    expect(find.text('Open verification queue'), findsOneWidget);
    expect(find.text('Report a Problem'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Verify'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('bottom nav opens a stubbed feature as Coming soon', (
    tester,
  ) async {
    await pumpCampusFix(tester);
    await signInAs(tester, UserRole.reporter);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('My Complaints'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('Sign out from the user menu returns to Login', (tester) async {
    final container = await pumpCampusFix(tester);
    await signInAs(tester, UserRole.reporter);

    await tester.tap(find.bySemanticsLabel('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isNull);
    expect(find.text('Sign in with your ID number'), findsOneWidget);
  });
}
