import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import '../theme/app_typography.dart';
import 'support/field_parts.dart';

/// Input kind of an [AppTextField] (contract 8.2 variants).
enum AppTextFieldKind {
  /// Single line text.
  text,

  /// Obscured text with a trailing show / hide toggle.
  password,

  /// Multiline text (min 3 lines, 96 high); a [AppTextField.maxLength]
  /// counter is expected.
  multiline,

  /// Digits only.
  numeric,
}

/// The CampusFix text field (contract 8.2).
///
/// The label sits above the control (`label-md`, `onSurfaceVariant`);
/// required fields append a red asterisk. The control itself is a Material
/// `TextField` styled by `inputDecorationTheme` (outlined, 1 px `outline`,
/// fill `card`, hover `onSurface` border, focus 2 px `primary`, error 2 px
/// `error`, disabled `cardSubtle`). Helper text and the right-aligned
/// character counter sit below; an [errorText] shows an error icon and the
/// message in the error colour (never colour alone).
///
/// Validate on blur and on attempted submit (G-7) in the caller and pass the
/// resulting message as [errorText]. Free text is trimmed by the caller.
class AppTextField extends StatefulWidget {
  /// Creates a text field.
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.kind = AppTextFieldKind.text,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.dense = false,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.leadingIcon,
    this.trailing,
    this.textInputAction,
    this.autofocus = false,
  });

  /// A password field with a show / hide toggle.
  const AppTextField.password({
    Key? key,
    String? label,
    String? hintText,
    String? helperText,
    String? errorText,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool required = false,
    bool enabled = true,
    bool dense = false,
    TextInputAction? textInputAction,
  }) : this(
         key: key,
         label: label,
         hintText: hintText,
         helperText: helperText,
         errorText: errorText,
         controller: controller,
         focusNode: focusNode,
         onChanged: onChanged,
         onSubmitted: onSubmitted,
         kind: AppTextFieldKind.password,
         required: required,
         enabled: enabled,
         dense: dense,
         textInputAction: textInputAction,
         leadingIcon: Icons.lock_outline,
       );

  /// A multiline field (min 3 lines) with a mandatory character counter.
  const AppTextField.multiline({
    Key? key,
    String? label,
    String? hintText,
    String? helperText,
    String? errorText,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    bool required = false,
    bool enabled = true,
    bool readOnly = false,
    required int maxLength,
  }) : this(
         key: key,
         label: label,
         hintText: hintText,
         helperText: helperText,
         errorText: errorText,
         controller: controller,
         focusNode: focusNode,
         onChanged: onChanged,
         kind: AppTextFieldKind.multiline,
         required: required,
         enabled: enabled,
         readOnly: readOnly,
         maxLength: maxLength,
         minLines: 3,
         maxLines: 6,
       );

  /// A digits-only field.
  const AppTextField.numeric({
    Key? key,
    String? label,
    String? hintText,
    String? helperText,
    String? errorText,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    bool required = false,
    bool enabled = true,
    bool dense = false,
    int? maxLength,
  }) : this(
         key: key,
         label: label,
         hintText: hintText,
         helperText: helperText,
         errorText: errorText,
         controller: controller,
         focusNode: focusNode,
         onChanged: onChanged,
         kind: AppTextFieldKind.numeric,
         required: required,
         enabled: enabled,
         dense: dense,
         maxLength: maxLength,
       );

  /// The privacy helper shown on fields that take free text where
  /// privacy-spec section 6 requires it.
  static const String visibilityHelper = 'Visible to people involved';

  /// Label above the control.
  final String? label;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Helper text below the control.
  final String? helperText;

  /// Error message; non-null switches the field to the error state.
  final String? errorText;

  /// Text controller.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (keyboard action).
  final ValueChanged<String>? onSubmitted;

  /// Input kind.
  final AppTextFieldKind kind;

  /// Appends a red asterisk to the label.
  final bool required;

  /// False renders the disabled state (fill `cardSubtle`, text 38%).
  final bool enabled;

  /// True renders the read-only state (fill `cardSubtle`, normal text).
  final bool readOnly;

  /// Admin dense control: 40 high and `body-md` text instead of 48 / 16.
  final bool dense;

  /// Maximum length; shows the tabular counter.
  final int? maxLength;

  /// Maximum visible lines (multiline).
  final int? maxLines;

  /// Minimum visible lines (multiline).
  final int? minLines;

  /// Leading icon (20).
  final IconData? leadingIcon;

  /// Trailing widget (20 icon or an action keeping a 48 hit area).
  final Widget? trailing;

  /// Keyboard action.
  final TextInputAction? textInputAction;

  /// Whether to autofocus.
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool password = widget.kind == AppTextFieldKind.password;
    final bool multiline = widget.kind == AppTextFieldKind.multiline;
    final bool inactive = !widget.enabled || widget.readOnly;
    final bool hasError = widget.errorText != null;
    final TextStyle base = (widget.dense
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodyLarge)!;
    final TextStyle textStyle = base.copyWith(
      color: widget.enabled
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: AppStateLayer.disabledContent),
    );

    final Widget? suffix = password
        ? IconButton(
            tooltip: _obscured ? 'Show password' : 'Hide password',
            onPressed: widget.enabled
                ? () => setState(() => _obscured = !_obscured)
                : null,
            iconSize: 20,
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          )
        : widget.trailing;

    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      if (widget.kind == AppTextFieldKind.numeric)
        FilteringTextInputFormatter.digitsOnly,
    ];

    final InputDecoration decoration = InputDecoration(
      hintText: widget.hintText,
      filled: true,
      fillColor: inactive ? colors.cardSubtle : colors.card,
      isDense: widget.dense,
      constraints: BoxConstraints(
        minHeight: multiline
            ? 96
            : (widget.dense
                  ? AppLayout.controlHeightAdmin
                  : AppLayout.controlHeightMobile),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: widget.dense ? AppSpace.s2 : AppSpace.s3,
      ),
      prefixIcon: widget.leadingIcon == null
          ? null
          : Icon(widget.leadingIcon, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      // Helper text is rendered by the decorator; the error carries an icon.
      helperText: hasError ? null : widget.helperText,
      error: hasError ? FieldError(message: widget.errorText!) : null,
    );

    final Widget field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: password && _obscured,
      keyboardType: switch (widget.kind) {
        AppTextFieldKind.numeric => TextInputType.number,
        AppTextFieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      textInputAction: widget.textInputAction,
      inputFormatters: formatters,
      maxLength: widget.maxLength,
      maxLines: multiline ? widget.maxLines : 1,
      minLines: multiline ? (widget.minLines ?? 3) : 1,
      style: textStyle,
      decoration: decoration,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      buildCounter:
          (
            BuildContext context, {
            required int currentLength,
            required bool isFocused,
            required int? maxLength,
          }) => maxLength == null
          ? null
          : Text(
              '$currentLength/$maxLength',
              style: AppTypography.tabular(
                theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
    );

    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FieldLabel(label: widget.label!, required: widget.required),
        field,
      ],
    );
  }
}
