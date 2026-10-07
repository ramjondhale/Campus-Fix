// Small building blocks shared by the panels of A-04: a label / value fact, a
// label chip, the loading skeleton, the photo viewer and the photo gallery.
// Everything is styled through the design system's tokens and widgets.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// A label above a value, the way every panel lists its facts. [value] is
/// plain text; pass [child] for a widget (a tag, a chip).
class DetailFact extends StatelessWidget {
  const DetailFact({super.key, required this.label, this.value, this.child})
    : assert(
        (value == null) != (child == null),
        'Give either a value or a child',
      );

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          child ?? Text(value!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A small neutral label chip (e.g. "Auto" / "Manual"), made of the theme's
/// `secondaryContainer` pair and the `r2` radius.
class DetailLabelChip extends StatelessWidget {
  const DetailLabelChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpace.s1,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.br2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: AppIconSize.s16,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpace.s1),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall!.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card of body content (the panels that are not dashboard panels).
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CampusColors colors = context.campusColors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.br4,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpace.s3),
          child,
        ],
      ),
    );
  }
}

/// The loading placeholder of A-04: a header block, an action strip and the
/// two columns of cards.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SkeletonBlock.fraction(widthFactor: 0.3, height: AppSpace.s6),
          SizedBox(height: AppSpace.s3),
          SkeletonBlock.fraction(widthFactor: 0.6, height: AppSpace.s5),
          SizedBox(height: AppSpace.s6),
          SkeletonBlock(height: AppSpace.s12, radius: AppRadius.br4),
          SizedBox(height: AppSpace.s4),
          SkeletonBlock(height: AppSpace.s16 * 2, radius: AppRadius.br4),
          SizedBox(height: AppSpace.s4),
          SkeletonBlock(height: AppSpace.s16 * 3, radius: AppRadius.br4),
        ],
      ),
    );
  }
}

/// Opens [attachment] large, with pinch-to-zoom (the photo viewer of A-04).
Future<void> showDetailPhotoViewer(
  BuildContext context, {
  required ProblemCategory category,
  required Attachment attachment,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final CampusColors colors = dialogContext.campusColors;
      return Dialog.fullscreen(
        backgroundColor: colors.photoOverlayBackground,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Semantics(
                      label: 'Photo of a ${category.label} problem',
                      child: ComplaintPhoto(
                        category: category,
                        attachment: attachment,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close photo',
                  color: colors.photoOverlayForeground,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The before photos, the after photos and, when both exist, the
/// [BeforeAfter] comparator (screens-spec A-04).
class DetailPhotos extends StatelessWidget {
  const DetailPhotos({super.key, required this.complaint});

  final PublicComplaintView complaint;

  @override
  Widget build(BuildContext context) {
    final PublicComplaintView c = complaint;
    final bool hasBefore = c.beforePhotos.isNotEmpty;
    final bool hasAfter = c.afterPhotos.isNotEmpty;
    return DetailSection(
      title: 'Photos',
      child: !hasBefore && !hasAfter
          ? Text(
              'No photos were attached.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (hasBefore && hasAfter) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: BeforeAfter.maxWidth,
                      ),
                      child: BeforeAfter(
                        category: c.category,
                        before: c.beforePhotos.first,
                        after: c.afterPhotos,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                ],
                if (hasBefore)
                  _Gallery(
                    label: 'Before',
                    category: c.category,
                    photos: c.beforePhotos,
                  ),
                if (hasAfter) ...<Widget>[
                  if (hasBefore) const SizedBox(height: AppSpace.s4),
                  _Gallery(
                    label: 'After repair',
                    category: c.category,
                    photos: c.afterPhotos,
                  ),
                ],
              ],
            ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.label,
    required this.category,
    required this.photos,
  });

  final String label;
  final ProblemCategory category;
  final List<Attachment> photos;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              PhotoThumbnail(
                category: category,
                attachment: photos[i],
                size: PhotoThumbnailSize.s100,
                semanticLabel:
                    '$label photo ${i + 1} of ${photos.length}. Open large',
                onTap: () => showDetailPhotoViewer(
                  context,
                  category: category,
                  attachment: photos[i],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
