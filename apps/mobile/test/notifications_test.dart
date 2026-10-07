import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/features/notifications/notifications_screen.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:campusfix_mobile/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';
import 'support/pump_app.dart';
import 'support/rendered_text.dart';

Future<ProviderContainer> openNotifications(
  WidgetTester tester, {
  UserRole role = UserRole.reporter,
  List<Override> overrides = const <Override>[],
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: overrides,
  );
  await signInAs(tester, role);
  useTallView(tester, height: 6000);
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      // "Alerts" on the four-item reporter bar, "Notifications" otherwise.
      matching: find.text(
        role == UserRole.reporter ? 'Alerts' : 'Notifications',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

List<AppNotification> seedNotificationsOf(UserRole role) {
  final String id = demoAccount(role).user.id;
  return <AppNotification>[
    for (final AppNotification n in testSeed.notifications)
      if (n.recipientId == id) n,
  ];
}

Finder unreadTiles() => find.ancestor(
  of: find.byKey(const ValueKey<String>('unread-dot')),
  matching: find.byType(NotificationTile),
);

int unreadCount(ProviderContainer c) => c.read(unreadNotificationCountProvider);

void main() {
  testWidgets('lists the user\'s own notifications, newest first, unread '
      'marked (M-12)', (tester) async {
    final ProviderContainer container = await openNotifications(tester);
    final List<AppNotification> mine = seedNotificationsOf(UserRole.reporter);

    final List<NotificationTile> tiles = tester
        .widgetList<NotificationTile>(find.byType(NotificationTile))
        .toList();
    expect(tiles.length, mine.length);
    expect(
      <String>[for (final t in tiles) t.notification.id],
      <String>[
        for (final n in <AppNotification>[
          ...mine,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          n.id,
      ],
    );
    // Only this user's feed.
    expect(
      tiles.every(
        (t) =>
            t.notification.recipientId ==
            demoAccount(UserRole.reporter).user.id,
      ),
      isTrue,
    );
    // Grouped under a heading.
    expect(
      find.text('Today').evaluate().length +
          find.text('Earlier').evaluate().length,
      greaterThan(0),
    );

    // Unread ones carry a dot; the badge count agrees.
    final int unread = mine.where((n) => !n.read).length;
    expect(unread, greaterThan(0));
    expect(unreadTiles(), findsNWidgets(unread));
    expect(unreadCount(container), unread);
    expect(find.widgetWithText(AppButton, 'Mark all as read'), findsOneWidget);

    // Messages are shown as stored: complaint ID, title and message.
    final AppNotification first = tiles.first.notification;
    expect(find.text(first.title), findsWidgets);
    expect(find.text(first.body), findsWidgets);
  });

  testWidgets('tapping an unread item marks just that one read and opens '
      'its complaint', (tester) async {
    final ProviderContainer container = await openNotifications(tester);
    final int before = unreadCount(container);

    final NotificationTile tile = tester.widget<NotificationTile>(
      unreadTiles().first,
    );
    await tester.tap(unreadTiles().first);
    await tester.pumpAndSettle();

    expect(unreadCount(container), before - 1);
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.complaint(tile.notification.complaintId),
    );
    expect(find.text('Complaint details'), findsOneWidget);
    // The read state sticks: the stored notification is read now.
    final List<AppNotification> stored = container
        .read(notificationsProvider)
        .requireValue;
    expect(stored.firstWhere((n) => n.id == tile.notification.id).read, isTrue);
  });

  testWidgets('Mark all as read clears every unread dot and the badge', (
    tester,
  ) async {
    final ProviderContainer container = await openNotifications(tester);
    expect(unreadCount(container), greaterThan(0));

    await tester.tap(find.widgetWithText(AppButton, 'Mark all as read'));
    await tester.pumpAndSettle();

    expect(unreadCount(container), 0);
    expect(unreadTiles(), findsNothing);
    expect(find.widgetWithText(AppButton, 'Mark all as read'), findsNothing);
    // The bottom-nav badge is gone as well.
    final AppBottomNav nav = tester.widget<AppBottomNav>(
      find.byType(AppBottomNav),
    );
    expect(nav.destinations.every((d) => d.badgeCount == null), isTrue);
  });

  testWidgets('read notifications are styled apart from unread ones', (
    tester,
  ) async {
    await openNotifications(tester);
    final NotificationTile read = tester
        .widgetList<NotificationTile>(find.byType(NotificationTile))
        .firstWhere((t) => t.notification.read);
    final NotificationTile unread = tester
        .widgetList<NotificationTile>(find.byType(NotificationTile))
        .firstWhere((t) => !t.notification.read);

    expect(
      find.descendant(
        of: find.byWidget(read),
        matching: find.byKey(const ValueKey<String>('unread-dot')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byWidget(unread),
        matching: find.byKey(const ValueKey<String>('unread-dot')),
      ),
      findsOneWidget,
    );
    // The title weight differs (bold when unread).
    FontWeight? weightOf(NotificationTile t) => tester
        .widget<Text>(
          find.descendant(
            of: find.byWidget(t),
            matching: find.text(t.notification.title),
          ),
        )
        .style
        ?.fontWeight;
    expect(weightOf(unread), FontWeight.w700);
    expect(weightOf(read), isNot(FontWeight.w700));
  });

  testWidgets('maintenance: a notification for a complaint outside its '
      'queue says "No longer available"; one in the queue opens it', (
    tester,
  ) async {
    final ProviderContainer container = await openNotifications(
      tester,
      role: UserRole.maintenance,
    );
    final WorkQueue queue = container.read(workQueueProvider).requireValue;
    final Set<String> reachable = <String>{
      for (final PublicComplaintView c in <PublicComplaintView>[
        ...queue.toStart,
        ...queue.inProgress,
        ...queue.rework,
      ])
        c.id,
    };
    final List<AppNotification> feed = container
        .read(notificationsProvider)
        .requireValue;
    final AppNotification gone = feed.firstWhere(
      (n) => !reachable.contains(n.complaintId),
    );

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is NotificationTile && w.notification.id == gone.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No longer available'), findsOneWidget);
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.notifications,
    );

    final AppNotification there = feed.firstWhere(
      (n) => reachable.contains(n.complaintId),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is NotificationTile && w.notification.id == there.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.workItem(there.complaintId),
    );
  });

  testWidgets('verifier: a notification for a resolved complaint opens '
      'its verification screen', (tester) async {
    final ProviderContainer container = await openNotifications(
      tester,
      role: UserRole.verifier,
    );
    final Set<String> waiting = <String>{
      for (final PublicComplaintView c
          in container.read(verificationQueueProvider).requireValue)
        c.id,
    };
    final AppNotification there = container
        .read(notificationsProvider)
        .requireValue
        .firstWhere((n) => waiting.contains(n.complaintId));

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is NotificationTile && w.notification.id == there.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).state.uri.path,
      AppRoutes.verifyItem(there.complaintId),
    );
  });

  for (final UserRole role in <UserRole>[
    UserRole.reporter,
    UserRole.maintenance,
    UserRole.verifier,
  ]) {
    testWidgets('${role.label} feed text carries no identity (AC-32)', (
      tester,
    ) async {
      await openNotifications(tester, role: role);
      expect(find.byType(NotificationTile), findsWidgets);
      expect(identityLeaks(allRenderedText(tester)), isEmpty);
    });
  }

  testWidgets('an empty feed says "You\'re all caught up"', (tester) async {
    await openNotifications(
      tester,
      overrides: <Override>[
        notificationRepositoryProvider.overrideWithValue(
          MockNotificationRepository(),
        ),
      ],
    );
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.byType(NotificationTile), findsNothing);
    expect(find.widgetWithText(AppButton, 'Mark all as read'), findsNothing);
  });

  testWidgets('while loading it shows a skeleton', (tester) async {
    final ProviderContainer container = await pumpCampusFix(
      tester,
      overrides: <Override>[
        notificationRepositoryProvider.overrideWithValue(
          StalledNotificationRepository(),
        ),
      ],
    );
    await signInAs(tester, UserRole.reporter);
    container.read(appRouterProvider).go(AppRoutes.notifications);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(find.byType(NotificationTile), findsNothing);
  });

  test('groupNotifications splits Today from Earlier, keeping the order', () {
    final DateTime now = DateTime(2026, 10, 7, 15, 30);
    AppNotification at(String id, DateTime t) => AppNotification(
      id: id,
      recipientId: 'u',
      complaintId: 'CF-2026-00001',
      type: NotificationType.statusChange,
      title: 't',
      body: 'b',
      createdAt: t,
    );
    final NotificationGroups g = groupNotifications(<AppNotification>[
      at('a', DateTime(2026, 10, 7, 15)),
      at('b', DateTime(2026, 10, 7, 0, 0, 1)),
      at('c', DateTime(2026, 10, 6, 23, 59)),
      at('d', DateTime(2026, 9, 1)),
    ], now);
    expect(<String>[for (final n in g.today) n.id], <String>['a', 'b']);
    expect(<String>[for (final n in g.earlier) n.id], <String>['c', 'd']);
    expect(groupNotifications(const <AppNotification>[], now).isEmpty, isTrue);
  });
}
