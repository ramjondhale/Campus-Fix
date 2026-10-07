import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import '../../providers/providers.dart';

/// The failure of a verify or reject action as an inline banner: a rule block
/// (P1, P3, P8 ...) shows its messages; a failed write shows a friendly
/// sentence with Retry (screens-spec G-4).
class VerifyFailureBanner extends StatelessWidget {
  const VerifyFailureBanner({
    super.key,
    required this.state,
    required this.title,
    required this.onRetry,
  });

  final VerifyActionState state;
  final String title;

  /// Retries a failed write; `null` hides the action (a rule block has none).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return InlineBanner(
      kind: state.blocked ? FeedbackKind.warning : FeedbackKind.error,
      title: title,
      message: state.messages.join(' '),
      actionLabel: state.blocked || onRetry == null ? null : 'Retry',
      onAction: state.blocked ? null : onRetry,
    );
  }
}
