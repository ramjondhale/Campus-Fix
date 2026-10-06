import 'package:flutter/material.dart';

import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// One segment of an [AppSegmented].
class AppSegment<T> {
  /// Creates a segment.
  const AppSegment({required this.value, required this.label, this.icon});

  /// Value reported through [AppSegmented.onChanged].
  final T value;

  /// Visible label.
  final String label;

  /// Optional leading icon (shown when the segment is not selected).
  final IconData? icon;
}

/// A single-select segmented control (contract 8.6): "All / Active /
/// Closed", the admin range control.
///
/// Height 40 (32 [dense]), radius `r4`, 1 px `outline`, segments separated by
/// 1 px `outlineVariant`. The selected segment uses `secondaryContainer` /
/// `onSecondaryContainer` with a leading check 16 (never colour alone).
class AppSegmented<T> extends StatelessWidget {
  /// Creates a segmented control.
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.dense = false,
    this.semanticLabel,
  });

  /// The segments, in order.
  final List<AppSegment<T>> segments;

  /// The selected value.
  final T selected;

  /// Called with the chosen value; null disables the control.
  final ValueChanged<T>? onChanged;

  /// Dense admin variant (32 high).
  final bool dense;

  /// Semantics label of the group.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final double height = dense
        ? AppLayout.controlHeightDense
        : AppLayout.controlHeightAdmin;
    final bool enabled = onChanged != null;
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final AppSegment<T> segment = segments[i];
      final bool isSelected = segment.value == selected;
      if (i > 0) {
        children.add(
          VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant),
        );
      }
      children.add(
        Flexible(
          child: AppPressable(
            enabled: enabled,
            radius: BorderRadius.zero,
            selected: isSelected,
            checked: isSelected,
            inMutuallyExclusiveGroup: true,
            isButton: false,
            semanticLabel: segment.label,
            onTap: enabled ? () => onChanged!(segment.value) : null,
            builder: (BuildContext context, Set<WidgetState> states) {
              final bool disabled = states.contains(WidgetState.disabled);
              final Color fg = disabled
                  ? scheme.onSurface.withValues(
                      alpha: AppStateLayer.disabledContent,
                    )
                  : (isSelected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface);
              return Container(
                constraints: BoxConstraints(minHeight: height - 2),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                color: applyStateLayer(
                  isSelected ? scheme.secondaryContainer : Colors.transparent,
                  fg,
                  states,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isSelected)
                        Icon(Icons.check, size: 16, color: fg)
                      else if (segment.icon != null)
                        Icon(segment.icon, size: 16, color: fg),
                      if (isSelected || segment.icon != null)
                        const SizedBox(width: AppSpace.s2),
                      Flexible(
                        child: Text(
                          segment.label,
                          style:
                              (dense
                                      ? context.textTheme.labelMedium
                                      : context.textTheme.labelLarge)!
                                  .copyWith(color: fg),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: semanticLabel,
      child: IntrinsicHeight(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.br4,
            border: Border.all(color: scheme.outline),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.br4,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
