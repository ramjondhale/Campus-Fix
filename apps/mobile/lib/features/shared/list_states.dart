import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// Pull-to-refresh around a single non-list [child] (an empty or error
/// state): the child fills the viewport and the page can still be dragged.
class RefreshFill extends StatelessWidget {
  const RefreshFill({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(hasScrollBody: false, child: child),
        ],
      ),
    );
  }
}

/// The loading placeholder of a complaint list: a few card skeletons.
class ComplaintListSkeleton extends StatelessWidget {
  const ComplaintListSkeleton({
    super.key,
    this.variant = ComplaintCardVariant.board,
    this.count = 4,
  });

  final ComplaintCardVariant variant;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpace.s3),
          ComplaintCardSkeleton(variant: variant),
        ],
      ],
    );
  }
}
