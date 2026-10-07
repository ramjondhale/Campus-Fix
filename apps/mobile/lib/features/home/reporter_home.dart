import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'home_widgets.dart';

/// Reporter Home (M-02): the Report call to action, up to three active
/// complaints of the signed-in reporter, and campus board highlights. Public
/// views only.
class ReporterHome extends ConsumerWidget {
  const ReporterHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PublicComplaintView>> mine = ref.watch(
      myActiveComplaintsProvider,
    );
    final AsyncValue<List<PublicComplaintView>> highlights = ref.watch(
      boardHighlightsProvider,
    );
    void report() => context.push(AppRoutes.reportCategory);
    void retry() => refreshComplaints(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppButton(
          label: 'Report a Problem',
          size: AppButtonSize.lg,
          expand: true,
          leadingIcon: Icons.add,
          onPressed: report,
        ),
        const SizedBox(height: AppSpace.s6),
        HomeSectionHeader(
          title: 'My active complaints',
          actionLabel: 'See all',
          onAction: () => context.go(AppRoutes.complaints),
        ),
        const SizedBox(height: AppSpace.s3),
        AsyncSection<List<PublicComplaintView>>(
          value: mine,
          onRetry: retry,
          errorTitle: "Couldn't load your complaints",
          loading: const CardColumn(
            children: <Widget>[
              ComplaintCardSkeleton(variant: ComplaintCardVariant.mine),
              ComplaintCardSkeleton(variant: ComplaintCardVariant.mine),
            ],
          ),
          builder: (List<PublicComplaintView> list) => list.isEmpty
              ? EmptyState.nothing(
                  actionLabel: 'Report a Problem',
                  onAction: report,
                )
              : CardColumn(
                  children: <Widget>[
                    for (final PublicComplaintView c in list)
                      ComplaintCard(
                        complaint: c,
                        variant: ComplaintCardVariant.mine,
                        onTap: () => context.push(AppRoutes.complaint(c.id)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.s6),
        HomeSectionHeader(
          title: 'Campus board highlights',
          actionLabel: 'See all',
          onAction: () => context.go(AppRoutes.board),
        ),
        const SizedBox(height: AppSpace.s3),
        AsyncSection<List<PublicComplaintView>>(
          value: highlights,
          onRetry: retry,
          errorTitle: "Couldn't load the campus board",
          loading: const CardColumn(
            children: <Widget>[
              ComplaintCardSkeleton(),
              ComplaintCardSkeleton(),
            ],
          ),
          builder: (List<PublicComplaintView> list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No urgent issues right now',
                  message: 'Critical and high priority problems show up here.',
                )
              : CardColumn(
                  children: <Widget>[
                    for (final PublicComplaintView c in list)
                      ComplaintCard(
                        complaint: c,
                        onTap: () => context.push(AppRoutes.boardItem(c.id)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
