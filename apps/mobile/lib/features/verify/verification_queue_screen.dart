import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../shared/coming_soon_screen.dart' show popOrHome;
import '../shared/list_states.dart';

/// M-16 Verification Queue: the complaints maintenance marked resolved and a
/// verifier has yet to judge (AC-40: only `resolved` ones), most urgent first,
/// then the longest waiting since being resolved. Reached from Home "Open
/// verification queue"; the bottom navigation keeps Home selected. Consumes
/// `verificationQueueProvider` (public views only), the same source as the
/// Home "Awaiting verification" count (AC-41), so the two always agree.
///
/// A card shows the ID, category, location, priority, the before and after
/// thumbnails and the time since it was resolved; tapping it opens the verify
/// detail (M-17).
class VerificationQueueScreen extends ConsumerWidget {
  const VerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PublicComplaintView>> queue = ref.watch(
      verificationQueueProvider,
    );

    return Scaffold(
      appBar: AppTopBar.page(
        title: 'Verification queue',
        onBack: () => popOrHome(context),
      ),
      body: queue.when(
        loading: () =>
            const ComplaintListSkeleton(variant: ComplaintCardVariant.verify),
        error: (_, _) => RefreshFill(
          onRefresh: () => refreshComplaints(ref),
          child: EmptyState.error(
            title: "Couldn't load the verification queue",
            onAction: () => refreshComplaints(ref),
          ),
        ),
        data: (List<PublicComplaintView> list) =>
            _buildData(context, ref, list),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    WidgetRef ref,
    List<PublicComplaintView> list,
  ) {
    if (list.isEmpty) {
      return RefreshFill(
        onRefresh: () => refreshComplaints(ref),
        child: const EmptyState(
          icon: Icons.task_alt,
          title: 'Nothing awaiting verification',
          message:
              'Repairs that maintenance marks as resolved will show up '
              'here.',
        ),
      );
    }
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Text(
            '${list.length} awaiting verification',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => refreshComplaints(ref),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s2,
                AppSpace.s4,
                AppSpace.s4,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
              itemBuilder: (BuildContext context, int i) {
                final PublicComplaintView c = list[i];
                return ComplaintCard(
                  complaint: c,
                  variant: ComplaintCardVariant.verify,
                  onTap: () => context.push(AppRoutes.verifyItem(c.id)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
