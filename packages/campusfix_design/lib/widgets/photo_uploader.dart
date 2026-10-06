import 'dart:ui' as ui;

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'complaint_photo.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// Upload state of one [PhotoUploadItem] (contract 8.12 tile states).
enum PhotoUploadStatus {
  /// Ready: shows the thumbnail.
  ready,

  /// Uploading: black overlay, upload icon and a 4 px progress bar.
  uploading,

  /// Failed: error outline, overlay, "Upload failed" and a Retry button.
  failed,
}

/// One photo in a [PhotoUploader].
@immutable
class PhotoUploadItem {
  /// Creates an item.
  const PhotoUploadItem({
    required this.attachment,
    this.status = PhotoUploadStatus.ready,
    this.progress = 0,
    this.caption,
  });

  /// The attachment (public type; the placeholder derives from its ref).
  final Attachment attachment;

  /// Upload state.
  final PhotoUploadStatus status;

  /// Upload progress from 0 to 1 while [status] is uploading.
  final double progress;

  /// Optional caption (80 characters).
  final String? caption;
}

/// The photo upload control (contract 8.12): "n of 5" counter, a grid of
/// square tiles (minimum 100, three per row on a 360 phone, gap 8), a dashed
/// add tile, a remove button on each tile and a caption field under the
/// selected tile.
///
/// The control is presentational: it reports [onAdd], [onRemove], [onRetry],
/// [onSelect] and [onCaptionChanged]; picking images is mocked by the host
/// app (A4). Reaching [maxPhotos] hides the add tile and shows "Maximum 5
/// photos". Items render as [ComplaintPhoto] placeholders tinted by
/// [category].
class PhotoUploader extends StatelessWidget {
  /// Creates an uploader.
  const PhotoUploader({
    super.key,
    required this.items,
    required this.category,
    required this.onAdd,
    this.onRemove,
    this.onRetry,
    this.onSelect,
    this.onCaptionChanged,
    this.selectedId,
    this.maxPhotos = AppLayout.maxPhotos,
    this.helperText = defaultHelper,
  });

  /// "Avoid including people's faces or documents."
  static const String defaultHelper =
      "Avoid including people's faces or documents.";

  /// The photos, in order.
  final List<PhotoUploadItem> items;

  /// Category used to tint the placeholders.
  final ProblemCategory category;

  /// Called when the add tile is tapped.
  final VoidCallback? onAdd;

  /// Called with the item to remove.
  final ValueChanged<PhotoUploadItem>? onRemove;

  /// Called with a failed item to retry.
  final ValueChanged<PhotoUploadItem>? onRetry;

  /// Called with the tapped item.
  final ValueChanged<PhotoUploadItem>? onSelect;

  /// Called with the attachment id and the new caption.
  final void Function(String attachmentId, String caption)? onCaptionChanged;

  /// Id of the selected attachment (shows its caption field).
  final String? selectedId;

  /// Maximum number of photos (5).
  final int maxPhotos;

  /// Helper under the control; null hides it.
  final String? helperText;

