import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// The switch track and thumb (contract 8.6): a 48 x 28 track. Off:
/// `cardSubtle` with a 2 px `outline` border and a 16 px `outline` thumb.
/// On: `primary` with a 20 px `onPrimary` thumb.
class AppSwitchVisual extends StatelessWidget {
  /// Creates the visual.
  const AppSwitchVisual({super.key, required this.value, this.enabled = true});

  /// Whether the switch is on.
  final bool value;

  /// False dims the switch (locked / disabled).
  final bool enabled;

  static const double _width = 48;
  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final Duration duration = AppMotion.resolve(context, AppMotion.base);
    final double thumb = value ? 20 : 16;
    return ExcludeSemantics(
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          width: _width,
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: value ? scheme.primary : colors.cardSubtle,
            borderRadius: AppRadius.brFull,
            border: value ? null : Border.all(color: scheme.outline, width: 2),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.standard,
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? scheme.onPrimary : scheme.outline,
            ),
            child: value
                ? Icon(Icons.check, size: 14, color: scheme.primary)
                : null,
          ),
        ),
      ),
    );
  }
}

/// A stand-alone switch with a focus ring and toggle semantics. For a row
/// with a title and helper use [AppSwitchRow].
class AppSwitch extends StatelessWidget {
  /// Creates a switch.
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Semantics label (required: a bare switch has no visible text).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      radius: AppRadius.brFull,
      toggled: value,
      isButton: false,
      semanticLabel: semanticLabel,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      builder: (BuildContext context, Set<WidgetState> states) =>
          AppSwitchVisual(
            value: value,
            enabled: !states.contains(WidgetState.disabled),
          ),
    );
  }
}

/// A settings-style toggle row (contract 8.6): min height 56, `title-sm`
/// title, `body-sm` helper and the switch on the right. The whole row is the
/// tap target.
///
/// [locked] renders the M-06 safety-category state: the control is disabled
/// at 55% with a 16 px lock before the title; the helper should explain why.
class AppSwitchRow extends StatelessWidget {
  /// Creates a toggle row.
  const AppSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.helper,
    this.locked = false,
  });

  /// Title.
  final String title;

  /// Helper text.
  final String? helper;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value; null disables the row.
  final ValueChanged<bool>? onChanged;

  /// Locked state: disabled with a lock icon (M-06).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool enabled = onChanged != null && !locked;
    return AppPressable(
      enabled: enabled,
      toggled: value,
      isButton: false,
      semanticLabel: [title, if (locked) 'locked', ?helper].join(', '),
      onTap: enabled ? () => onChanged!(!value) : null,
      builder: (BuildContext context, Set<WidgetState> states) {
        return Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: applyStateLayer(
              Colors.transparent,
              scheme.onSurface,
              states,
            ),
            borderRadius: AppRadius.br4,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (locked) ...<Widget>[
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            style: context.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (helper != null)
                      Text(
                        helper!,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AppSwitchVisual(value: value, enabled: enabled),
            ],
          ),
        );
      },
    );
  }
}

/// A checkbox with a label row, using the themed Material `Checkbox`
/// (`checkboxTheme`). The whole row (min height 48) toggles it.
class AppCheckboxRow extends StatelessWidget {
  /// Creates a checkbox row.
  const AppCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Visible label.
  final String label;

  /// Whether the box is checked.
  final bool value;

  /// Called with the new value; null disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool enabled = onChanged != null;
    return AppPressable(
      enabled: enabled,
      checked: value,
      isButton: false,
      semanticLabel: label,
      onTap: enabled ? () => onChanged!(!value) : null,
      builder: (BuildContext context, Set<WidgetState> states) {
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: applyStateLayer(
              Colors.transparent,
              scheme.onSurface,
              states,
            ),
            borderRadius: AppRadius.br4,
          ),
          child: Row(
            children: <Widget>[
              ExcludeFocus(
                child: IgnorePointer(
                  child: Checkbox(
                    value: value,
                    onChanged: enabled ? (_) {} : null,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge!.copyWith(
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(
                            alpha: AppStateLayer.disabledContent,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A radio with a label row, using the themed Material `Radio`
/// (`radioThemeData`). It must sit inside a `RadioGroup<T>`, which owns the
/// selected value; the whole row (min height 48) selects it.
class AppRadioRow<T> extends StatelessWidget {
  /// Creates a radio row for [value].
  const AppRadioRow({
    super.key,
    required this.value,
    required this.label,
    this.enabled = true,
  });

  /// The value this row selects.
  final T value;

  /// Visible label.
  final String label;

  /// False renders the disabled state.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final RadioGroupRegistry<T>? group = RadioGroup.maybeOf<T>(context);
    final bool selected = group != null && group.groupValue == value;
    final bool active = enabled && group != null;
    return AppPressable(
      enabled: active,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      isButton: false,
      semanticLabel: label,
      onTap: active ? () => group.onChanged(value) : null,
      builder: (BuildContext context, Set<WidgetState> states) {
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: applyStateLayer(
              Colors.transparent,
              scheme.onSurface,
              states,
            ),
            borderRadius: AppRadius.br4,
          ),
          child: Row(
            children: <Widget>[
              ExcludeFocus(
                child: IgnorePointer(
                  child: Radio<T>(value: value, enabled: active),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge!.copyWith(
                    color: active
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(
                            alpha: AppStateLayer.disabledContent,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
