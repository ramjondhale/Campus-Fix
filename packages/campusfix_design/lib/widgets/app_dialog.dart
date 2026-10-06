import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'support/context_ext.dart';

/// The CampusFix dialog (contract 8.20): fill `raised`, radius `r5`, padding
/// 24, content gap 12, elevation `e3`.
///
/// Title `headline-sm` (a question or an action), body `body-md` in
/// `onSurfaceVariant`, optional [content] (a form field), and right-aligned
/// [actions] with the primary action last. Width is `min(420, width - 32)` on
/// mobile and 560 in the admin console.
///
/// Use [confirm] and [confirmWithNote] to show it. The destructive button
/// repeats the verb of the title ("Reject").
class AppDialog extends StatelessWidget {
  /// Creates a dialog surface. Prefer the [confirm] helpers for the common
  /// cases.
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const <Widget>[],
  });

  /// Title `headline-sm`.
  final String title;

  /// Body text.
  final String? message;

  /// Optional extra content under the message (a form field).
  final Widget? content;

  /// Action buttons, primary last.
  final List<Widget> actions;

  /// Shows a confirm dialog; resolves to true on confirm, false or null on
  /// cancel / dismiss.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    String? message,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) {
    return _show<bool>(
      context,
      (BuildContext dialogContext) => AppDialog(
        title: title,
        message: message,
        actions: <Widget>[
          AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.tertiary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            variant: destructive
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
  }

  /// Shows a confirm dialog with a note field (M-17 reject, A-04 actions).
  /// Resolves to the trimmed note on confirm, or null on cancel. When
  /// [noteRequired] is true the confirm button stays disabled until the note
  /// has text.
  static Future<String?> confirmWithNote({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    required String noteLabel,
    String? message,
    String cancelLabel = 'Cancel',
    bool destructive = false,
    bool noteRequired = true,
    int maxLength = 500,
  }) {
    return _show<String>(
      context,
      (BuildContext dialogContext) => _NoteDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        noteLabel: noteLabel,
        destructive: destructive,
        noteRequired: noteRequired,
        maxLength: maxLength,
      ),
    );
  }

  static Future<T?> _show<T>(BuildContext context, WidgetBuilder builder) {
    return showDialog<T>(
      context: context,
      builder: builder,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: AppMotion.moderate,
              reverseDuration: AppMotion.base,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double maxWidth = context.windowClass == AppWindowClass.compact
        ? AppLayout.mobileDialogWidth(width)
        : AppLayout.dialogMaxWidthAdmin;
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Dialog(
      // Surface, shadow (e3) and scrim come from `dialogTheme`.
      backgroundColor: colors.raised,
      insetPadding: const EdgeInsets.all(AppSpace.s4),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.br5),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(title, style: context.textTheme.headlineSmall),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpace.s3),
                Text(
                  message!,
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (content != null) ...<Widget>[
                const SizedBox(height: AppSpace.s3),
                content!,
              ],
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.s6),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.noteLabel,
    required this.destructive,
    required this.noteRequired,
    required this.maxLength,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final String noteLabel;
  final bool destructive;
  final bool noteRequired;
  final int maxLength;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _note,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final String trimmed = value.text.trim();
        final bool canConfirm = !widget.noteRequired || trimmed.isNotEmpty;
        return AppDialog(
          title: widget.title,
          message: widget.message,
          content: AppTextField.multiline(
            label: widget.noteLabel,
            required: widget.noteRequired,
            controller: _note,
            maxLength: widget.maxLength,
          ),
          actions: <Widget>[
            AppButton(
              label: widget.cancelLabel,
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppButton(
              label: widget.confirmLabel,
              variant: widget.destructive
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(trimmed)
                  : null,
            ),
          ],
        );
      },
    );
  }
}
