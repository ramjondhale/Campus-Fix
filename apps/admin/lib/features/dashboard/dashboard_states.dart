import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The body of a dashboard panel for an async [value]: a skeleton while it
/// loads, the design system's error state with **Retry** when it fails, and
/// [builder]'s content otherwise (screens-spec G-3, G-4, A-02 states).
///
/// Every panel has its own instance, so each chart and list shows its own
/// error and Retry.
class AsyncPanelBody<T> extends StatelessWidget {
  const AsyncPanelBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading = const ChartSkeleton(),
    this.errorTitle = "Couldn't load this section",
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  /// The skeleton shown while loading (mirrors the loaded layout).
  final Widget loading;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading,
      error: (_, _) => EmptyState.error(
        title: errorTitle,
        onAction: onRetry,
        alignment: CrossAxisAlignment.start,
      ),
    );
  }
}

/// Skeleton of a bar chart: a few track-sized blocks.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key, this.rows = 5});

  /// How many bar rows to mirror.
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.s1),
              child: SkeletonBlock(height: 12),
            ),
        ],
      ),
    );
  }
}

/// Skeleton of a list of dashboard rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpace.s2),
            const ComplaintCardSkeleton(variant: ComplaintCardVariant.row),
          ],
        ],
      ),
    );
  }
}
