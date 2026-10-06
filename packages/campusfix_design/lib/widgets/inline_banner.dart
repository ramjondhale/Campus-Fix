import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// An inline banner (contract 8.22): closed notices, inline errors, stale
/// and unmet preconditions.
///
/// Radius `r4`, padding 12 x 16, gap 12, fill from a feedback set (`info`,
/// `success`, `warning`, `error`) with `fg` text, a 20 px leading icon in the
/// set `accent`, `title-sm` title, `body-md` body and an optional small
/// outlined action (border and text `fg`). There is no accent rail.
class InlineBanner extends StatelessWidget {
  /// Creates a banner.
  const InlineBanner({
    super.key,
    required this.kind,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  /// Feedback kind.
  final FeedbackKind kind;

  /// Optional title.
  final String? title;

  /// Body text.
  final String message;

  /// Label of the optional action.
  final String? actionLabel;

  /// Action callback.
  final VoidCallback? onAction;

  static IconData _icon(FeedbackKind kind) => switch (kind) {
    FeedbackKind.success => Icons.check_circle_outline,
    FeedbackKind.warning => Icons.warning_amber,
    FeedbackKind.error => Icons.error_outline,
    FeedbackKind.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final FeedbackStyle style = context.feedbackStyle(kind);
    final TextTheme text = context.textTheme;
    return Semantics(
      container: true,
      liveRegion: kind == FeedbackKind.error,
      label: '${kind.label}. ${title == null ? '' : '$title. '}$message',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        decoration: BoxDecoration(color: style.bg, borderRadius: AppRadius.br4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_icon(kind), size: 20, color: style.accent),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      style: text.titleSmall!.copyWith(color: style.fg),
                    ),
                  Text(
                    message,
                    style: text.bodyMedium!.copyWith(color: style.fg),
                  ),
                  if (actionLabel != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: _BannerAction(
                        label: actionLabel!,
                        color: style.fg,
                        onTap: onAction!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      radius: AppRadius.br3,
      semanticLabel: label,
      builder: (BuildContext context, Set<WidgetState> states) => Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        decoration: BoxDecoration(
          color: applyStateLayer(Colors.transparent, color, states),
          borderRadius: AppRadius.br3,
          border: Border.all(color: color),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: context.textTheme.labelMedium!.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// A privacy note (contract 8.22): `secondaryContainer` fill,
/// `onSecondaryContainer` text, 1 px `outlineVariant` and a leading
/// `verified_user_outlined` icon.
///
/// Two fixed strings exist: [identityMessage] (M-07) and [photoMessage]
/// (M-05); use the named constructors for them.
class PrivacyNote extends StatelessWidget {
  /// Creates a note with a custom [message].
  const PrivacyNote({super.key, required this.message});

  /// "Your name and contact details are never shown on the board or to
  /// maintenance staff." (M-07)
  const PrivacyNote.identity({Key? key})
    : this(key: key, message: identityMessage);

  /// "Avoid including people's faces or documents." (M-05)
  const PrivacyNote.photos({Key? key}) : this(key: key, message: photoMessage);

  /// The M-07 identity note.
  static const String identityMessage =
      'Your name and contact details are never shown on the board or to '
      'maintenance staff.';

  /// The M-05 photo note.
  static const String photoMessage =
      "Avoid including people's faces or documents.";

  /// The note text.
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Semantics(
      container: true,
      label: 'Privacy note. $message',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: AppRadius.br4,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Text(
                message,
                style: context.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
