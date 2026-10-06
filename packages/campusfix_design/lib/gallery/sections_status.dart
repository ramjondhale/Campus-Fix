import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/tokens/spacing_tokens.dart';
import '../widgets/app_tag_size.dart';
import '../widgets/category_chip.dart';
import '../widgets/complaint_id_text.dart';
import '../widgets/priority_tag.dart';
import '../widgets/status_badge.dart';
import '../widgets/timeline.dart';
import '../widgets/user_avatar.dart';
import 'gallery_fixtures.dart';
import 'gallery_parts.dart';

/// 8.7 to 8.9: StatusBadge, PriorityTag, CategoryChip and ComplaintId.
class IndicatorsSection extends StatelessWidget {
  /// Creates the section.
  const IndicatorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      id: '8.7-8.9',
      title: 'StatusBadge, PriorityTag, CategoryChip, ComplaintId',
      description:
          'Shape encodes the dimension (status pill with ring, priority '
          'rectangle with signal bars, category rounded square); colour '
          'encodes the value. Text always names the state. Critical and '
          'Closed are the two solid sets.',
      children: <Widget>[
        GalleryLabel(
          'StatusBadge md: all 7 statuses',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ComplaintStatus s in ComplaintStatus.values)
                StatusBadge(status: s),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GalleryLabel(
          'StatusBadge sm',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ComplaintStatus s in ComplaintStatus.values)
                StatusBadge(status: s, size: AppTagSize.sm),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'PriorityTag md: all 4',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final Priority p in Priority.values)
                    PriorityTag(priority: p),
                ],
              ),
            ),
            GalleryLabel(
              'PriorityTag sm',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final Priority p in Priority.values)
                    PriorityTag(priority: p, size: AppTagSize.sm),
                ],
              ),
            ),
            const GalleryLabel(
              'With the Overridden marker (admin detail only)',
              child: PriorityTag(priority: Priority.high, overridden: true),
            ),
          ],
        ),
        GalleryLabel(
          'CategoryChip: all 8 at 24, 32, 40 and 48',
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final ProblemCategory c in ProblemCategory.values)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final CategoryChipSize size in CategoryChipSize.values)
                      CategoryChip(category: c, size: size),
                    Text(c.label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GalleryWrap(
          children: <Widget>[
            const GalleryLabel(
              'ComplaintId sm (cards and rows)',
              child: ComplaintIdText(id: 'CF-2026-00042'),
            ),
            const GalleryLabel(
              'ComplaintId md (tap to copy)',
              child: ComplaintIdText(
                id: 'CF-2026-00042',
                size: ComplaintIdSize.md,
              ),
            ),
            const GalleryLabel(
              'ComplaintId lg (confirmation, tap to copy)',
              child: ComplaintIdText(
                id: 'CF-2026-00042',
                size: ComplaintIdSize.lg,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 8.14 and 8.23: StatusStepper, timeline, avatar and role pills.
class TimelineSection extends StatelessWidget {
  /// Creates the section.
  const TimelineSection({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = GalleryFixtures.now;
    return GallerySection(
      id: '8.14, 8.23',
      title: 'StatusStepper, Timeline, Avatar, RolePill',
      description:
          'The timeline shows roles only (RolePill), never a name or id. '
          'Rework (T7) is a marker, not an eighth status.',
      children: <Widget>[
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'StatusStepper compact: each status',
              width: GalleryPhone.width,
              child: Column(
                children: <Widget>[
                  for (final ComplaintStatus s in <ComplaintStatus>[
                    ComplaintStatus.reported,
                    ComplaintStatus.inProgress,
                    ComplaintStatus.closed,
                  ]) ...<Widget>[
                    StatusStepper(status: s),
                    const SizedBox(height: AppSpace.s4),
                  ],
                  const StatusStepper(
                    status: ComplaintStatus.inProgress,
                    hasRework: true,
                  ),
                ],
              ),
            ),
            GalleryLabel(
              'StatusStepper full (admin and tablets, min 560)',
              width: 640,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  StatusStepper(
                    status: ComplaintStatus.assigned,
                    variant: StatusStepperVariant.full,
                  ),
                  SizedBox(height: AppSpace.s6),
                  StatusStepper(
                    status: ComplaintStatus.inProgress,
                    variant: StatusStepperVariant.full,
                    hasRework: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'ComplaintTimeline (public form, with a T7 rework)',
              width: 440,
              child: GalleryPanel(
                child: ComplaintTimeline(
                  events: GalleryFixtures.civilRework.timeline,
                  now: now,
                ),
              ),
            ),
            GalleryLabel(
              'TimelineItem, admin form (A-04 only)',
              width: 440,
              child: GalleryPanel(
                child: TimelineItem(
                  status: ComplaintStatus.assigned,
                  actorRole: UserRole.admin,
                  at: now.subtract(const Duration(hours: 4)),
                  note: 'Routed to the electrician team.',
                  adminActorLine: 'actor-001 · Sample Admin',
                  isLast: true,
                  isCurrent: true,
                  now: now,
                ),
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'RolePill: all 4 roles',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final UserRole role in UserRole.values)
                    RolePill(role: role),
                ],
              ),
            ),
            const GalleryLabel(
              'UserAvatar 24 / 32 / 40 (signed-in user and admin panels only)',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  UserAvatar(initials: 'AB', size: UserAvatarSize.s24),
                  SizedBox(width: 8),
                  UserAvatar(initials: 'AB'),
                  SizedBox(width: 8),
                  UserAvatar(initials: 'AB', size: UserAvatarSize.s40),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
