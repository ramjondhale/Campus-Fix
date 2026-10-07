import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';

/// E-403: a signed-in role the console has no screens for (reporter,
/// maintenance) signed in or opened a console route (screens-spec G-2, AC-45).
/// The only way forward is **Sign out**: nothing of the console is shown.
class NotAuthorizedScreen extends ConsumerWidget {
  const NotAuthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState.forbidden(
          message:
              'The admin console is for admins and verifiers. Sign out and '
              'use an account that can open it.',
          actionLabel: 'Sign out',
          onAction: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ),
    );
  }
}

/// E-404: an unknown route. Never reveals whether something exists but is not
/// permitted (screens-spec G-6).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState.notFound(
          title: 'Page not found',
          message: "This page doesn't exist or isn't available to you.",
          actionLabel: 'Go to dashboard',
          onAction: () => context.go(AppRoutes.dashboard),
        ),
      ),
    );
  }
}
