import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'app_search_field.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// Behaviour of an [AppFilterChip] (contract 8.16).
enum AppFilterChipKind {
  /// Opens a menu or sheet: a trailing `expand_more`.
  menu,

  /// An on / off filter ("Include closed", "Unresolved only"): a leading
  /// check when on.
  toggle,
}

/// A filter chip (contract 8.16): 32 high, radius `r4`, padding 0 x 12,
/// 1 px `outline`, `label-lg`, icons 16.
///
/// A chip with active values is [selected]: `secondaryContainer` fill,
/// `onSecondaryContainer` text, no border, plus a [count] pill (18 high,
/// inverse colours). States: default, hover (8%), pressed (12%), focus ring,
/// selected, disabled (40% opacity).
class AppFilterChip extends StatelessWidget {
  /// Creates a filter chip.
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.kind = AppFilterChipKind.menu,
    this.count,
  });

  /// Chip label.
  final String label;

  /// Whether the filter is active.
  final bool selected;

  /// Called when tapped (opens the menu, or toggles); null disables the chip.
  final VoidCallback? onTap;

  /// Menu or toggle chip.
  final AppFilterChipKind kind;

  /// Number of active values, shown in a pill when above zero.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool toggle = kind == AppFilterChipKind.toggle;
    final int active = count ?? 0;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: AppPressable(
        onTap: onTap,
        selected: selected,
        toggled: toggle ? selected : null,
        semanticLabel: [
          label,
          if (active > 0) '$active selected',
          if (selected && active == 0) 'on',
        ].join(', '),
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fg = selected
              ? scheme.onSecondaryContainer
              : scheme.onSurface;
          return Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            decoration: BoxDecoration(
              color: applyStateLayer(
                selected ? scheme.secondaryContainer : Colors.transparent,
                fg,
                states,
              ),
              borderRadius: AppRadius.br4,
              border: selected ? null : Border.all(color: scheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (toggle && selected) ...<Widget>[
                  Icon(Icons.check, size: 16, color: fg),
                  const SizedBox(width: AppSpace.s1),
                ],
                Text(
                  label,
                  style: context.textTheme.labelLarge!.copyWith(color: fg),
                  maxLines: 1,
                  softWrap: false,
                ),
                if (active > 0) ...<Widget>[
                  const SizedBox(width: AppSpace.s2),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: scheme.inverseSurface,
                      borderRadius: AppRadius.brFull,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$active',
                      style: context.textTheme.labelSmall!.copyWith(
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ],
                if (kind == AppFilterChipKind.menu) ...<Widget>[
                  const SizedBox(width: AppSpace.s1),
                  Icon(Icons.expand_more, size: 16, color: fg),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Layout of a [FilterBar] (contract 8.16).
enum FilterBarLayout {
  /// Mobile on compact windows, admin toolbar otherwise.
  auto,

  /// One horizontally scrolling row (mobile): chips, then a trailing "Clear".
  scroll,

  /// Wrapping toolbar (admin): the search field first (width 280), then the
  /// chips, then "Reset filters".
  wrap,
}

/// The filter strip above a list (contract 8.16).
///
/// Mobile: one horizontally scrolling row (gap 8) directly under the app bar;
/// a trailing tertiary "Clear" appears when [hasActiveFilters]. Admin: a
/// wrapping toolbar (gap 8 x 12), the optional [search] field first (width
/// 280), then the [chips], then "Reset filters".
class FilterBar extends StatelessWidget {
  /// Creates a filter bar.
  const FilterBar({
    super.key,
    required this.chips,
    this.search,
    this.hasActiveFilters = false,
    this.onClear,
    this.layout = FilterBarLayout.auto,
  });

  /// The filter chips ([AppFilterChip]s).
  final List<Widget> chips;

  /// Admin only: the search field shown first.
  final AppSearchField? search;

  /// Whether any filter is active (shows Clear / Reset).
  final bool hasActiveFilters;

  /// Called by the Clear / Reset action.
  final VoidCallback? onClear;

  /// Layout; defaults to the window class.
  final FilterBarLayout layout;

  @override
  Widget build(BuildContext context) {
    final FilterBarLayout resolved = switch (layout) {
      FilterBarLayout.auto =>
        context.windowClass == AppWindowClass.compact
            ? FilterBarLayout.scroll
            : FilterBarLayout.wrap,
      _ => layout,
    };
    if (resolved == FilterBarLayout.scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.screenPaddingMobile,
          vertical: AppSpace.s2,
        ),
        child: Row(
          children: <Widget>[
            for (final Widget chip in chips) ...<Widget>[
              chip,
              const SizedBox(width: AppSpace.s2),
            ],
            if (hasActiveFilters)
              AppButton(
                label: 'Clear',
                variant: AppButtonVariant.tertiary,
                size: AppButtonSize.sm,
                onPressed: onClear,
              ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (search != null) SizedBox(width: 280, child: search),
        ...chips,
        if (hasActiveFilters)
          AppButton(
            label: 'Reset filters',
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            onPressed: onClear,
          ),
      ],
    );
  }
}
