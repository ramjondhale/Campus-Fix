import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_tag_size.dart';
import 'category_chip.dart';
import 'complaint_id_text.dart';
import 'complaint_photo.dart';
import 'priority_tag.dart';
import 'skeleton.dart';
import 'status_badge.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';
import 'support/time_format.dart';

/// Layout variant of a [ComplaintCard] (contract 8.10).
enum ComplaintCardVariant {
  /// Campus board (M-11, M-02 highlights, M-07 duplicates): 80 x 80 first
  /// before photo, description clamped to 2 lines, submitted time.
  board,

  /// My Complaints (M-09, M-02 active): 72 x 72 photo, "Updated 3 h ago".
  mine,

  /// Assigned work (M-13): 72 x 72 photo, "Waiting 5 h".
  work,

  /// Verification queue (M-16): Before and After 56 x 56 thumbnails with
  /// kind labels, "Resolved 3 h ago".
  verify,

  /// Admin list row (A-02): one 40 high line without a thumbnail.
  row,
}

/// A complaint summary card (contract 8.10).
///
/// **Privacy:** the only data input is a [PublicComplaintView]. The
/// constructor has no reporter, assignee, actor or "mine" parameter, and no
/// way to show identity (R5).
///
/// The whole card is one focusable button. Its semantics label reads
/// "CF-2026-00042, Electrical, Critical priority, In Progress". Priority is
/// always `effectivePriority`. States: default, hover (border `outline`,
/// 3% overlay), pressed (`pressedFill`), focus ring, [selected] (2 px
/// `primary` outline and `primaryContainer` 40% tint). With no [onTap] the
/// card is static.
class ComplaintCard extends StatelessWidget {
  /// Creates a card for [complaint].
  const ComplaintCard({
    super.key,
    required this.complaint,
    this.variant = ComplaintCardVariant.board,
    this.onTap,
    this.selected = false,
    this.now,
  });

  /// The public complaint view to show.
  final PublicComplaintView complaint;

  /// Layout variant.
  final ComplaintCardVariant variant;

  /// Tap callback (open the detail screen). Null renders a static card.
  final VoidCallback? onTap;

  /// Selected state for admin multi-select contexts.
  final bool selected;

  /// The reference time for relative times; defaults to `DateTime.now()`.
  final DateTime? now;

  /// "Building · Floor · Room".
  static String locationOf(PublicComplaintView c) =>
      '${c.building} · ${c.floor} · ${c.room}';

  /// The semantics label of the whole card.
  static String semanticsOf(PublicComplaintView c) =>
      '${c.id}, ${c.category.label}, ${c.effectivePriority.label} priority, '
      '${c.status.label}';

  static bool _unresolved(ComplaintStatus s) =>
      s.order < ComplaintStatus.resolved.order;

