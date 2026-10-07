import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../router/routes.dart';

/// The route each bottom-nav destination of [role] opens, in the order of
/// `AppBottomNav.destinationsFor(role)` (screens-spec G-9).
///
/// * Reporter: Home, My Complaints, Board, Alerts.
/// * Maintenance: Work (the role dashboard), Board, Notifications.
/// * Verifier: Verify (the role dashboard), Board, Notifications.
///
/// The Report flow is not a tab: it is the Home call to action and the
/// "Report a Problem" button of My Complaints / Board.
List<String> navPathsFor(UserRole role) => switch (role) {
  UserRole.maintenance || UserRole.verifier => const <String>[
    AppRoutes.home,
    AppRoutes.board,
    AppRoutes.notifications,
  ],
  UserRole.admin => const <String>[AppRoutes.home],
  // The remaining role is the person who reports problems.
  _ => const <String>[
    AppRoutes.home,
    AppRoutes.complaints,
    AppRoutes.board,
    AppRoutes.notifications,
  ],
};

/// The bottom-nav destination that [location] belongs to. The work queue
/// (`/work`) and the verification queue (`/verify`) live under the first tab,
/// the role's dashboard destination.
int navIndexFor(UserRole role, String location) {
  final List<String> segments = Uri.parse(location).pathSegments;
  final String segment = segments.isEmpty ? 'home' : segments.first;
  final String top = switch (segment) {
    'work' || 'verify' => 'home',
    _ => segment,
  };
  final int index = navPathsFor(role).indexOf('/$top');
  return index < 0 ? 0 : index;
}

/// The role-aware scaffold around the top-level screens: the page itself plus
/// the bottom navigation of the signed-in role, with the unread-notifications
/// badge on the notifications destination. Detail and flow screens are pushed
/// above it and carry their own back navigation.
class RoleScaffold extends ConsumerWidget {
  const RoleScaffold({super.key, required this.location, required this.child});

  /// The current route path, used to highlight the right destination.
  final String location;

  /// The current top-level page.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final List<String> paths = navPathsFor(user.role);
    final List<AppNavDestination> destinations =
        AppBottomNav.destinationsFor(user.role).take(paths.length).toList();
    final int unread = ref.watch(unreadNotificationCountProvider);
    final int alerts = paths.indexOf(AppRoutes.notifications);
    if (alerts >= 0 && unread > 0) {
      destinations[alerts] = destinations[alerts].withBadge(count: unread);
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: destinations.length < 2
          ? null
          : AppBottomNav(
              destinations: destinations,
              selectedIndex: navIndexFor(user.role, location),
              onSelected: (int i) => context.go(paths[i]),
            ),
    );
  }
}
