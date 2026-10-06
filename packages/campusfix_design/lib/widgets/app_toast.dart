import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'support/context_ext.dart';

/// Visual kind of an [AppToast].
enum AppToastKind {
  /// Neutral confirmation (no leading icon colour emphasis).
  neutral,

  /// Success: leading check in `inversePrimary`.
  success,

  /// Error: leading error icon in `inverseError`; persists until dismissed.
  error,
}

/// Toast and snackbar helper (contract 8.21).
///
/// Wraps `ScaffoldMessenger` + `SnackBar` (styled by `snackBarTheme`: fill
/// `inverseSurface`, text `onInverseSurface`, floating, radius `r4`). Timing:
/// 4 s, 6 s with an action, errors persist until dismissed. A toast never
/// holds the only copy of an error (G-4).
abstract final class AppToast {
  /// Maximum toast width on mobile and web (contract 8.21).
  static const double maxWidth = 420;

  /// Maximum toast width in the admin console.
  static const double maxWidthAdmin = 560;

  /// Shows a toast with [message] on the nearest `ScaffoldMessenger`.
  ///
  /// Returns null when there is no `ScaffoldMessenger` above [context].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (messenger == null) return null;
    final bool hasAction = actionLabel != null && onAction != null;
    final bool persist = kind == AppToastKind.error;
    final double screen = MediaQuery.sizeOf(context).width;
    final double cap = context.windowClass == AppWindowClass.expanded
        ? maxWidthAdmin
        : maxWidth;
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        content: _ToastContent(message: message, kind: kind),
        width: math.min(cap, math.max(0, screen - 32)),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        duration: Duration(seconds: hasAction ? 6 : 4),
        persist: persist,
        showCloseIcon: persist,
        action: hasAction
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br4),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({required this.message, required this.kind});

  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    final SnackBarThemeData theme = Theme.of(context).snackBarTheme;
    final Color? icon = switch (kind) {
      AppToastKind.success => context.colorScheme.inversePrimary,
      AppToastKind.error => colors.inverseError,
      AppToastKind.neutral => null,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            ExcludeSemantics(
              child: Icon(
                kind == AppToastKind.error
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 20,
                color: icon,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(message, style: theme.contentTextStyle)),
        ],
      ),
    );
  }
}
