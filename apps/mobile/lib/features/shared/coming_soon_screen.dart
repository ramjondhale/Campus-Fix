import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';

/// Leaves the current pushed screen: back when there is a screen to go back
/// to, otherwise the role home (deep links have no history).
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// Placeholder body of a feature that a later chunk builds: the design
/// system's `EmptyState` saying "Coming soon".
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction_outlined,
    this.showBack = true,
    this.floatingActionButton,
  });

  /// The feature's screen title (top bar and message).
  final String title;

  final IconData icon;

  /// Whether the top bar shows a back arrow (pushed screens) or not (a tab of
  /// the bottom navigation).
  final bool showBack;

  /// An optional floating action (e.g. "Report a Problem").
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      appBar: AppTopBar.page(
        title: title,
        onBack: showBack ? () => popOrHome(context) : null,
      ),
      body: EmptyState(
        icon: icon,
        title: 'Coming soon',
        message: '$title arrives in a later release.',
      ),
    );
  }
}
