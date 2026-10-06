import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'app_button.dart';
import 'support/context_ext.dart';

/// Tone of an [EmptyState] icon tile.
enum EmptyStateTone {
  /// `cardSubtle` tile with an `onSurfaceVariant` glyph.
  neutral,

  /// `errorContainer` tile with an `onErrorContainer` glyph.
  error,
}

/// The empty, filtered-empty, error and not-found states of a list or page
/// (contract 8.17).
///
/// A vertical stack (gap 8, padding 32 x 16, max width 360): a 64 icon tile
/// (`r5`, icon 32), the title (`title-lg`), the body (`body-md` in
/// `onSurfaceVariant`) and one action. Centred on mobile, [alignment]
/// `start` inside admin tables. The named constructors carry the contract's
/// default icon, title and action label for each variant.
///
/// E-404 never reveals whether an ID exists (G-6): [EmptyState.notFound]
/// says "We couldn't find that complaint" for any missing or forbidden ID.
class EmptyState extends StatelessWidget {
  /// Creates a custom empty state.
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionVariant = AppButtonVariant.primary,
    this.tone = EmptyStateTone.neutral,
    this.alignment = CrossAxisAlignment.center,
  });

  /// "You haven't reported anything yet" with a clear next step.
  const EmptyState.nothing({
    Key? key,
    String title = "You haven't reported anything yet",
    String? message = 'Problems you report will show up here.',
    String? actionLabel,
    VoidCallback? onAction,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) : this(
         key: key,
         icon: Icons.inbox_outlined,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         alignment: alignment,
       );

  /// "No matching complaints" with a Clear filters action.
  const EmptyState.filtered({
    Key? key,
    String title = 'No matching complaints',
    String? message = 'Try removing a filter or searching for something else.',
    String? actionLabel = 'Clear filters',
    VoidCallback? onAction,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) : this(
         key: key,
         icon: Icons.filter_list,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         actionVariant: AppButtonVariant.secondary,
         alignment: alignment,
       );

  /// "Couldn't load complaints" with a Retry action.
  const EmptyState.error({
    Key? key,
    String title = "Couldn't load complaints",
    String? message = 'Check your connection and try again.',
    String? actionLabel = 'Retry',
    VoidCallback? onAction,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) : this(
         key: key,
         icon: Icons.warning_amber,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         actionVariant: AppButtonVariant.secondary,
         tone: EmptyStateTone.error,
         alignment: alignment,
       );

  /// E-404: "We couldn't find that complaint" with a Go home action.
  const EmptyState.notFound({
    Key? key,
    String title = "We couldn't find that complaint",
    String? message = 'It may have been removed, or the link may be wrong.',
    String? actionLabel = 'Go home',
    VoidCallback? onAction,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) : this(
         key: key,
         icon: Icons.search_off,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         alignment: alignment,
       );

  /// E-403: "You don't have access to this page" with a Go home action.
  const EmptyState.forbidden({
    Key? key,
    String title = "You don't have access to this page",
    String? message = 'Switch to an account that can open it.',
    String? actionLabel = 'Go home',
    VoidCallback? onAction,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) : this(
         key: key,
         icon: Icons.search_off,
         title: title,
         message: message,
         actionLabel: actionLabel,
         onAction: onAction,
         alignment: alignment,
       );

  /// Glyph in the icon tile.
  final IconData icon;

  /// Title.
  final String title;

  /// Body text.
  final String? message;

  /// Action button label; null hides the action.
  final String? actionLabel;

  /// Action callback. The action is shown only when both [actionLabel] and
  /// this callback are set (a dead button is never rendered).
  final VoidCallback? onAction;

  /// Variant of the action button.
  final AppButtonVariant actionVariant;

  /// Icon tile tone.
  final EmptyStateTone tone;

  /// `center` on mobile; `start` inside admin tables.
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool error = tone == EmptyStateTone.error;
    final TextAlign textAlign = alignment == CrossAxisAlignment.center
        ? TextAlign.center
        : TextAlign.start;
    return Align(
      alignment: alignment == CrossAxisAlignment.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: alignment,
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: error ? scheme.errorContainer : colors.cardSubtle,
                    borderRadius: AppRadius.br5,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 32,
                    color: error
                        ? scheme.onErrorContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: textAlign,
                  style: context.textTheme.titleLarge,
                ),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpace.s2),
                Text(
                  message!,
                  textAlign: textAlign,
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpace.s4),
                AppButton(
                  label: actionLabel!,
                  variant: actionVariant,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
