import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'skeleton.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// A dashboard metric (contract 8.15): label, big tabular value and a
/// definition.
///
/// Container `card`, 1 px `outlineVariant`, radius `r4`, padding 16, gap 4.
/// Label `label-md`, value `display-sm` (tabular), definition `body-sm`.
/// States: default; clickable ([onTap]: hover border `outline` and 3%
/// overlay, focus ring, pressed `pressedFill`; opens the complaint list with
/// a preset filter); [loading] (skeleton value 30 high and 60% wide, caption
/// 12 high and 80% wide); [hasError] ("Could not load." plus Retry).
///
/// [attention] adds the Critical / High flag: a 20 px square (`r2`) in the
/// critical set `bg` / `fg` with a `warning_amber` glyph. There is no accent
/// rail.
class MetricCard extends StatelessWidget {
  /// Creates a metric card.
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.definition,
    this.attention = false,
    this.onTap,
    this.loading = false,
    this.hasError = false,
    this.onRetry,
  });

  /// Metric name ("Total", "Critical / High").
  final String label;

  /// The value as text (kept a string so "1,284" or "12" format is the
  /// caller's decision).
  final String value;

  /// One-line definition under the value.
  final String? definition;

  /// Shows the attention flag (Critical / High).
  final bool attention;

  /// Makes the card clickable.
  final VoidCallback? onTap;

  /// Loading skeleton state.
  final bool loading;

  /// Error state with a Retry action.
  final bool hasError;

  /// Retry callback of the error state.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final TextTheme text = context.textTheme;

    Widget body() {
      if (loading) {
        return const Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SkeletonBlock.fraction(widthFactor: 0.4, height: 16),
              SizedBox(height: AppSpace.s1),
              SkeletonBlock.fraction(widthFactor: 0.6, height: 30),
              SizedBox(height: AppSpace.s1),
              SkeletonBlock.fraction(widthFactor: 0.8, height: 12),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: text.labelMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (attention)
                _AttentionFlag(style: context.priorityStyle(Priority.critical)),
            ],
          ),
          const SizedBox(height: AppSpace.s1),
          if (hasError) ...<Widget>[
            Text(
              'Could not load.',
              style: text.bodyMedium!.copyWith(color: scheme.error),
            ),
            if (onRetry != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Retry',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.tertiary,
                  onPressed: onRetry,
                ),
              ),
          ] else ...<Widget>[
            Text(value, style: AppTypography.tabular(text.displaySmall!)),
            if (definition != null) ...<Widget>[
              const SizedBox(height: AppSpace.s1),
              Text(
                definition!,
                style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      );
    }

    Widget shell(Set<WidgetState> states) {
      final bool pressed = states.contains(WidgetState.pressed);
      final bool hovered = states.contains(WidgetState.hovered);
      return Container(
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: pressed
              ? colors.pressedFill
              : applyStateLayer(
                  colors.card,
                  scheme.onSurface,
                  states,
                  hover: 0.03,
                ),
          borderRadius: AppRadius.br4,
          border: Border.all(
            color: hovered ? scheme.outline : scheme.outlineVariant,
          ),
        ),
        child: body(),
      );
    }

    final String semantics = loading
        ? 'Loading $label'
        : (hasError
              ? '$label. Could not load.'
              : '$label: $value${definition == null ? '' : '. $definition'}');
    final bool clickable = onTap != null && !loading && !hasError;
    if (!clickable) {
      return Semantics(
        container: true,
        label: loading ? semantics : null,
        child: shell(<WidgetState>{}),
      );
    }
    return AppPressable(
      onTap: onTap,
      semanticLabel: semantics,
      builder: (BuildContext context, Set<WidgetState> states) => shell(states),
    );
  }
}

class _AttentionFlag extends StatelessWidget {
  const _AttentionFlag({required this.style});

  final PriorityStyle style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: style.bg, borderRadius: AppRadius.br2),
        alignment: Alignment.center,
        child: Icon(Icons.warning_amber, size: 14, color: style.fg),
      ),
    );
  }
}

/// One horizontal bar row of an A-02 chart (contract 8.15): a 96 px label,
/// a flexible 12 px track (`cardSubtle`, `r2`) filled with the set accent,
/// and a 32 px right-aligned tabular value.
///
/// Use the named constructors so the fill always comes from the right
/// semantic set: a chart never mixes sets (contract 2.8).
class MetricBarRow extends StatelessWidget {
  const MetricBarRow._({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.fill,
  });

  /// A bar for a [ComplaintStatus].
  factory MetricBarRow.status({
    Key? key,
    required BuildContext context,
    required ComplaintStatus status,
    required int value,
    required int maxValue,
  }) => MetricBarRow._(
    key: key,
    label: status.label,
    value: value,
    maxValue: maxValue,
    fill: context.statusStyle(status).accent,
  );

  /// A bar for a [Priority].
  factory MetricBarRow.priority({
    Key? key,
    required BuildContext context,
    required Priority priority,
    required int value,
    required int maxValue,
  }) => MetricBarRow._(
    key: key,
    label: priority.label,
    value: value,
    maxValue: maxValue,
    fill: context.priorityStyle(priority).accent,
  );

  /// A bar for a [ProblemCategory] (the label is the full category label).
  factory MetricBarRow.category({
    Key? key,
    required BuildContext context,
    required ProblemCategory category,
    required int value,
    required int maxValue,
  }) => MetricBarRow._(
    key: key,
    label: category.label,
    value: value,
    maxValue: maxValue,
    fill: context.categoryStyle(category).accent,
  );

  /// Direct text label.
  final String label;

  /// The value (also printed as text).
  final int value;

  /// The value that fills the whole track.
  final int maxValue;

  /// Fill colour (a set accent).
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final double fraction = maxValue <= 0 ? 0 : (value / maxValue).clamp(0, 1);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: context.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: colors.cardSubtle,
                  borderRadius: AppRadius.br2,
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: AppRadius.br2,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$value',
                textAlign: TextAlign.right,
                style: AppTypography.tabular(
                  context.textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
