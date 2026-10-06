import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_nav.dart';
import '../widgets/app_segmented.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/inline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/user_avatar.dart';
import '../theme/tokens/semantic_tokens.dart';
import 'gallery_fixtures.dart';
import 'gallery_parts.dart';

/// 8.18 and 8.19: top bars and navigation.
class NavigationSection extends StatefulWidget {
  /// Creates the section.
  const NavigationSection({super.key});

  @override
  State<NavigationSection> createState() => _NavigationSectionState();
}

class _NavigationSectionState extends State<NavigationSection> {
  int _bottom = 0;
  int _side = 1;
  String _range = '30';

  @override
  Widget build(BuildContext context) {
    final List<AppNavDestination> reporter = AppBottomNav.destinationsFor(
      GalleryFixtures.filerRole,
    );
    return GallerySection(
      id: '8.18-8.19',
      title: 'AppTopBar, AdminTopBar, AppBottomNav, AdminSideNav',
      description:
          'Mobile bars are 56 high; the admin top bar is 64. Bottom nav is '
          '64 plus the safe area; side nav is 240 (72 as a rail).',
      children: <Widget>[
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'AppTopBar.home (greeting, bell with badge, avatar)',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppTopBar.home(
                  greeting: 'Good afternoon',
                  name: 'Campus user',
                  avatarInitials: 'CU',
                  unreadCount: 3,
                  onNotifications: () {},
                  onAvatar: () {},
                ),
              ),
            ),
            GalleryLabel(
              'AppTopBar.page (filled, with edge)',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppTopBar.page(
                  title: 'CF-2026-00042',
                  filled: true,
                  onBack: () {},
                  actions: <Widget>[
                    AppIconButton(
                      icon: Icons.content_copy,
                      tooltip: 'Copy ID',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            GalleryLabel(
              'AppTopBar.flow (report step 2 of 5)',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppTopBar.flow(
                  stepLabel: 'Location',
                  step: 2,
                  onClose: () {},
                ),
              ),
            ),
          ],
        ),
        GalleryLabel(
          'AdminTopBar (title, range control, role pill, avatar)',
          child: GalleryPanel(
            padding: false,
            child: AdminTopBar(
              title: 'Dashboard',
              role: UserRole.admin,
              avatarInitials: 'AD',
              rangeControl: AppSegmented<String>(
                dense: true,
                segments: const <AppSegment<String>>[
                  AppSegment<String>(value: '7', label: '7 days'),
                  AppSegment<String>(value: '30', label: '30 days'),
                  AppSegment<String>(value: '90', label: '90 days'),
                ],
                selected: _range,
                onChanged: (String v) => setState(() => _range = v),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'AppBottomNav: reporter, with unread badge and dot',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppBottomNav(
                  destinations: <AppNavDestination>[
                    reporter[0],
                    reporter[1],
                    reporter[2],
                    reporter[3].withBadge(count: 120),
                  ],
                  selectedIndex: _bottom,
                  onSelected: (int i) => setState(() => _bottom = i),
                ),
              ),
            ),
            GalleryLabel(
              'AppBottomNav: maintenance (3 items, dot)',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppBottomNav(
                  destinations: <AppNavDestination>[
                    ...AppBottomNav.destinationsFor(
                      UserRole.maintenance,
                    ).take(2),
                    AppBottomNav.destinationsFor(
                      UserRole.maintenance,
                    )[2].withBadge(dot: true),
                  ],
                  selectedIndex: 0,
                  onSelected: (int i) {},
                ),
              ),
            ),
            GalleryLabel(
              'AppBottomNav: verifier',
              width: GalleryPhone.width,
              child: GalleryPhone(
                padding: false,
                child: AppBottomNav(
                  destinations: AppBottomNav.destinationsFor(UserRole.verifier),
                  selectedIndex: 1,
                  onSelected: (int i) {},
                ),
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'AdminSideNav expanded (240)',
              child: SizedBox(
                height: 360,
                child: AdminSideNav(
                  selectedIndex: _side,
                  onSelected: (int i) => setState(() => _side = i),
                  role: UserRole.admin,
                  avatarInitials: 'AD',
                ),
              ),
            ),
            GalleryLabel(
              'AdminSideNav rail (72)',
              child: SizedBox(
                height: 360,
                child: AdminSideNav(
                  rail: true,
                  selectedIndex: _side,
                  onSelected: (int i) => setState(() => _side = i),
                  role: UserRole.admin,
                  avatarInitials: 'AD',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 8.20 to 8.24: dialogs, sheets, toasts, banners and skeletons.
class FeedbackSection extends StatelessWidget {
  /// Creates the section.
  const FeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      id: '8.20-8.24',
      title: 'Dialog, BottomSheet, Toast, InlineBanner, PrivacyNote, Skeleton',
      description:
          'Dialog titles are questions or actions and the destructive button '
          'repeats the verb. Toasts last 4 s (6 s with an action); errors '
          'persist until dismissed.',
      children: <Widget>[
        GalleryLabel(
          'Overlays (tap to open)',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              AppButton(
                label: 'Confirm dialog',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppDialog.confirm(
                  context: context,
                  title: 'Discard this report?',
                  message: 'Your answers so far will not be saved.',
                  confirmLabel: 'Discard',
                  cancelLabel: 'Keep editing',
                  destructive: true,
                ),
              ),
              AppButton(
                label: 'Dialog with required note',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppDialog.confirmWithNote(
                  context: context,
                  title: 'Reject and request rework?',
                  message: 'The maintenance team will see your note.',
                  noteLabel: 'What still needs fixing?',
                  confirmLabel: 'Reject',
                  destructive: true,
                ),
              ),
              AppButton(
                label: 'Option sheet',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppBottomSheet.showOptions<String>(
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
                      icon: Icons.image_outlined,
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Toast',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppToast.show(context, 'Copied CF-2026-00042'),
              ),
              AppButton(
                label: 'Toast, success with action',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppToast.show(
                  context,
                  'Sent for verification',
                  kind: AppToastKind.success,
                  actionLabel: 'Undo',
                  onAction: () {},
                ),
              ),
              AppButton(
                label: 'Toast, error (persists)',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppToast.show(
                  context,
                  'Could not send. Check your connection.',
                  kind: AppToastKind.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GalleryLabel(
          'AppDialog surface (static preview)',
          child: SizedBox(
            width: 420,
            child: AppDialog(
              title: 'Mark as resolved?',
              message: 'The verifier will review your after photos.',
              actions: <Widget>[
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.tertiary,
                  onPressed: () {},
                ),
                AppButton(label: 'Mark as resolved', onPressed: () {}),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GalleryLabel(
          'AppSheetBody (static preview)',
          child: SizedBox(
            width: GalleryPhone.width,
            child: GalleryPhone(
              padding: false,
              child: AppSheetBody(
                title: 'Add a photo',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppSheetRow(
                      label: 'Take a photo',
                      icon: Icons.photo_camera_outlined,
                      onTap: () {},
                    ),
                    AppSheetRow(
                      label: 'Choose from gallery',
                      icon: Icons.image_outlined,
                      selected: true,
                      onTap: () {},
                    ),
                    AppSheetRow(
                      label: 'Remove photo',
                      icon: Icons.delete_outline,
                      destructive: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GalleryWrap(
          children: <Widget>[
            for (final FeedbackKind kind in FeedbackKind.values)
              GalleryLabel(
                'InlineBanner: ${kind.name}',
                width: 400,
                child: InlineBanner(
                  kind: kind,
                  title: switch (kind) {
                    FeedbackKind.success => 'Sent for verification',
                    FeedbackKind.warning => 'This complaint changed',
                    FeedbackKind.error => "Couldn't load complaints",
                    FeedbackKind.info => 'This complaint is closed',
                  },
                  message: switch (kind) {
                    FeedbackKind.success =>
                      'The verifier has been notified of your after photos.',
                    FeedbackKind.warning =>
                      'Refresh to see the latest status before you continue.',
                    FeedbackKind.error =>
                      'Check your connection and try again.',
                    FeedbackKind.info =>
                      'No further changes can be made to it.',
                  },
                  actionLabel: kind == FeedbackKind.error ? 'Retry' : null,
                  onAction: kind == FeedbackKind.error ? () {} : null,
                ),
              ),
          ],
        ),
        GalleryWrap(
          children: const <Widget>[
            GalleryLabel(
              'PrivacyNote (M-07)',
              width: 400,
              child: PrivacyNote.identity(),
            ),
            GalleryLabel(
              'PrivacyNote (M-05)',
              width: 400,
              child: PrivacyNote.photos(),
            ),
          ],
        ),
        GalleryLabel(
          'Skeleton blocks (shimmer 1400 ms; static with reduced motion)',
          width: 400,
          child: const Skeleton(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBlock(height: 20),
                SizedBox(height: AppSpace.s2),
                SkeletonBlock.fraction(widthFactor: 0.7, height: 16),
                SizedBox(height: AppSpace.s2),
                SkeletonBlock(width: 80, height: 80, radius: AppRadius.br4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const GalleryLabel(
          'UserAvatar',
          child: UserAvatar(initials: 'CU', semanticLabel: 'Signed-in user'),
        ),
      ],
    );
  }
}
