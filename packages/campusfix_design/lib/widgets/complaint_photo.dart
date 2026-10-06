import 'dart:math' as math;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/icon_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';
import 'support/stable_hash.dart';

/// The drawn placeholder for a complaint photo (design decision: seed photos
/// ship no image files).
///
/// A category-tinted box (category `bg`) with a subtle pattern in the
/// category `accent` and the category icon in `fg`. The pattern variant is
/// derived deterministically from [Attachment.ref], so the same attachment
/// always looks the same. It fills the space it is given; wrap it in
/// [PhotoThumbnail] for the sized, bordered thumbnail with a kind label.
class ComplaintPhoto extends StatelessWidget {
  /// Creates a placeholder for [category]. [attachment] only seeds the
  /// pattern; without it the category name is used.
  const ComplaintPhoto({super.key, required this.category, this.attachment});

  /// The complaint category that tints the placeholder.
  final ProblemCategory category;

  /// The attachment this placeholder stands in for.
  final Attachment? attachment;

  /// The pattern variant (0 to 3) for [ref].
  static int variantFor(String ref) => stableHash(ref) % 4;

  @override
  Widget build(BuildContext context) {
    final CategoryStyle style = context.categoryStyle(category);
    final String seed = attachment?.ref ?? category.name;
    final int hash = stableHash(seed);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double shortest = math.min(
            constraints.hasBoundedWidth ? constraints.maxWidth : 100,
            constraints.hasBoundedHeight ? constraints.maxHeight : 100,
          );
          final double icon = (shortest * 0.4).clamp(
            AppIconSize.s16,
            AppIconSize.s48 * 1.5,
          );
          return CustomPaint(
            painter: _PatternPainter(
              background: style.bg,
              ink: style.accent.withValues(alpha: 0.22),
              variant: hash % 4,
              spacing: 8.0 + (hash >> 4) % 4 * 2,
            ),
            child: Center(
              child: Icon(
                AppCategoryIcons.of(category),
                size: icon,
                color: style.fg,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.background,
    required this.ink,
    required this.variant,
    required this.spacing,
  });

  final Color background;
  final Color ink;
  final int variant;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final Paint paint = Paint()
      ..color = ink
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final double reach = size.width + size.height;
    switch (variant) {
      case 0: // diagonal, rising
        for (double d = -size.height; d < size.width; d += spacing) {
          canvas.drawLine(
            Offset(d, size.height),
            Offset(d + size.height, 0),
            paint,
          );
        }
      case 1: // diagonal, falling
        for (double d = -size.height; d < size.width; d += spacing) {
          canvas.drawLine(
            Offset(d, 0),
            Offset(d + size.height, size.height),
            paint,
          );
        }
      case 2: // horizontal lines
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(reach, y), paint);
        }
      default: // dot grid
        final Paint dots = Paint()..color = ink;
        for (double y = spacing / 2; y < size.height; y += spacing) {
          for (double x = spacing / 2; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.5, dots);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.background != background ||
      old.ink != ink ||
      old.variant != variant ||
      old.spacing != spacing;
}

/// Edge of a [PhotoThumbnail] (contract 8.12).
enum PhotoThumbnailSize {
  /// 56 x 56 (verify card).
  s56(56),

  /// 72 x 72 (mine and work cards).
  s72(72),

  /// 80 x 80 (board card).
  s80(80),

  /// 100 x 100 (uploader tile minimum).
  s100(100),

  /// 4:3, as wide as the parent allows (galleries).
  ratio43(null);

  const PhotoThumbnailSize(this.edge);

  /// Fixed edge, or null for the 4:3 gallery size.
  final double? edge;
}

/// A complaint photo thumbnail (contract 8.12): [ComplaintPhoto] with a
/// radius `r4`, a 1 px `outlineVariant` border, and a Before / After kind
/// label chip bottom-left (`label-sm` uppercase, white on black 82%) derived
/// from [Attachment.kind].
///
/// Optionally tappable ([onTap]), [selected] (2 px `primary` outline) and
/// removable ([onRemove], a 24 px circle in a 44 x 44 hit area top-right).
class PhotoThumbnail extends StatelessWidget {
  /// Creates a thumbnail.
  const PhotoThumbnail({
    super.key,
    required this.category,
    this.attachment,
    this.size = PhotoThumbnailSize.s72,
    this.showKindLabel = true,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.semanticLabel,
  });

  /// The complaint category that tints the placeholder.
  final ProblemCategory category;

  /// The attachment (null draws the plain category placeholder).
  final Attachment? attachment;

  /// Thumbnail size.
  final PhotoThumbnailSize size;

  /// Whether to show the Before / After label.
  final bool showKindLabel;

  /// Selected state (2 px `primary` outline).
  final bool selected;

  /// Tap callback (open viewer, swap into the comparator).
  final VoidCallback? onTap;

  /// Remove callback; adds the remove button.
  final VoidCallback? onRemove;

  /// Overrides the semantics label.
  final String? semanticLabel;

  /// The kind label text ("Before" or "After"), or null for other kinds.
  static String? kindLabelFor(AttachmentKind kind) => switch (kind) {
    AttachmentKind.beforePhoto => 'Before',
    AttachmentKind.afterPhoto => 'After',
    AttachmentKind.other => null,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final String? kind = attachment == null
        ? null
        : kindLabelFor(attachment!.kind);
    final String label =
        semanticLabel ??
        '${kind ?? 'Photo'} photo of a ${category.label} problem';

    Widget frame = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: AppRadius.br4,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.br4,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ComplaintPhoto(category: category, attachment: attachment),
            if (showKindLabel && kind != null)
              Positioned(
                left: 4,
                bottom: 4,
                child: PhotoKindLabel(label: kind),
              ),
          ],
        ),
      ),
    );

    if (size.edge != null) {
      frame = SizedBox.square(dimension: size.edge, child: frame);
    } else {
      frame = AspectRatio(aspectRatio: 4 / 3, child: frame);
    }

    if (onRemove != null) {
      frame = Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: <Widget>[
          frame,
          Positioned(
            top: 0,
            right: 0,
            child: PhotoRemoveButton(onTap: onRemove!),
          ),
        ],
      );
    }

    if (onTap == null) {
      return Semantics(label: label, image: true, child: frame);
    }
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (BuildContext context, Set<WidgetState> states) => frame,
    );
  }
}

