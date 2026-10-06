import 'package:flutter/material.dart';

import '../../theme/tokens/spacing_tokens.dart';
import 'context_ext.dart';

/// The label above a form control (contract 8.2): `label-md` in
/// `onSurfaceVariant`; required fields append a red asterisk that screen
/// readers announce as "required".
class FieldLabel extends StatelessWidget {
  /// Creates a field label.
  const FieldLabel({super.key, required this.label, this.required = false});

  /// Label text.
  final String label;

  /// Appends the red asterisk.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s1),
      child: Text.rich(
        TextSpan(
          text: label,
          children: <InlineSpan>[
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: scheme.error),
                semanticsLabel: ', required',
              ),
          ],
        ),
        style: context.textTheme.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The helper text below a control: `body-sm` in `onSurfaceVariant`.
class FieldHelper extends StatelessWidget {
  /// Creates helper text.
  const FieldHelper({super.key, required this.text});

  /// Helper text.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.bodySmall!.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The error message below a control: an error icon plus the message in the
/// `error` colour, so an error is never colour alone (contract 7.2, 9.10).
class FieldError extends StatelessWidget {
  /// Creates an error message.
  const FieldError({super.key, required this.message});

  /// The message: names the problem and the fix.
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(
            child: Icon(Icons.error_outline, size: 16, color: scheme.error),
          ),
        ),
        const SizedBox(width: AppSpace.s1),
        Expanded(
          child: Text(
            message,
            style: context.textTheme.bodySmall!.copyWith(color: scheme.error),
          ),
        ),
      ],
    );
  }
}
