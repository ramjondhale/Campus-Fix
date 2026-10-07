import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

/// Disables Riverpod's automatic provider retry: a failed load must show its
/// error with a user-driven **Retry** (screens-spec G-4), not silently loop.
Duration? noAutoRetry(int retryCount, Object error) => null;

/// The CampusFix mobile app: themed `MaterialApp.router` driven by the
/// session-aware router. The design system supplies both themes; the platform
/// brightness picks between them.
class CampusFixApp extends ConsumerWidget {
  const CampusFixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CampusFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
