import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Home section title with an optional trailing text action ("See all").
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.tertiary,
            onPressed: onAction,
          ),
      ],
    );
  }
}

/// Renders one independent section of a screen from its [value]: [loading]
/// placeholders while it loads, an error with **Retry** when it fails, and
/// [builder]'s content otherwise (screens-spec G-3, G-4). Sections of the same
/// screen use separate instances, so they fail independently.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.loading,
    required this.builder,
    required this.onRetry,
    this.errorTitle = "Couldn't load this section",
  });

  final AsyncValue<T> value;
  final Widget loading;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading,
      error: (_, _) => EmptyState.error(title: errorTitle, onAction: onRetry),
    );
  }
}

/// A vertical list of [children] separated by the card gap.
class CardColumn extends StatelessWidget {
  const CardColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpace.s3),
          children[i],
        ],
      ],
    );
  }
}
