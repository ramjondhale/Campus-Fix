import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import 'admin_nav.dart';
import 'admin_top_bar.dart';

/// The responsive, desktop-first scaffold around the console screens
/// (design contract 8.19, section 4.2): the side navigation, the top bar and
/// the routed page.
///
/// * **Expanded** (1024 px and up, the target): a persistent 240 px side nav.
/// * **Medium** (600 to 1023): the 72 px icon rail.
/// * **Compact** (below 600, a graceful fallback only): no persistent nav; a
///   menu button in the top bar opens the same nav in a drawer.
///
/// The selected destination follows [location]; a tap navigates with
/// `context.go`. The routed screen fills the area below the top bar and owns
/// its own scrolling (see `AdminPage`).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  /// The current route path, used to highlight the right destination and to
  /// title the top bar.
  final String location;

  /// The current routed page.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final AppWindowClass windowClass = context.windowClass;

    AdminSideNav sideNav({required bool rail, VoidCallback? afterSelect}) =>
        AdminSideNav(
          selectedIndex: navIndexFor(location),
          rail: rail,
          role: user.role,
          avatarInitials: UserAvatar.initialsOf(user.displayName),
          onSelected: (int i) {
            afterSelect?.call();
            context.go(kAdminNavPaths[i]);
          },
        );

    Widget topBar({VoidCallback? onMenu}) => AdminShellTopBar(
      title: pageTitleFor(location),
      user: user,
      onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
      onMenu: onMenu,
    );

    if (windowClass == AppWindowClass.compact) {
      return Scaffold(
        drawer: Builder(
          builder: (BuildContext drawerContext) => Drawer(
            width: AppLayout.sideNavWidthExpanded,
            child: sideNav(
              rail: false,
              afterSelect: () => Scaffold.of(drawerContext).closeDrawer(),
            ),
          ),
        ),
        body: Builder(
          builder: (BuildContext bodyContext) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              topBar(onMenu: () => Scaffold.of(bodyContext).openDrawer()),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          sideNav(rail: windowClass == AppWindowClass.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                topBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
