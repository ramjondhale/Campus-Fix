import 'package:flutter/material.dart';

import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/motion_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// One row of an option sheet (contract 8.20): 56 high, 24 leading icon,
/// `body-lg` label.
class AppSheetOption<T> {
  /// Creates an option.
  const AppSheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  /// Value returned when the row is chosen.
  final T value;

  /// Visible label.
  final String label;

  /// Optional leading icon (24).
  final IconData? icon;

  /// Renders the row in the error colour.
  final bool destructive;
}

/// Bottom sheet helpers (contract 8.20).
///
/// Fill `raised`, top radius `r6`, a 32 x 4 grab handle, padding 8 x 16 x 24,
/// maximum height 90%, drag to dismiss, `e3`. The surface comes from
/// `bottomSheetTheme`; this class adds the title and padding.
abstract final class AppBottomSheet {
  /// Shows a modal bottom sheet with [title] and [builder] content.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isDismissible = true,
  }) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: AppMotion.moderate,
              reverseDuration: AppMotion.base,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            ),
      builder: (BuildContext sheetContext) {
        return AppSheetBody(title: title, child: builder(sheetContext));
      },
    );
  }

  /// Shows a list of [options] and returns the chosen value (photo source
  /// sheets, pickers).
  static Future<T?> showOptions<T>({
    required BuildContext context,
    required List<AppSheetOption<T>> options,
    String? title,
  }) {
    return show<T>(
      context: context,
      title: title,
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AppSheetOption<T> option in options)
            AppSheetRow(
              label: option.label,
              icon: option.icon,
              destructive: option.destructive,
              onTap: () => Navigator.of(sheetContext).pop(option.value),
            ),
        ],
      ),
    );
  }
}

/// Padding and optional title around sheet content. Used by
/// [AppBottomSheet.show]; also usable to build an inline preview.
class AppSheetBody extends StatelessWidget {
  /// Creates the sheet body.
  const AppSheetBody({super.key, required this.child, this.title});

  /// Title (`title-md`).
  final String? title;

  /// Sheet content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text(title!, style: context.textTheme.titleMedium),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// A 56 high sheet row with a 24 leading icon and a `body-lg` label.
class AppSheetRow extends StatelessWidget {
  /// Creates a row.
  const AppSheetRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  /// Visible label.
  final String label;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Optional leading icon.
  final IconData? icon;

  /// Renders in the error colour.
  final bool destructive;

  /// Shows a trailing check and selected semantics.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final Color fg = destructive ? scheme.error : scheme.onSurface;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      builder: (BuildContext context, Set<WidgetState> states) {
        return Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: applyStateLayer(Colors.transparent, fg, states),
            borderRadius: AppRadius.br4,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 24, color: fg),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge!.copyWith(color: fg),
                ),
              ),
              if (selected) Icon(Icons.check, size: 24, color: scheme.primary),
            ],
          ),
        );
      },
    );
  }
}
