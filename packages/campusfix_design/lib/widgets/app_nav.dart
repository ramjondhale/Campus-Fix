import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';
import 'user_avatar.dart';

/// One destination of the [AppBottomNav] or [AdminSideNav] (contract 8.19).
@immutable
class AppNavDestination {
  /// Creates a destination.
  const AppNavDestination({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.showDot = false,
  });

  /// Outlined glyph (24 in the bottom nav, 20 in the side nav).
  final IconData icon;

  /// Visible label.
  final String label;

  /// Unread count in a badge ("99+" cap).
  final int? badgeCount;

  /// A bare 8 px dot for unread without a count.
  final bool showDot;

  /// Copy with a different badge.
  AppNavDestination withBadge({int? count, bool dot = false}) =>
      AppNavDestination(
        icon: icon,
        label: label,
        badgeCount: count,
        showDot: dot,
      );
}

/// The mobile bottom navigation (contract 8.19): 64 high plus the bottom safe
/// area, fill `card`, 1 px `outlineVariant` top border, three or four equal
/// destinations by role.
///
/// Icon 24 inside a 56 x 28 pill and a `label-sm` label. Active: pill
/// `primaryContainer`, icon `onPrimaryContainer`, label `onSurface`;
/// inactive: `onSurfaceVariant`. The badge is `error` with `onError` text
/// (min 16 high, "99+" cap), or a bare 8 px dot.
class AppBottomNav extends StatelessWidget {
  /// Creates a bottom nav.
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(destinations.length >= 2 && destinations.length <= 5);

  /// The destinations (3 or 4 by role).
  final List<AppNavDestination> destinations;

  /// The selected destination.
  final int selectedIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelected;

