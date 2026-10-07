import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// One choice of a [MultiSelectFilterChip] or [SingleSelectFilterChip].
class FilterOption<T> {
  const FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A filter chip that opens a checklist menu: any number of the [options] can
/// be on (design contract 8.16: multi-select menus use `MenuAnchor`).
///
/// The chip is the design system's [AppFilterChip]; the menu uses Material's
/// `MenuAnchor` and `CheckboxMenuButton`, styled by the theme's `menuTheme`,
/// `menuButtonTheme` and `checkboxTheme`. The menu stays open while boxes are
/// ticked, so several values can be chosen in one visit.
class MultiSelectFilterChip<T> extends StatelessWidget {
  const MultiSelectFilterChip({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// The chip label ("Status").
  final String label;

  /// Every choice, in display order.
  final List<FilterOption<T>> options;

  /// The values that are on.
  final Set<T> selected;

  /// Called with the new set of values whenever a box is ticked or cleared.
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: <Widget>[
        for (final FilterOption<T> option in options)
          CheckboxMenuButton(
            value: selected.contains(option.value),
            closeOnActivate: false,
            onChanged: (bool? on) {
              final Set<T> next = <T>{...selected};
              if (on ?? false) {
                next.add(option.value);
              } else {
                next.remove(option.value);
              }
              onChanged(Set<T>.unmodifiable(next));
            },
            child: Text(option.label),
          ),
      ],
      builder: (BuildContext context, MenuController controller, Widget? _) =>
          AppFilterChip(
            label: label,
            selected: selected.isNotEmpty,
            count: selected.length,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
    );
  }
}

/// A filter chip that opens a menu of mutually exclusive choices: the
/// Building filter. The first entry, [anyLabel], clears the filter.
class SingleSelectFilterChip<T> extends StatelessWidget {
  const SingleSelectFilterChip({
    super.key,
    required this.label,
    required this.anyLabel,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// The chip label ("Building").
  final String label;

  /// The label of the entry that clears the filter ("Any building").
  final String anyLabel;

  /// Every choice, in display order.
  final List<FilterOption<T>> options;

  /// The chosen value, or `null` for any.
  final T? selected;

  /// Called with the chosen value, or `null` for [anyLabel].
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget entry(String text, T? value) {
      final bool on = value == selected;
      return MenuItemButton(
        onPressed: () => onChanged(value),
        leadingIcon: on
            ? const Icon(Icons.check)
            : const SizedBox.square(dimension: AppSpace.s6),
        child: Text(text),
      );
    }

    return MenuAnchor(
      menuChildren: <Widget>[
        entry(anyLabel, null),
        for (final FilterOption<T> option in options)
          entry(option.label, option.value),
      ],
      builder: (BuildContext context, MenuController controller, Widget? _) =>
          AppFilterChip(
            label: label,
            selected: selected != null,
            count: selected == null ? 0 : 1,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
    );
  }
}
