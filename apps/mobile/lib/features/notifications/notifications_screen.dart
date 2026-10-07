import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../shared/list_states.dart';

/// The Today / Earlier groups of the feed (screens-spec M-12).
class NotificationGroups {
  const NotificationGroups({this.today = const [], this.earlier = const []});

  final List<AppNotification> today;
  final List<AppNotification> earlier;

  bool get isEmpty => today.isEmpty && earlier.isEmpty;
}

/// Splits [items] (newest first) into notifications created on [now]'s local
/// calendar day and everything before it, keeping the order.
NotificationGroups groupNotifications(
  List<AppNotification> items,
  DateTime now,
) {
  final DateTime startOfToday = DateTime(now.year, now.month, now.day);
  final List<AppNotification> today = <AppNotification>[];
  final List<AppNotification> earlier = <AppNotification>[];
  for (final AppNotification n in items) {
    (n.createdAt.toLocal().isBefore(startOfToday) ? earlier : today).add(n);
  }
  return NotificationGroups(today: today, earlier: earlier);
}

/// The detail screen [role] opens for a notification about [complaintId]
/// (screens-spec M-12: Rp -> M-10, M -> M-14, V -> M-17).
String? notificationRoute(UserRole role, String complaintId) => switch (role) {
  UserRole.reporter => AppRoutes.complaint(complaintId),
  UserRole.maintenance => AppRoutes.workItem(complaintId),
  UserRole.verifier => AppRoutes.verifyItem(complaintId),
  // The admin console is on the web; mobile never holds an admin session.
  UserRole.admin => null,
};

/// M-12 Notifications: the signed-in user's in-app feed, grouped Today /
/// Earlier, newest first, unread ones marked. Tapping an item marks it read
/// and opens the related complaint. A bottom-nav tab.
///
/// `AppNotification` is PII-free by contract (privacy LK-1), so it is shown
/// directly.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> feed = ref.watch(
      notificationsProvider,
    );
    final int unread = ref.watch(unreadNotificationCountProvider);
    // Watched only to keep it current: a tap checks it (see `_open`).
    ref.watch(reachableComplaintIdsProvider);

    return Scaffold(
      appBar: AppTopBar.page(
        title: 'Notifications',
        actions: <Widget>[
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s2),
              child: AppButton(
                label: 'Mark all as read',
                size: AppButtonSize.sm,
                variant: AppButtonVariant.tertiary,
                onPressed: () => markAllNotificationsRead(ref),
              ),
            ),
        ],
      ),
      body: feed.when(
        loading: () => const _NotificationsSkeleton(),
        error: (_, _) => RefreshFill(
          onRefresh: () => refreshNotifications(ref),
          child: EmptyState.error(
            title: "Couldn't load notifications",
            onAction: () => refreshNotifications(ref),
          ),
        ),
        data: (List<AppNotification> items) {
          if (items.isEmpty) {
            return RefreshFill(
              onRefresh: () => refreshNotifications(ref),
              child: const EmptyState(
                icon: Icons.notifications_none,
                title: "You're all caught up",
                message: 'Updates on your complaints show up here.',
              ),
            );
          }
          final NotificationGroups groups = groupNotifications(
            items,
            DateTime.now(),
          );
          return RefreshIndicator(
            onRefresh: () => refreshNotifications(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.s4),
              children: <Widget>[
                if (groups.today.isNotEmpty)
                  ..._group(context, ref, 'Today', groups.today),
                if (groups.earlier.isNotEmpty)
                  ..._group(context, ref, 'Earlier', groups.earlier),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<AppNotification> items,
  ) {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s2, top: AppSpace.s2),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
      for (final AppNotification n in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s3),
          child: NotificationTile(
            notification: n,
            onTap: () => _open(context, ref, n),
          ),
        ),
    ];
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final AppUser? user = ref.read(sessionProvider);
    final GoRouter router = GoRouter.of(context);
    await markNotificationRead(ref, n.id);
    if (user == null) return;
    // A list that has not loaded yet counts as reachable: the target screen
    // handles its own states.
    final Set<String>? reachable = ref
        .read(reachableComplaintIdsProvider)
        .value;
    final String? target =
        reachable != null && !reachable.contains(n.complaintId)
        ? null
        : notificationRoute(user.role, n.complaintId);
    if (target == null) {
      if (context.mounted) AppToast.show(context, 'No longer available');
      return;
    }
    router.push(target);
  }
}

/// One notification row: an icon for the event kind, the title and message,
/// the Complaint ID, the relative time and, while unread, a dot.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final DateTime? now;

  static IconData iconFor(NotificationType type) => switch (type) {
    NotificationType.submission => Icons.outbox_outlined,
    NotificationType.assignment => Icons.assignment_ind_outlined,
    NotificationType.statusChange => Icons.update,
    NotificationType.completion => Icons.task_alt,
    NotificationType.closure => Icons.lock_outline,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppNotification n = notification;
    final bool unread = !n.read;
    final String time = formatRelativeTime(
      n.createdAt,
      now: now ?? DateTime.now(),
    );
    return AppPressable(
      onTap: onTap,
      semanticLabel:
          '${unread ? 'Unread. ' : ''}${n.title}. ${n.body} '
          '${n.complaintId}. $time',
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color base = unread
            ? Color.alphaBlend(
                scheme.primaryContainer.withValues(alpha: 0.35),
                context.campusColors.card,
              )
            : context.campusColors.card;
        return Container(
          padding: const EdgeInsets.all(AppSpace.s3),
          decoration: BoxDecoration(
            color: applyStateLayer(base, scheme.onSurface, states),
            borderRadius: AppRadius.br4,
            border: Border.all(
              color: unread ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.campusColors.cardSubtle,
                  borderRadius: AppRadius.br4,
                ),
                child: Icon(
                  iconFor(n.type),
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      n.title,
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: unread
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(n.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpace.s2),
                    Wrap(
                      spacing: AppSpace.s2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ComplaintIdText(id: n.complaintId),
                        Text(
                          time,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.s2,
                    top: AppSpace.s1,
                  ),
                  child: Container(
                    key: const ValueKey<String>('unread-dot'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.s4),
        children: <Widget>[
          for (int i = 0; i < 5; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpace.s3),
            const SkeletonBlock(height: 84, radius: AppRadius.br4),
          ],
        ],
      ),
    );
  }
}
