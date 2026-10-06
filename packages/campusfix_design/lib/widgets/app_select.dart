import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_bottom_sheet.dart';
import 'app_search_field.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';
import 'support/field_parts.dart';

/// One option of an [AppSelect].
class AppSelectOption<T> {
  /// Creates an option.
  const AppSelectOption({required this.value, required this.label});

  /// The value reported through [AppSelect.onChanged].
  final T value;

  /// Visible label.
  final String label;
}

/// The CampusFix select (contract 8.3): the text-field shell with a trailing
/// `expand_more`.
///
/// On compact windows (mobile) it opens a bottom sheet list (8.20); on wider
/// windows (admin) an anchored menu. More than [searchThreshold] options adds
/// an inline search field. The selected row uses `primaryContainer`, a check
/// and `label-lg` weight.
class AppSelect<T> extends StatefulWidget {
  /// Creates a select.
  const AppSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'Select',
    this.helperText,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.dense = false,
    this.searchThreshold = 8,
    this.sheetTitle,
  });

  /// The options in display order.
  final List<AppSelectOption<T>> options;

  /// The selected value, or null for none.
  final T? value;

  /// Called with the chosen value.
  final ValueChanged<T>? onChanged;

  /// Label above the control.
  final String? label;

  /// Placeholder while nothing is selected.
  final String hintText;

  /// Helper text below.
  final String? helperText;

  /// Error message; non-null switches to the error state.
  final String? errorText;

  /// Appends the red asterisk to the label.
  final bool required;

  /// False renders the disabled state.
  final bool enabled;

  /// Admin dense control (40 high; menu items 40 high).
  final bool dense;

  /// Options count above which an inline search is added.
  final int searchThreshold;

  /// Title of the mobile sheet (defaults to [label]).
  final String? sheetTitle;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final MenuController _menu = MenuController();
  double _width = 0;

  AppSelectOption<T>? get _selected {
    for (final AppSelectOption<T> o in widget.options) {
      if (o.value == widget.value) return o;
    }
    return null;
  }

  void _choose(T value) {
    widget.onChanged?.call(value);
  }

  Future<void> _open() async {
    if (context.windowClass == AppWindowClass.compact) {
      final AppSelectOption<T>? picked =
          await AppBottomSheet.show<AppSelectOption<T>>(
            context: context,
            title: widget.sheetTitle ?? widget.label,
            builder: (BuildContext sheetContext) => _OptionList<T>(
              options: widget.options,
              selected: widget.value,
              dense: false,
              searchable: widget.options.length > widget.searchThreshold,
              onPick: (AppSelectOption<T> o) =>
                  Navigator.of(sheetContext).pop(o),
            ),
          );
      if (picked != null) _choose(picked.value);
    } else if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool hasError = widget.errorText != null;
    final bool enabled = widget.enabled && widget.onChanged != null;
    final AppSelectOption<T>? selected = _selected;

    final Widget shell = AppPressable(
      enabled: enabled,
      onTap: _open,
      semanticLabel:
          '${widget.label ?? ''} ${selected?.label ?? widget.hintText}'.trim(),
      builder: (BuildContext context, Set<WidgetState> states) {
        final bool disabled = states.contains(WidgetState.disabled);
        final BorderSide side;
        if (hasError) {
          side = BorderSide(color: scheme.error, width: 2);
        } else if (disabled) {
          side = BorderSide(color: scheme.outlineVariant);
        } else if (states.contains(WidgetState.focused)) {
          side = BorderSide(color: scheme.primary, width: 2);
        } else if (states.contains(WidgetState.hovered)) {
          side = BorderSide(color: scheme.onSurface);
        } else {
          side = BorderSide(color: scheme.outline);
        }
        final TextStyle base = (widget.dense
            ? context.textTheme.bodyMedium
            : context.textTheme.bodyLarge)!;
        final Color text = disabled
            ? scheme.onSurface.withValues(alpha: AppStateLayer.disabledContent)
            : (selected == null ? scheme.onSurfaceVariant : scheme.onSurface);
        return Container(
          constraints: BoxConstraints(
            minHeight: widget.dense
                ? AppLayout.controlHeightAdmin
                : AppLayout.controlHeightMobile,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          decoration: BoxDecoration(
            color: disabled ? colors.cardSubtle : colors.card,
            borderRadius: AppRadius.br4,
            border: Border.fromBorderSide(side),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  selected?.label ?? widget.hintText,
                  style: base.copyWith(color: text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Icon(Icons.expand_more, size: 20, color: text),
            ],
          ),
        );
      },
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _width = constraints.hasBoundedWidth ? constraints.maxWidth : 280;
        final Widget anchored = MenuAnchor(
          controller: _menu,
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll<Size>(Size(_width, 0)),
            maximumSize: WidgetStatePropertyAll<Size>(Size(_width, 360)),
          ),
          menuChildren: <Widget>[
            SizedBox(
              width: _width - 8,
              child: _OptionList<T>(
                options: widget.options,
                selected: widget.value,
                dense: widget.dense,
                searchable: widget.options.length > widget.searchThreshold,
                onPick: (AppSelectOption<T> o) {
                  _menu.close();
                  _choose(o.value);
                },
              ),
            ),
          ],
          child: shell,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.label != null)
              FieldLabel(label: widget.label!, required: widget.required),
            anchored,
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: FieldError(message: widget.errorText!),
              )
            else if (widget.helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: FieldHelper(text: widget.helperText!),
              ),
          ],
        );
      },
    );
  }
}

class _OptionList<T> extends StatefulWidget {
  const _OptionList({
    required this.options,
    required this.selected,
    required this.dense,
    required this.searchable,
    required this.onPick,
  });

  final List<AppSelectOption<T>> options;
  final T? selected;
  final bool dense;
  final bool searchable;
  final ValueChanged<AppSelectOption<T>> onPick;

  @override
  State<_OptionList<T>> createState() => _OptionListState<T>();
}

class _OptionListState<T> extends State<_OptionList<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<AppSelectOption<T>> shown = <AppSelectOption<T>>[
      for (final AppSelectOption<T> o in widget.options)
        if (q.isEmpty || o.label.toLowerCase().contains(q)) o,
    ];
    final ColorScheme scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: AppSearchField(
              hintText: 'Search',
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
        Flexible(
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Text(
                    'No matches',
                    style: context.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final AppSelectOption<T> o in shown)
                      _OptionRow<T>(
                        option: o,
                        selected: o.value == widget.selected,
                        dense: widget.dense,
                        onTap: () => widget.onPick(o),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.dense,
    required this.onTap,
  });

  final AppSelectOption<T> option;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: option.label,
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color fg = selected
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
        final Color base = selected
            ? scheme.primaryContainer
            : Colors.transparent;
        return Container(
          constraints: BoxConstraints(minHeight: dense ? 40 : 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          decoration: BoxDecoration(
            color: applyStateLayer(base, fg, states),
            borderRadius: AppRadius.br3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  option.label,
                  style:
                      (selected
                              ? context.textTheme.labelLarge
                              : context.textTheme.bodyLarge)!
                          .copyWith(color: fg),
                ),
              ),
              if (selected) Icon(Icons.check, size: 20, color: fg),
            ],
          ),
        );
      },
    );
  }
}
