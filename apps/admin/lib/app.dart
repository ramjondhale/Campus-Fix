import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

/// Disables Riverpod's automatic provider retry: a failed load must show its
/// error with a user-driven **Retry** (screens-spec G-4), not silently loop.
Duration? noAutoRetry(int retryCount, Object error) => null;

/// The CampusFix admin web console: a themed `MaterialApp.router` driven by
/// the session-aware router. The design system supplies both themes; the
/// platform brightness picks between them. Desktop-first (the shell collapses
/// below 1024 px, see `AdminShell`).
class CampusFixAdminApp extends ConsumerWidget {
  const CampusFixAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CampusFix Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
