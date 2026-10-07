import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'maintenance_home.dart';
import 'reporter_home.dart';
import 'verifier_home.dart';

/// "Good morning" / "Good afternoon" / "Good evening" for [now].
String greetingFor(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 18
    ? 'Good afternoon'
    : 'Good evening';

/// M-02 Home (role-aware): the signed-in user's own display name in the
/// header (session UI), the notification bell with the unread badge, a user
/// menu with Sign out, and a role-specific body. Pull-to-refresh re-reads the
/// data. Consumes public views only.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final int unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppTopBar.home(
        greeting: greetingFor(DateTime.now()),
        name: user.displayName,
        avatarInitials: UserAvatar.initialsOf(user.displayName),
        unreadCount: unread > 0 ? unread : null,
        onNotifications: () => context.go(AppRoutes.notifications),
        onAvatar: () => _showAccountMenu(context, ref, user),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait(<Future<void>>[
          refreshComplaints(ref),
          refreshNotifications(ref),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.s4),
          children: <Widget>[
            switch (user.role) {
              UserRole.maintenance => MaintenanceHome(user: user),
              UserRole.verifier => const VerifierHome(),
              // The remaining mobile role is the person who reports problems.
              _ => const ReporterHome(),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _showAccountMenu(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final SessionNotifier session = ref.read(sessionProvider.notifier);
    final String? choice = await AppBottomSheet.showOptions<String>(
      context: context,
      title: '${user.displayName} · ${user.role.label}',
      options: const <AppSheetOption<String>>[
        AppSheetOption<String>(
          value: 'sign-out',
          label: 'Sign out',
          icon: Icons.logout,
          destructive: true,
        ),
      ],
    );
    if (choice == 'sign-out') await session.signOut();
  }
}
