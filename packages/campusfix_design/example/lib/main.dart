import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// Gallery app for the `campusfix_design` package: opens
/// [WidgetGalleryScreen], which has its own light / dark toggle, under a
/// `MaterialApp` that follows the system theme with `AppTheme.light()` and
/// `AppTheme.dark()`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start loading Archivo, Public Sans and JetBrains Mono before the first
  // frame so the gallery does not flash a fallback font.
  await AppTypography.preload();
  runApp(const GalleryApp());
}

/// The example app.
class GalleryApp extends StatelessWidget {
  /// Creates the app.
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFix widget gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const WidgetGalleryScreen(),
    );
  }
}
