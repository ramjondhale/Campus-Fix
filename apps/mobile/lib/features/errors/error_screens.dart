import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';

/// E-403: a signed-in role opened a screen it is not listed for
/// (screens-spec G-2).
class NotAuthorizedScreen extends StatelessWidget {
  const NotAuthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: "You don't have access to this page",
          message: 'Your role cannot open this screen.',
          actionLabel: 'Go home',
          onAction: () => context.go(AppRoutes.home),
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
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Page not found',
          message: "This page doesn't exist or isn't available to you.",
          actionLabel: 'Go home',
          onAction: () => context.go(AppRoutes.home),
        ),
      ),
    );
  }
}
