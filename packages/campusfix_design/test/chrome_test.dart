import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_design/gallery/gallery_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  for (final Brightness brightness in kBrightnesses) {
    group('EmptyState ($brightness)', () {
      testWidgets('every variant shows icon, title and its action', (
        WidgetTester tester,
      ) async {
        final List<(Widget, String, String?)> variants =
            <(Widget, String, String?)>[
              (
                EmptyState.nothing(
                  actionLabel: 'Report a problem',
                  onAction: () {},
                ),
                "You haven't reported anything yet",
                'Report a problem',
              ),
              (
                EmptyState.filtered(onAction: () {}),
                'No matching complaints',
                'Clear filters',
              ),
              (
                EmptyState.error(onAction: () {}),
                "Couldn't load complaints",
                'Retry',
              ),
              (
                EmptyState.notFound(onAction: () {}),
                "We couldn't find that complaint",
                'Go home',
              ),
              (
                EmptyState.forbidden(onAction: () {}),
                "You don't have access to this page",
                'Go home',
              ),
              (
                const EmptyState.nothing(),
                "You haven't reported anything yet",
                null,
              ),
            ];
        for (final (Widget widget, String title, String? action) in variants) {
          await pumpApp(
            tester,
            SizedBox(width: 360, child: widget),
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expect(find.text(title), findsOneWidget);
          if (action != null) {
            expect(find.text(action), findsOneWidget);
          } else {
            expect(find.byType(AppButton), findsNothing);
          }
        }
      });

      testWidgets('action fires; admin tables left-align it', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          SizedBox(
            width: 600,
            child: EmptyState.filtered(
              alignment: CrossAxisAlignment.start,
              onAction: () => taps++,
            ),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Clear filters'));
        expect(taps, 1);
        expect(
          tester.getTopLeft(find.text('No matching complaints')).dx,
          lessThan(100),
        );
      });
    });

    group('navigation ($brightness)', () {
      testWidgets('AppBottomNav: destinations by role, badge cap, selection', (
        WidgetTester tester,
      ) async {
        int selected = 0;
        final List<AppNavDestination> reporter = AppBottomNav.destinationsFor(
          GalleryFixtures.filerRole,
        );
        expect(reporter.map((AppNavDestination d) => d.label), <String>[
          'Home',
          'My Complaints',
          'Board',
          'Alerts',
        ]);
        expect(
          AppBottomNav.destinationsFor(
            UserRole.maintenance,
          ).map((AppNavDestination d) => d.label),
          <String>['Work', 'Board', 'Notifications'],
        );
        expect(
          AppBottomNav.destinationsFor(
            UserRole.verifier,
          ).map((AppNavDestination d) => d.label),
          <String>['Verify', 'Board', 'Notifications'],
        );
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => SizedBox(
              width: 360,
              child: AppBottomNav(
                destinations: <AppNavDestination>[
                  reporter[0],
                  reporter[1],
                  reporter[2].withBadge(dot: true),
                  reporter[3].withBadge(count: 150),
                ],
                selectedIndex: selected,
                onSelected: (int i) => setState(() => selected = i),
              ),
            ),
          ),
          brightness: brightness,
          size: const Size(400, 600),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('99+'), findsOneWidget);
        expect(find.byType(DotBadge), findsOneWidget);
        expect(tester.getSize(find.byType(AppBottomNav)).height, 64);
        await tester.tap(find.text('Board'));
        await tester.pump();
        expect(selected, 2);
      });

      testWidgets('AdminSideNav: expanded 240 and rail 72, selection', (
        WidgetTester tester,
      ) async {
        int selected = 0;
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => SizedBox(
              height: 400,
              child: AdminSideNav(
                selectedIndex: selected,
                onSelected: (int i) => setState(() => selected = i),
                role: UserRole.admin,
                avatarInitials: 'AD',
              ),
            ),
          ),
          brightness: brightness,
        );
        expect(tester.getSize(find.byType(AdminSideNav)).width, 240);
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Complaints'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
        await tester.tap(find.text('Complaints'));
        await tester.pump();
        expect(selected, 1);

        await pumpApp(
          tester,
          SizedBox(
            height: 400,
            child: AdminSideNav(
              rail: true,
              selectedIndex: 0,
              onSelected: (int i) {},
            ),
          ),
          brightness: brightness,
        );
        expect(tester.getSize(find.byType(AdminSideNav)).width, 72);
        expect(find.text('Dashboard'), findsNothing);
      });

      testWidgets('AppTopBar variants and AdminTopBar', (
        WidgetTester tester,
      ) async {
        int back = 0;
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: Column(
              children: <Widget>[
                AppTopBar.home(
                  greeting: 'Good afternoon',
                  name: 'Campus user',
                  avatarInitials: 'CU',
                  unreadCount: 3,
                  onNotifications: () {},
                ),
                AppTopBar.page(
                  title: 'CF-2026-00042',
                  filled: true,
                  onBack: () => back++,
                ),
                AppTopBar.flow(stepLabel: 'Location', step: 2, onClose: () {}),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(400, 800),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Good afternoon'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Step 2 of 5 · Location'), findsOneWidget);
        expect(tester.getSize(find.byType(AppTopBar).first).height, 56);
        await tester.tap(find.byIcon(Icons.arrow_back));
        expect(back, 1);

        await pumpApp(
          tester,
          const AdminTopBar(
            title: 'Dashboard',
            role: UserRole.admin,
            avatarInitials: 'AD',
          ),
          brightness: brightness,
        );
        expect(tester.getSize(find.byType(AdminTopBar)).height, 64);
        expect(find.text('Admin'), findsOneWidget);
      });
    });

    group('overlays ($brightness)', () {
      testWidgets('AppDialog.confirm resolves true / false', (
        WidgetTester tester,
      ) async {
        bool? result;
        await pumpApp(
          tester,
          Builder(
            builder: (BuildContext context) => AppButton(
              label: 'Open',
              onPressed: () async => result = await AppDialog.confirm(
                context: context,
                title: 'Reject and request rework?',
                message: 'The team will see your note.',
                confirmLabel: 'Reject',
                destructive: true,
              ),
            ),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Reject and request rework?'), findsOneWidget);
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });

      testWidgets(
        'confirmWithNote keeps confirm disabled until a note exists',
        (WidgetTester tester) async {
          String? note;
          await pumpApp(
            tester,
            Builder(
              builder: (BuildContext context) => AppButton(
                label: 'Open',
                onPressed: () async => note = await AppDialog.confirmWithNote(
                  context: context,
                  title: 'Reject and request rework?',
                  noteLabel: 'What still needs fixing?',
                  confirmLabel: 'Reject',
                ),
              ),
            ),
            brightness: brightness,
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reject'));
          await tester.pumpAndSettle();
          expect(note, isNull);
          expect(find.text('Reject and request rework?'), findsOneWidget);
          await tester.enterText(find.byType(TextField), '  Seal it fully  ');
          await tester.pump();
          await tester.tap(find.text('Reject'));
          await tester.pumpAndSettle();
          expect(note, 'Seal it fully');
        },
      );

      testWidgets('AppBottomSheet.showOptions returns the chosen value', (
        WidgetTester tester,
      ) async {
        String? choice;
        await pumpApp(
          tester,
          Builder(
            builder: (BuildContext context) => AppButton(
              label: 'Open',
              onPressed: () async =>
                  choice = await AppBottomSheet.showOptions<String>(
                    context: context,
                    title: 'Add a photo',
                    options: const <AppSheetOption<String>>[
                      AppSheetOption<String>(
                        value: 'camera',
                        label: 'Take a photo',
                        icon: Icons.photo_camera_outlined,
                      ),
                      AppSheetOption<String>(
                        value: 'gallery',
                        label: 'Choose from gallery',
                      ),
                    ],
                  ),
            ),
          ),
          brightness: brightness,
          size: const Size(400, 800),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Add a photo'), findsOneWidget);
        await tester.tap(find.text('Choose from gallery'));
        await tester.pumpAndSettle();
        expect(choice, 'gallery');
      });

      testWidgets('AppToast shows message, action and error persistence', (
        WidgetTester tester,
      ) async {
        int undone = 0;
        await pumpApp(
          tester,
          Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                AppButton(
                  label: 'Success',
                  onPressed: () => AppToast.show(
                    context,
                    'Sent for verification',
                    kind: AppToastKind.success,
                    actionLabel: 'Undo',
                    onAction: () => undone++,
                  ),
                ),
                AppButton(
                  label: 'Error',
                  onPressed: () => AppToast.show(
                    context,
                    'Could not send.',
                    kind: AppToastKind.error,
                  ),
                ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(500, 800),
        );
        await tester.tap(find.text('Success'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Sent for verification'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        await tester.tap(find.text('Undo'));
        expect(undone, 1);

        await tester.tap(find.text('Error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Could not send.'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        // Errors persist: still there well after the 4 s default.
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('Could not send.'), findsOneWidget);
      });

      testWidgets('AppToast returns null without a ScaffoldMessenger', (
        WidgetTester tester,
      ) async {
        late BuildContext captured;
        await tester.pumpWidget(
          Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox();
            },
          ),
        );
        expect(AppToast.show(captured, 'x'), isNull);
      });
    });

    group('banners, roles and skeletons ($brightness)', () {
      testWidgets('InlineBanner renders every feedback kind', (
        WidgetTester tester,
      ) async {
        int retries = 0;
        await pumpApp(
          tester,
          SizedBox(
            width: 400,
            child: Column(
              children: <Widget>[
                for (final FeedbackKind kind in FeedbackKind.values)
                  InlineBanner(
                    kind: kind,
                    title: 'Title ${kind.name}',
                    message: 'Message ${kind.name}',
                    actionLabel: kind == FeedbackKind.error ? 'Retry' : null,
                    onAction: kind == FeedbackKind.error
                        ? () => retries++
                        : null,
                  ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(500, 800),
        );
        for (final FeedbackKind kind in FeedbackKind.values) {
          expect(find.text('Title ${kind.name}'), findsOneWidget);
        }
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        await tester.tap(find.text('Retry'));
        expect(retries, 1);
      });

      testWidgets('PrivacyNote fixed strings', (WidgetTester tester) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 400,
            child: Column(
              children: <Widget>[PrivacyNote.identity(), PrivacyNote.photos()],
            ),
          ),
          brightness: brightness,
        );
        expect(
          find.text(
            'Your name and contact details are never shown on the board or to '
            'maintenance staff.',
          ),
          findsOneWidget,
        );
        expect(
          find.text("Avoid including people's faces or documents."),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.verified_user_outlined), findsNWidgets(2));
      });

      testWidgets('RolePill names all four roles; avatar initials', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final UserRole r in UserRole.values) RolePill(role: r),
              const UserAvatar(initials: 'AB'),
              const UserAvatar(initials: 'CD', size: UserAvatarSize.s40),
            ],
          ),
          brightness: brightness,
        );
        for (final UserRole r in UserRole.values) {
          expect(find.text(r.label), findsOneWidget);
        }
        expect(find.text('AB'), findsOneWidget);
        expect(UserAvatar.initialsOf('Ada Lovelace'), 'AL');
        expect(UserAvatar.initialsOf('  grace  '), 'G');
        expect(UserAvatar.initialsOf(''), '?');
      });

      testWidgets('Skeleton is static under reduced motion', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 300,
            child: Skeleton(
              child: Column(
                children: <Widget>[
                  SkeletonBlock(height: 20),
                  SkeletonBlock.fraction(widthFactor: 0.5, height: 16),
                ],
              ),
            ),
          ),
          brightness: brightness,
        );
        expect(find.byType(SkeletonBlock), findsNWidgets(2));
        // pumpAndSettle only returns when nothing animates (reduced motion).
        await tester.pumpAndSettle();
        expect(find.byType(ShaderMask), findsNothing);
      });

      testWidgets('Skeleton shimmers with motion enabled', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.of(brightness),
            home: const Scaffold(
              body: Skeleton(child: SkeletonBlock(width: 200, height: 20)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);
      });
    });
  }

  testWidgets('gallery has the privacy callout and every section', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const WidgetGalleryScreen(),
      size: const Size(1280, 900),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CampusFix widget gallery'), findsOneWidget);
    expect(find.text('Privacy: this package is PII-free'), findsOneWidget);
    for (final String title in <String>[
      'AppButton',
      'TextField, Select, SearchField',
      'SelectTile, CategoryTile, toggles and filters',
      'StatusBadge, PriorityTag, CategoryChip, ComplaintId',
      'ComplaintCard',
      'ComplaintTable',
      'PhotoThumbnail, PhotoUploader, BeforeAfter',
      'StatusStepper, Timeline, Avatar, RolePill',
      'MetricCard',
      'AppTopBar, AdminTopBar, AppBottomNav, AdminSideNav',
      'Dialog, BottomSheet, Toast, InlineBanner, PrivacyNote, Skeleton',
    ]) {
      expect(find.textContaining(title), findsWidgets, reason: title);
    }
    expect(find.text('CF-2026-00042'), findsWidgets);
  });

  testWidgets('gallery theme toggle switches light and dark', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const WidgetGalleryScreen(initialBrightness: Brightness.light),
      size: const Size(1280, 900),
    );
    await tester.pump(const Duration(milliseconds: 300));
    Brightness current() => Theme.of(
      tester.element(find.text('CampusFix widget gallery')),
    ).brightness;
    expect(current(), Brightness.light);
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(current(), Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