  DateTime _resolvedAt() {
    for (final PublicStatusEvent e in complaint.timeline.reversed) {
      if (e.status == ComplaintStatus.resolved) return e.at;
    }
    return complaint.updatedAt;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime reference = now ?? DateTime.now();
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final String label = semanticsOf(complaint);

    Widget decorated(Set<WidgetState> states) {
      Color base = colors.card;
      if (selected) {
        base = Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.4),
          colors.card,
        );
      }
      if (states.contains(WidgetState.pressed)) {
        base = colors.pressedFill;
      } else {
        base = applyStateLayer(base, scheme.onSurface, states, hover: 0.03);
      }
      final bool hovered = states.contains(WidgetState.hovered);
      final double border = selected ? 2 : 1;
      final bool isRow = variant == ComplaintCardVariant.row;
      return Container(
        constraints: BoxConstraints(minHeight: isRow ? 40 : 0),
        padding: isRow
            ? const EdgeInsets.symmetric(horizontal: AppSpace.s3)
            : EdgeInsets.all(AppSpace.s3 - (border - 1)),
        decoration: BoxDecoration(
          color: base,
          borderRadius: isRow ? BorderRadius.zero : AppRadius.br4,
          border: isRow
              ? Border(bottom: BorderSide(color: scheme.outlineVariant))
              : Border.all(
                  color: selected
                      ? scheme.primary
                      : (hovered ? scheme.outline : scheme.outlineVariant),
                  width: border,
                ),
        ),
        child: isRow ? _row(context, reference) : _body(context, reference),
      );
    }

    if (onTap == null) {
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: decorated(<WidgetState>{}),
      );
    }
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      radius: variant == ComplaintCardVariant.row
          ? BorderRadius.zero
          : AppRadius.br4,
      builder: (BuildContext context, Set<WidgetState> states) =>
          decorated(states),
    );
  }

  Widget _row(BuildContext context, DateTime reference) {
    final ColorScheme scheme = context.colorScheme;
    final bool unresolved = _unresolved(complaint.status);
    final String wait = unresolved
        ? ' · ${formatWaiting(reference.difference(complaint.createdAt))}'
        : '';
    return Row(
      children: <Widget>[
        ComplaintIdText(id: complaint.id),
        const SizedBox(width: AppSpace.s2),
        CategoryChip(category: complaint.category, size: CategoryChipSize.s24),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            '${complaint.category.label} · ${complaint.building}$wait',
            style: context.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        PriorityTag(priority: complaint.effectivePriority, size: AppTagSize.sm),
      ],
    );
  }

  Widget _body(BuildContext context, DateTime reference) {
    final ColorScheme scheme = context.colorScheme;
    final TextTheme text = context.textTheme;
    final TextStyle meta = text.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final bool verify = variant == ComplaintCardVariant.verify;

    final String timeText = switch (variant) {
      ComplaintCardVariant.board => formatRelativeTime(
        complaint.createdAt,
        now: reference,
      ),
      ComplaintCardVariant.mine =>
        'Updated ${formatRelativeTime(complaint.updatedAt, now: reference)}',
      ComplaintCardVariant.work =>
        _unresolved(complaint.status)
            ? 'Waiting ${formatWaiting(reference.difference(complaint.createdAt))}'
            : 'Updated ${formatRelativeTime(complaint.updatedAt, now: reference)}',
      ComplaintCardVariant.verify =>
        'Resolved ${formatRelativeTime(_resolvedAt(), now: reference)}',
      ComplaintCardVariant.row => '',
    };

    final Widget thumbnail = switch (variant) {
      ComplaintCardVariant.board => PhotoThumbnail(
        category: complaint.category,
        attachment: complaint.beforePhotos.isEmpty
            ? null
            : complaint.beforePhotos.first,
        size: PhotoThumbnailSize.s80,
        showKindLabel: false,
      ),
      ComplaintCardVariant.mine || ComplaintCardVariant.work => PhotoThumbnail(
        category: complaint.category,
        attachment: complaint.beforePhotos.isEmpty
            ? null
            : complaint.beforePhotos.first,
        size: PhotoThumbnailSize.s72,
        showKindLabel: false,
      ),
      _ => const SizedBox.shrink(),
    };

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Full width so `spaceBetween` pins the priority tag to the right.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: <Widget>[
              ComplaintIdText(id: complaint.id),
              PriorityTag(priority: complaint.effectivePriority),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            CategoryChip(
              category: complaint.category,
              size: CategoryChipSize.s24,
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                complaint.category.label,
                style: text.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.place_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpace.s1),
            Expanded(
              child: Text(
                locationOf(complaint),
                style: meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (variant == ComplaintCardVariant.board) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            complaint.description,
            style: text.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (verify) ...<Widget>[
          const SizedBox(height: AppSpace.s2),
          Row(
            children: <Widget>[
              PhotoThumbnail(
                category: complaint.category,
                attachment: complaint.beforePhotos.isEmpty
                    ? null
                    : complaint.beforePhotos.first,
                size: PhotoThumbnailSize.s56,
              ),
              const SizedBox(width: AppSpace.s2),
              PhotoThumbnail(
                category: complaint.category,
                attachment: complaint.afterPhotos.isEmpty
                    ? null
                    : complaint.afterPhotos.first,
                size: PhotoThumbnailSize.s56,
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s1,
            children: <Widget>[
              StatusBadge(
                status: complaint.status,
                size: verify ? AppTagSize.sm : AppTagSize.md,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpace.s1),
                  Text(
                    timeText,
                    style: meta.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (verify) return details;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        thumbnail,
        const SizedBox(width: AppSpace.s3),
        Expanded(child: details),
      ],
    );
  }
}

/// The loading skeleton of a [ComplaintCard] (contract 8.10, G-3): the same
/// container with shimmering bars mirroring the layout.
class ComplaintCardSkeleton extends StatelessWidget {
  /// Creates a skeleton for [variant].
  const ComplaintCardSkeleton({
    super.key,
    this.variant = ComplaintCardVariant.board,
  });

  /// The variant whose layout is mirrored.
  final ComplaintCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool isRow = variant == ComplaintCardVariant.row;
    final bool verify = variant == ComplaintCardVariant.verify;
    final double? thumb = switch (variant) {
      ComplaintCardVariant.board => 80,
      ComplaintCardVariant.mine || ComplaintCardVariant.work => 72,
      _ => null,
    };
    final Widget lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SkeletonBlock.fraction(widthFactor: 0.9, height: 16),
        const SizedBox(height: 8),
        const SkeletonBlock.fraction(widthFactor: 0.6, height: 16),
        const SizedBox(height: 8),
        const SkeletonBlock.fraction(widthFactor: 0.8, height: 12),
        if (variant == ComplaintCardVariant.board) ...<Widget>[
          const SizedBox(height: 8),
          const SkeletonBlock(height: 12),
        ],
        if (verify) ...<Widget>[
          const SizedBox(height: 8),
          const Row(
            children: <Widget>[
              SkeletonBlock(width: 56, height: 56, radius: AppRadius.br4),
              SizedBox(width: 8),
              SkeletonBlock(width: 56, height: 56, radius: AppRadius.br4),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const SkeletonBlock.fraction(widthFactor: 0.5, height: 20),
      ],
    );
    return Skeleton(
      child: Container(
        padding: EdgeInsets.all(isRow ? AppSpace.s2 : AppSpace.s3),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: AppRadius.br4,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: isRow
            ? const SkeletonBlock(height: 24)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (thumb != null) ...<Widget>[
                    SkeletonBlock(
                      width: thumb,
                      height: thumb,
                      radius: AppRadius.br4,
                    ),
                    const SizedBox(width: AppSpace.s3),
                  ],
                  Expanded(child: lines),
                ],
              ),
      ),
    );
  }
}
