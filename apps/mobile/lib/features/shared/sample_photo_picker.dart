import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// Where a photo comes from. The prototype has no camera or gallery: both
/// pick a bundled sample (assumption A4).
enum _PhotoSource { camera, gallery }

/// Asks where a photo should come from (camera or gallery, both mocked) and
/// returns whether the user chose one. The caller then adds the sample photo to
/// its own draft: the Report flow's before-photos (M-05) and the maintenance
/// after-repair photos (M-15) share this sheet.
Future<bool> pickSamplePhoto(BuildContext context) async {
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
  return source != null;
}
