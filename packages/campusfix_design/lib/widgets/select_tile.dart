import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import 'category_chip.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// A selection tile with a leading radio indicator (contract 8.5): severity
/// and people-affected choices (M-06).
///
/// Min height 56, padding 12 x 16, radius `r5`, 1 px `outlineVariant`, fill
/// `card`. Selected: a 2 px `primary` outline and `primaryContainer` at 45%
/// over `card`, plus a filled radio dot (never colour alone). Tiles are
/// radio-semantics items of a mutually exclusive group.
class SelectTile extends StatelessWidget {
  /// Creates a tile.
  const SelectTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.hint,
    this.enabled = true,
  });

  /// Title (`title-sm`).
  final String title;

  /// Optional hint under the title (`body-sm`, `onSurfaceVariant`).
  final String? hint;

  /// Whether this tile is the selected one.
  final bool selected;

  /// Called when the tile is chosen; null disables it.
  final VoidCallback? onTap;

  /// False renders the disabled state (50% opacity).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppPressable(
        enabled: enabled,
        onTap: onTap,
        radius: AppRadius.br5,
        selected: selected,
        checked: selected,
        inMutuallyExclusiveGroup: true,
        isButton: false,
        semanticLabel: hint == null ? title : '$title. $hint',
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color base = selected
              ? Color.alphaBlend(
                  scheme.primaryContainer.withValues(alpha: 0.45),
                  colors.card,
                )
              : colors.card;
          final double border = selected ? 2 : 1;
          return Container(
            constraints: const BoxConstraints(minHeight: 56),
            // Keep the content still when the border grows from 1 to 2 px.
            padding: EdgeInsets.symmetric(
              horizontal: 16 - (border - 1),
              vertical: 12 - (border - 1),
            ),
            decoration: BoxDecoration(
              color: applyStateLayer(
                base,
                scheme.onSurface,
                states,
                hover: 0.04,
                pressed: 0.08,
              ),
              borderRadius: AppRadius.br5,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: border,
              ),
            ),
            child: Row(
              children: <Widget>[
                _RadioDot(selected: selected, enabled: enabled),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: context.textTheme.titleSmall),
                      if (hint != null)
                        Text(
                          hint!,
                          style: context.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              )
            : null,
      ),
    );
  }
}

/// A category selection tile (contract 8.5): an icon chip, the category
/// label and an optional helper. One tile exists per `ProblemCategory`
/// (eight in total); the label always comes from `ProblemCategory.label`.
///
/// Min height 96, padding 12, radius `r5`. Selected: 2 px `primary` outline,
/// `primaryContainer` at 55% over `card` and a 20 px check badge top-right.
/// `safety` and `other` show their fixed helper text by default.
class CategoryTile extends StatelessWidget {
  /// Creates a tile for [category].
  const CategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.helper,
    this.showDefaultHelper = true,
    this.enabled = true,
  });

  /// The category this tile selects.
  final ProblemCategory category;

  /// Whether this tile is the selected one.
  final bool selected;

  /// Called when chosen; null disables the tile.
  final VoidCallback? onTap;

  /// Helper text overriding the default for [category].
  final String? helper;

  /// Shows the fixed helper text of `safety` and `other` when [helper] is
  /// null.
  final bool showDefaultHelper;

  /// False renders the disabled state (50% opacity).
  final bool enabled;

  /// The fixed helper text of a category, or null (contract 8.5 content).
  static String? defaultHelperFor(ProblemCategory category) =>
      switch (category) {
        ProblemCategory.safety =>
          'For immediate danger contact campus security directly',
        ProblemCategory.other => 'Will be reviewed manually',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final String? helperText =
        helper ?? (showDefaultHelper ? defaultHelperFor(category) : null);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppPressable(
        enabled: enabled,
        onTap: onTap,
        radius: AppRadius.br5,
        selected: selected,
        checked: selected,
        inMutuallyExclusiveGroup: true,
        isButton: false,
        semanticLabel: helperText == null
            ? category.label
            : '${category.label}. $helperText',
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color base = selected
              ? Color.alphaBlend(
                  scheme.primaryContainer.withValues(alpha: 0.55),
                  colors.card,
                )
              : colors.card;
          final double border = selected ? 2 : 1;
          return Stack(
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(minHeight: 96),
                width: double.infinity,
                padding: EdgeInsets.all(12 - (border - 1)),
                decoration: BoxDecoration(
                  color: applyStateLayer(
                    base,
                    scheme.onSurface,
                    states,
                    hover: 0.04,
                    pressed: 0.08,
                  ),
                  borderRadius: AppRadius.br5,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CategoryChip(
                      category: category,
                      size: CategoryChipSize.s40,
                    ),
                    const SizedBox(height: 8),
                    Text(category.label, style: context.textTheme.titleSmall),
                    if (helperText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          helperText,
                          style: context.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
