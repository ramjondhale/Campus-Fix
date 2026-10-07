import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';

/// The "Report a Problem" floating button of My Complaints (M-09) and the
/// Campus Board (M-11): starts the report flow at the category step. It shows
/// only to a role that may open the flow (the route policy: reporters), and
/// nothing for any other role.
///
/// Use it as a `Scaffold.floatingActionButton`.
class ReportProblemFab extends ConsumerWidget {
  const ReportProblemFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null || !roleMayOpen(user.role, AppRoutes.reportCategory)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      heroTag: 'report-problem-fab',
      onPressed: () => context.push(AppRoutes.reportCategory),
      icon: const Icon(Icons.add),
      label: const Text('Report a Problem'),
    );
  }
}
