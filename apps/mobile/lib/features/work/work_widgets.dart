import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import '../../providers/providers.dart';

/// The privacy helper under every note field (privacy-spec section 6).
const String kNoteVisibilityHelper =
    "Visible to people involved in this complaint. Don't include names or "
    'contact details.';

/// The failure of a work action as an inline banner: a rule block (P1, P2, P6,
/// P7, P8 ...) shows its messages; a failed write shows a friendly sentence
/// with Retry (screens-spec G-4).
class WorkFailureBanner extends StatelessWidget {
  const WorkFailureBanner({
    super.key,
    required this.state,
    required this.title,
    required this.onRetry,
  });

  final WorkActionState state;
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

/// The sticky bottom bar of a work screen: its [children] stacked, separated
/// from the content by a hairline. Nothing when there is nothing to show.
class WorkActionBar extends StatelessWidget {
  const WorkActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpace.s3),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section title of a work form.
class WorkSectionTitle extends StatelessWidget {
  const WorkSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
