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

/// The mobile app bar (contract 8.18): 56 high, title `title-lg`
/// left-aligned, icon buttons with a 48 hit area. Use it as
/// `Scaffold.appBar`.
///
/// Variants: [AppTopBar.home] (greeting, notification bell with badge, user
/// avatar), [AppTopBar.page] (back arrow, title, trailing actions; `filled`
/// with a bottom border on detail pages) and [AppTopBar.flow] (close, title,
/// "Step 2 of 5 · Location" and a segmented progress bar). A 1 px
/// `outlineVariant` bottom edge appears when content scrolls under it
/// ([showEdge]); there is no shadow.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar._({
    super.key,
    required this.variant,
    this.title,
    this.greeting,
    this.onBack,
    this.onClose,
    this.actions = const <Widget>[],
    this.filled = false,
    this.showEdge = false,
    this.unreadCount,
    this.onNotifications,
    this.avatarInitials,
    this.onAvatar,
    this.stepLabel,
    this.step = 1,
    this.totalSteps = 5,
  });

  /// The home bar: a small [greeting], the user's [name] (`title-md`), the
  /// notification bell with the [unreadCount] badge and the avatar.
  const AppTopBar.home({
    Key? key,
    required String greeting,
    required String name,
    String avatarInitials = '?',
    int? unreadCount,
    VoidCallback? onNotifications,
    VoidCallback? onAvatar,
    bool showEdge = false,
  }) : this._(
         key: key,
         variant: AppTopBarVariant.home,
         greeting: greeting,
         title: name,
         avatarInitials: avatarInitials,
         unreadCount: unreadCount,
         onNotifications: onNotifications,
         onAvatar: onAvatar,
         showEdge: showEdge,
       );

  /// The page bar: back arrow, [title] and trailing [actions].
  const AppTopBar.page({
    Key? key,
    required String title,
    VoidCallback? onBack,
    List<Widget> actions = const <Widget>[],
    bool filled = false,
    bool showEdge = false,
  }) : this._(
         key: key,
         variant: AppTopBarVariant.page,
         title: title,
         onBack: onBack,
         actions: actions,
         filled: filled,
         showEdge: showEdge,
       );

  /// The report-flow bar: close, [title] and step progress.
  const AppTopBar.flow({
    Key? key,
    String title = 'Report a problem',
    required String stepLabel,
    required int step,
    int totalSteps = 5,
    VoidCallback? onClose,
  }) : this._(
         key: key,
         variant: AppTopBarVariant.flow,
         title: title,
         stepLabel: stepLabel,
         step: step,
         totalSteps: totalSteps,
         onClose: onClose,
       );

  /// Which variant this bar is.
  final AppTopBarVariant variant;

  /// Title (the user's name on the home bar).
  final String? title;

  /// Home bar greeting.
  final String? greeting;

  /// Page bar back callback; hides the back arrow when null.
  final VoidCallback? onBack;

  /// Flow bar close callback.
  final VoidCallback? onClose;

  /// Page bar trailing actions.
  final List<Widget> actions;

  /// Page bar `card` fill with a bottom border (detail pages).
  final bool filled;

  /// Shows the 1 px bottom edge (content scrolled under the bar).
  final bool showEdge;

  /// Home bar unread notifications.
  final int? unreadCount;

  /// Home bar bell callback.
  final VoidCallback? onNotifications;

  /// Home bar avatar initials.
  final String? avatarInitials;

  /// Home bar avatar callback.
  final VoidCallback? onAvatar;

  /// Flow bar step name ("Location").
  final String? stepLabel;

  /// Flow bar current step (1 based).
  final int step;

  /// Flow bar number of steps.
  final int totalSteps;

  static const double _height = 56;

  @override
  Size get preferredSize => Size.fromHeight(
    variant == AppTopBarVariant.flow ? _height + 44 : _height,
  );

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool edge = showEdge || (variant == AppTopBarVariant.page && filled);
    final Color fill = variant == AppTopBarVariant.page && filled
        ? colors.card
        : scheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: edge
            ? Border(bottom: BorderSide(color: scheme.outlineVariant))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: switch (variant) {
          AppTopBarVariant.home => _home(context),
          AppTopBarVariant.page => _page(context),
          AppTopBarVariant.flow => _flow(context),
        },
      ),
    );
  }

  Widget _home(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.s4, right: AppSpace.s1),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greeting ?? '',
                    style: context.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      title ?? '',
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            AppIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              badgeCount: unreadCount,
              onPressed: onNotifications,
            ),
            AppPressable(
              onTap: onAvatar,
              radius: AppRadius.brFull,
              semanticLabel: 'Account menu',
              builder: (BuildContext context, Set<WidgetState> states) =>
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: UserAvatar(initials: avatarInitials ?? '?'),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        children: <Widget>[
          if (onBack != null)
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: onBack,
            )
          else
            const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title ?? '',
                style: context.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ...actions,
          const SizedBox(width: AppSpace.s1),
        ],
      ),
    );
  }

  Widget _flow(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: onClose,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title ?? '',
                    style: context.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Semantics(
            label:
                'Step $step of $totalSteps${stepLabel == null ? '' : ', $stepLabel'}',
            excludeSemantics: true,
            child: Text(
              'Step $step of $totalSteps${stepLabel == null ? '' : ' · $stepLabel'}',
              style: context.textTheme.labelMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            AppSpace.s3,
          ),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < totalSteps; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpace.s1),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < step ? scheme.primary : scheme.outlineVariant,
                      borderRadius: AppRadius.br1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The variants of [AppTopBar].
enum AppTopBarVariant {
  /// Greeting, bell and avatar.
  home,

  /// Back arrow, title and actions.
  page,

  /// Close, title and step progress.
  flow,
}

/// The admin top bar (contract 8.18): 64 high, fill `card`, bottom border
/// `outlineVariant`, page title `headline-sm`; on the right an optional range
/// control, the [RolePill] and the avatar.
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates an admin top bar.
  const AdminTopBar({
    super.key,
    required this.title,
    this.rangeControl,
    this.role,
    this.avatarInitials,
  });

  /// Page title.
  final String title;

  /// Optional range control (an `AppSegmented`).
  final Widget? rangeControl;

  /// The signed-in user's role (shown as a pill; never a name).
  final UserRole? role;

  /// Initials of the signed-in user's avatar.
  final String? avatarInitials;

  @override
  Size get preferredSize => const Size.fromHeight(AppLayout.appBarHeightAdmin);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Container(
      height: AppLayout.appBarHeightAdmin,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s6),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // The range control needs room; on compact windows (a fallback
          // only, SC-OI-2) it is dropped so the bar never overflows.
          if (rangeControl != null &&
              context.windowClass != AppWindowClass.compact) ...<Widget>[
            rangeControl!,
            const SizedBox(width: AppSpace.s4),
          ],
          if (role != null) ...<Widget>[
            RolePill(role: role!),
            const SizedBox(width: AppSpace.s3),
          ],
          if (avatarInitials != null)
            UserAvatar(
              initials: avatarInitials!,
              semanticLabel: 'Signed-in user',
            ),
        ],
      ),
    );
  }
}