  static const double _gap = AppSpace.s2;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool reachedMax = items.length >= maxPhotos;
    PhotoUploadItem? selected;
    for (final PhotoUploadItem item in items) {
      if (item.attachment.id == selectedId) selected = item;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: Text(
            '${items.length} of $maxPhotos',
            style: context.textTheme.labelMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (items.isEmpty)
          _AddTile(onTap: onAdd, empty: true)
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final int columns =
                  ((width + _gap) / (AppLayout.photoTile + _gap)).floor().clamp(
                    1,
                    8,
                  );
              final double edge = (width - _gap * (columns - 1)) / columns;
              return Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: <Widget>[
                  for (final PhotoUploadItem item in items)
                    SizedBox.square(
                      dimension: edge,
                      child: _UploadTile(
                        item: item,
                        category: category,
                        selected: item.attachment.id == selectedId,
                        onSelect: onSelect == null
                            ? null
                            : () => onSelect!(item),
                        onRemove: onRemove == null
                            ? null
                            : () => onRemove!(item),
                        onRetry: onRetry == null ? null : () => onRetry!(item),
                      ),
                    ),
                  if (!reachedMax)
                    SizedBox.square(
                      dimension: edge,
                      child: _AddTile(onTap: onAdd),
                    ),
                ],
              );
            },
          ),
        if (selected != null && onCaptionChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s3),
            child: _CaptionField(
              key: ValueKey<String>(selected.attachment.id),
              initial: selected.caption ?? '',
              onChanged: (String v) =>
                  onCaptionChanged!(selected!.attachment.id, v),
            ),
          ),
        if (reachedMax || helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: Text(
              reachedMax ? 'Maximum $maxPhotos photos' : helperText!,
              style: context.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (reachedMax && helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              helperText!,
              style: context.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _CaptionField extends StatefulWidget {
  const _CaptionField({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_CaptionField> createState() => _CaptionFieldState();
}

class _CaptionFieldState extends State<_CaptionField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Caption (optional)',
      controller: _controller,
      maxLength: 80,
      onChanged: widget.onChanged,
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, this.empty = false});

  final VoidCallback? onTap;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return AppPressable(
      onTap: onTap,
      semanticLabel: empty ? 'Add a photo' : 'Add photo',
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color fill = applyStateLayer(
          empty ? colors.cardSubtle : Colors.transparent,
          scheme.primary,
          states,
          hover: 0.06,
        );
        return CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: states.contains(WidgetState.disabled)
                ? scheme.outlineVariant
                : scheme.outline,
            radius: AppRadius.r4,
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: empty ? 152 : 0),
            width: double.infinity,
            height: empty ? null : double.infinity,
            decoration: BoxDecoration(color: fill, borderRadius: AppRadius.br4),
            alignment: Alignment.center,
            child: empty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 32,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        'Add a photo',
                        style: context.textTheme.labelMedium!.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, size: 20, color: scheme.primary),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        'Add photo',
                        style: context.textTheme.labelMedium!.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _stroke = 1.5;
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(_stroke / 2),
          Radius.circular(radius),
        ),
      );
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.item,
    required this.category,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    required this.onRetry,
  });

  final PhotoUploadItem item;
  final ProblemCategory category;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool failed = item.status == PhotoUploadStatus.failed;
    final bool uploading = item.status == PhotoUploadStatus.uploading;
    final String? kind = PhotoThumbnail.kindLabelFor(item.attachment.kind);

    final Widget square = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.br4,
          child: ComplaintPhoto(
            category: category,
            attachment: item.attachment,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.br4,
            border: Border.all(
              color: failed
                  ? scheme.error
                  : (selected ? scheme.primary : scheme.outlineVariant),
              width: selected && !failed ? 2 : 1,
            ),
          ),
        ),
        if (uploading) _UploadingOverlay(progress: item.progress),
        if (failed) _FailedOverlay(onRetry: onRetry),
        if (kind != null && !failed)
          Positioned(
            left: 4,
            bottom: uploading ? 10 : 4,
            child: PhotoKindLabel(label: kind),
          ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 0,
            child: PhotoRemoveButton(onTap: onRemove!),
          ),
      ],
    );

    final String statusText = switch (item.status) {
      PhotoUploadStatus.ready => 'ready',
      PhotoUploadStatus.uploading => 'uploading',
      PhotoUploadStatus.failed => 'upload failed',
    };
    final String label =
        '${item.attachment.kind.label}, $statusText'
        '${item.caption == null ? '' : ', ${item.caption}'}';
    if (onSelect == null) {
      return Semantics(label: label, image: true, child: square);
    }
    return AppPressable(
      onTap: onSelect,
      selected: selected,
      semanticLabel: label,
      builder: (BuildContext context, Set<WidgetState> states) => square,
    );
  }
}

/// Uploading state: black 62% overlay, upload icon and a 4 px progress bar.
class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    return ClipRRect(
      borderRadius: AppRadius.br4,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
            color: colors.photoOverlayBackground.withValues(alpha: 0.62),
          ),
          Center(
            child: Icon(
              Icons.upload_outlined,
              size: 24,
              color: colors.photoOverlayForeground,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 4,
              color: colors.photoOverlayForeground,
              backgroundColor: colors.photoOverlayForeground.withValues(
                alpha: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Failed state: inset 1 px error outline, deep red overlay, "Upload failed"
/// and a small Retry button.
class _FailedOverlay extends StatelessWidget {
  const _FailedOverlay({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.92),
          borderRadius: AppRadius.br3,
          border: Border.all(color: scheme.error),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Upload failed',
                textAlign: TextAlign.center,
                style: context.textTheme.labelSmall!.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              if (onRetry != null)
                AppButton(
                  label: 'Retry',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.tertiary,
                  onPressed: onRetry,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
