import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// One choice of a filter sheet.
class FilterOption<T> {
  const FilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// Opens a bottom sheet to pick any number of [options]. Every tap reports
/// the new set through [onChanged] so the list behind updates live; "Done"
/// closes the sheet.
Future<void> showMultiSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<FilterOption<T>> options,
  required Set<T> selected,
  required ValueChanged<Set<T>> onChanged,
}) {
  Set<T> current = <T>{...selected};
  return AppBottomSheet.show<void>(
    context: context,
    title: title,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final FilterOption<T> o in options)
                  AppSheetRow(
                    label: o.label,
                    selected: current.contains(o.value),
                    onTap: () {
                      setSheetState(() {
                        current = current.contains(o.value)
                            ? (<T>{...current}..remove(o.value))
                            : <T>{...current, o.value};
                      });
                      onChanged(current);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton(
            label: 'Done',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Opens a bottom sheet to pick exactly one of [options]; returns the choice,
/// or `null` when dismissed.
Future<T?> showSingleSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<FilterOption<T>> options,
  required T selected,
}) {
  return AppBottomSheet.show<T>(
    context: context,
    title: title,
    builder: (BuildContext sheetContext) => ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final FilterOption<T> o in options)
          AppSheetRow(
            label: o.label,
            selected: o.value == selected,
            onTap: () => Navigator.of(sheetContext).pop(o.value),
          ),
      ],
    ),
  );
}
