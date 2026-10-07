import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';

/// The "Report a Problem" floating button of My Complaints (M-09) and the
/// Campus Board (M-11): starts the report flow at the category step. Only a
/// reporter can file a report, so it shows nothing for any other role.
///
/// Use it as a `Scaffold.floatingActionButton`.
class ReportProblemFab extends ConsumerWidget {
  const ReportProblemFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider);
    if (user?.role != UserRole.reporter) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      heroTag: 'report-problem-fab',
      onPressed: () => context.push(AppRoutes.reportCategory),
      icon: const Icon(Icons.add),
      label: const Text('Report a Problem'),
    );
  }
}
