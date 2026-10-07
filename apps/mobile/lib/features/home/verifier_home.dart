import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'home_widgets.dart';

/// Verifier Home (M-02): the count of complaints awaiting verification
/// (`status == resolved`), "Open verification queue" and a shortcut to the
/// board.
class VerifierHome extends ConsumerWidget {
  const VerifierHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PublicComplaintView>> queue = ref.watch(
      verificationQueueProvider,
    );
    void openQueue() => context.go(AppRoutes.verify);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const HomeSectionHeader(title: 'Verification'),
        const SizedBox(height: AppSpace.s3),
        AsyncSection<List<PublicComplaintView>>(
          value: queue,
          onRetry: () => refreshComplaints(ref),
          errorTitle: "Couldn't load the verification queue",
          loading: const MetricCard(
            label: 'Awaiting verification',
            value: '',
            loading: true,
          ),
          builder: (List<PublicComplaintView> list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.task_alt,
                  title: 'Nothing to do right now',
                  message: 'Nothing is awaiting verification.',
                )
              : MetricCard(
                  label: 'Awaiting verification',
                  value: '${list.length}',
                  definition: 'Repairs resolved and ready for review',
                  onTap: openQueue,
                ),
        ),
        const SizedBox(height: AppSpace.s6),
        AppButton(
          label: 'Open verification queue',
          size: AppButtonSize.lg,
          expand: true,
          leadingIcon: Icons.fact_check_outlined,
          onPressed: openQueue,
        ),
        const SizedBox(height: AppSpace.s3),
        AppButton(
          label: 'Campus board',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          expand: true,
          leadingIcon: Icons.view_kanban_outlined,
          onPressed: () => context.go(AppRoutes.board),
        ),
      ],
    );
  }
}