/// The Before / After chip drawn over a photo (contract 8.12): `label-sm`
/// uppercase, white on black 82%.
class PhotoKindLabel extends StatelessWidget {
  /// Creates a label chip. [big] uses `label-md` (the BeforeAfter corner
  /// tags) instead of `label-sm`.
  const PhotoKindLabel({super.key, required this.label, this.big = false});

  /// Label text (shown upper case).
  final String label;

  /// Use `label-md` instead of `label-sm`.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colors.photoOverlayBackground,
        borderRadius: AppRadius.br2,
      ),
      child: Text(
        label.toUpperCase(),
        style:
            (big
                    ? context.textTheme.labelMedium!
                    : context.textTheme.labelSmall!)
                .copyWith(color: colors.photoOverlayForeground),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// The remove button over a photo (contract 8.12): a 24 px circle (black
/// 80%, white icon 14) inside a 44 x 44 hit area.
class PhotoRemoveButton extends StatelessWidget {
  /// Creates a remove button.
  const PhotoRemoveButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    return Tooltip(
      message: 'Remove photo',
      child: AppPressable(
        onTap: onTap,
        radius: AppRadius.brFull,
        semanticLabel: 'Remove photo',
        builder: (BuildContext context, Set<WidgetState> states) {
          return SizedBox(
            width: 44,
            height: 44,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.photoOverlayBackground.withValues(alpha: 0.8),
                ),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colors.photoOverlayForeground,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
