import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// The console's top bar (design contract 8.18, admin variant): 64 high, fill
/// `card`, bottom border `outlineVariant`, the page [title] in `headline-sm`,
/// and on the right the signed-in user's name, role pill and avatar plus
/// **Sign out**.
///
/// The design system's `AdminTopBar` shows the role pill and avatar but has no
/// room for the signed-in user's own name or a Sign out action, so the shell
/// carries this layout-only variant built from the same tokens and shared
/// widgets (`RolePill`, `UserAvatar`, `AppButton`). Compact windows trade the
/// name and the labelled button for a [onMenu] button and an icon-only Sign
/// out.
class AdminShellTopBar extends StatelessWidget {
  const AdminShellTopBar({
    super.key,
    required this.title,
    required this.user,
    required this.onSignOut,
    this.onMenu,
  });

  /// Page title.
  final String title;

  /// The signed-in user: their own name and role (never anyone else's).
  final AppUser user;

  /// Called by the Sign out action.
  final VoidCallback onSignOut;

  /// Opens the navigation drawer. Non-null only on compact windows, where it
  /// shows the menu button.
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool compact = context.windowClass == AppWindowClass.compact;
    return Container(
      height: AppLayout.appBarHeightAdmin,
      padding: EdgeInsets.only(
        left: onMenu != null ? AppSpace.s1 : AppSpace.s6,
        right: compact ? AppSpace.s2 : AppSpace.s6,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          if (onMenu != null)
            AppIconButton(
              icon: Icons.menu,
              tooltip: 'Open navigation',
              onPressed: onMenu,
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (!compact) ...<Widget>[
            Flexible(
              child: Text(
                user.displayName,
                style: theme.textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpace.s3),
          ],
          RolePill(role: user.role),
          const SizedBox(width: AppSpace.s3),
          UserAvatar(
            initials: UserAvatar.initialsOf(user.displayName),
            semanticLabel: 'Signed in as ${user.displayName}',
          ),
          const SizedBox(width: AppSpace.s2),
          if (compact)
            AppIconButton(
              icon: Icons.logout,
              tooltip: 'Sign out',
              onPressed: onSignOut,
            )
          else
            AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.tertiary,
              size: AppButtonSize.sm,
              leadingIcon: Icons.logout,
              onPressed: onSignOut,
            ),
        ],
      ),
    );
  }
}