  /// The destinations of a role (G-9).
  ///
  /// Reporter: Home, My Complaints, Board, Alerts. Maintenance: Work, Board,
  /// Notifications. Verifier: Verify, Board, Notifications. The admin console
  /// is a desktop app; its two destinations are returned as a graceful
  /// fallback only. "Alerts" is the short label of four-item bars so labels do
  /// not truncate at 360 wide (design question 3).
  static List<AppNavDestination> destinationsFor(
    UserRole role,
  ) => switch (role) {
    UserRole.maintenance => const <AppNavDestination>[
      AppNavDestination(icon: Icons.build_outlined, label: 'Work'),
      AppNavDestination(icon: Icons.view_kanban_outlined, label: 'Board'),
      AppNavDestination(icon: Icons.notifications_none, label: 'Notifications'),
    ],
    UserRole.verifier => const <AppNavDestination>[
      AppNavDestination(icon: Icons.fact_check_outlined, label: 'Verify'),
      AppNavDestination(icon: Icons.view_kanban_outlined, label: 'Board'),
      AppNavDestination(icon: Icons.notifications_none, label: 'Notifications'),
    ],
    UserRole.admin => AdminSideNav.defaultDestinations,
    // The remaining role is the person who reports problems.
    _ => const <AppNavDestination>[
      AppNavDestination(icon: Icons.home_outlined, label: 'Home'),
      AppNavDestination(icon: Icons.list_alt_outlined, label: 'My Complaints'),
      AppNavDestination(icon: Icons.view_kanban_outlined, label: 'Board'),
      AppNavDestination(icon: Icons.notifications_none, label: 'Alerts'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    // A DecoratedBox keeps the 1 px top border inside the 64 px height.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppLayout.bottomNavHeight,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    index: i,
                    total: destinations.length,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final int count = destination.badgeCount ?? 0;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      radius: AppRadius.brFull,
      semanticLabel:
          '${destination.label}, tab ${index + 1} of $total'
          '${count > 0 ? ', $count unread' : (destination.showDot ? ', unread' : '')}',
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color iconColor = selected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 28,
                    decoration: BoxDecoration(
                      color: applyStateLayer(
                        selected ? scheme.primaryContainer : Colors.transparent,
                        iconColor,
                        states,
                      ),
                      borderRadius: AppRadius.brFull,
                    ),
                    alignment: Alignment.center,
                    child: Icon(destination.icon, size: 24, color: iconColor),
                  ),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: 4,
                      child: CountBadge(count: count),
                    )
                  else if (destination.showDot)
                    const Positioned(top: 0, right: 12, child: DotBadge()),
                ],
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                destination.label,
                style: context.textTheme.labelSmall!.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The admin side navigation (contract 8.19): 240 wide (a 72 rail on medium
/// windows, a drawer below 600), fill `card`, 1 px `outlineVariant` right
/// border, padding 16 x 12.
///
/// A brand block on top (a 28 px `primary` square mark and the wordmark),
/// items 44 high with radius `r4` (icon 20 plus `label-lg`; active
/// `primaryContainer` / `onPrimaryContainer`; hover overlay 6%) and a footer
/// with the avatar and the role label.
class AdminSideNav extends StatelessWidget {
  /// Creates a side nav.
  const AdminSideNav({
    super.key,
    this.destinations = defaultDestinations,
    required this.selectedIndex,
    required this.onSelected,
    this.rail = false,
    this.role,
    this.avatarInitials,
    this.brandName = 'CampusFix',
  });

  /// Dashboard and Complaints.
  static const List<AppNavDestination> defaultDestinations =
      <AppNavDestination>[
        AppNavDestination(
          icon: Icons.space_dashboard_outlined,
          label: 'Dashboard',
        ),
        AppNavDestination(icon: Icons.list_alt_outlined, label: 'Complaints'),
      ];

  /// The destinations.
  final List<AppNavDestination> destinations;

  /// The selected destination.
  final int selectedIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelected;

  /// The 72 px rail instead of the 240 px expanded nav.
  final bool rail;

  /// The signed-in user's role label in the footer (never a name).
  final UserRole? role;

  /// Initials for the footer avatar.
  final String? avatarInitials;

  /// Wordmark.
  final String brandName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final double width = rail
        ? AppLayout.sideNavWidthRail
        : AppLayout.sideNavWidthExpanded;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Brand(name: brandName, rail: rail),
          const SizedBox(height: AppSpace.s6),
          for (int i = 0; i < destinations.length; i++) ...<Widget>[
            _SideItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              rail: rail,
              onTap: () => onSelected(i),
            ),
            const SizedBox(height: AppSpace.s1),
          ],
          const Spacer(),
          if (avatarInitials != null || role != null)
            Row(
              mainAxisAlignment: rail
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: <Widget>[
                if (avatarInitials != null)
                  UserAvatar(initials: avatarInitials!),
                if (!rail && role != null) ...<Widget>[
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      role!.label,
                      style: context.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.name, required this.rail});

  final String name;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final Widget mark = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.br3,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.build_outlined, size: 16, color: scheme.onPrimary),
    );
    if (rail) return Center(child: ExcludeSemantics(child: mark));
    return Row(
      children: <Widget>[
        ExcludeSemantics(child: mark),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            name,
            style: context.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.destination,
    required this.selected,
    required this.rail,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final int count = destination.badgeCount ?? 0;
    final Widget item = AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: destination.label,
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color fg = selected
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;
        return Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: rail ? 0 : AppSpace.s3),
          decoration: BoxDecoration(
            color: applyStateLayer(
              selected ? scheme.primaryContainer : Colors.transparent,
              fg,
              states,
              hover: 0.06,
            ),
            borderRadius: AppRadius.br4,
          ),
          child: Row(
            mainAxisAlignment: rail
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: <Widget>[
              Icon(destination.icon, size: 20, color: fg),
              if (!rail) ...<Widget>[
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    destination.label,
                    style: context.textTheme.labelLarge!.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) CountBadge(count: count),
              ],
            ],
          ),
        );
      },
    );
    return rail ? Tooltip(message: destination.label, child: item) : item;
  }
}
