import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'report_flow.dart';

/// Where a photo comes from. The prototype has no camera or gallery: both
/// pick a bundled sample (assumption A4).
enum _PhotoSource { camera, gallery }

/// M-05 Report: Photo Upload (step 3 of 5). One to five before-repair photos,
/// shown with the drawn placeholder; an optional public caption each.
class PhotosStep extends ConsumerStatefulWidget {
  const PhotosStep({super.key, this.edit = false});

  final bool edit;

  @override
  ConsumerState<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<PhotosStep> {
  String? _selectedId;

  Future<void> _add() async {
    final _PhotoSource? source = await AppBottomSheet.showOptions<_PhotoSource>(
      context: context,
      title: 'Add a photo',
      options: const <AppSheetOption<_PhotoSource>>[
        AppSheetOption<_PhotoSource>(
          value: _PhotoSource.camera,
          label: 'Take a photo (sample)',
          icon: Icons.photo_camera_outlined,
        ),
        AppSheetOption<_PhotoSource>(
          value: _PhotoSource.gallery,
          label: 'Choose from gallery (sample)',
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    if (source == null) return;
    ref.read(reportDraftProvider.notifier).addPhoto();
  }

  @override
  Widget build(BuildContext context) {
    final ReportDraft draft = ref.watch(reportDraftProvider);
    final ReportDraftNotifier notifier = ref.read(reportDraftProvider.notifier);
    final bool selectedExists = draft.photos.any((a) => a.id == _selectedId);

    return ReportStepScaffold(
      step: 3,
      stepLabel: 'Photos',
      edit: widget.edit,
      primaryLabel: widget.edit ? 'Done' : 'Next',
      onPrimary: draft.photosValid
          ? () => continueFrom(
              context,
              edit: widget.edit,
              next: AppRoutes.reportDetails,
            )
          : null,
      children: <Widget>[
        const StepHeading(
          title: 'Add photos of the problem',
          subtitle:
              'Before-repair evidence helps maintenance. '
              'Add 1 to ${ReportLimits.maxPhotos} photos.',
        ),
        PhotoUploader(
          category: draft.category ?? ProblemCategory.other,
          maxPhotos: ReportLimits.maxPhotos,
          items: <PhotoUploadItem>[
            for (final Attachment a in draft.photos)
              PhotoUploadItem(attachment: a, caption: a.caption),
          ],
          onAdd: _add,
          onRemove: (PhotoUploadItem item) =>
              notifier.removePhoto(item.attachment.id),
          onSelect: (PhotoUploadItem item) =>
              setState(() => _selectedId = item.attachment.id),
          selectedId: selectedExists ? _selectedId : null,
          onCaptionChanged: notifier.setCaption,
        ),
        if (!draft.photosValid) ...<Widget>[
          const SizedBox(height: AppSpace.s3),
          Text(
            'Add at least ${ReportLimits.minPhotos} photo to continue.',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s2),
        Text(
          'Captions are public. Tap a photo to add one.',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
