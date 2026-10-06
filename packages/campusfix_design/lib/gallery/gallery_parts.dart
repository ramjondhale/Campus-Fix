import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import '../widgets/support/context_ext.dart';

/// A titled gallery section (design contract section 8 heading and a short
/// description), followed by its [children].
class GallerySection extends StatelessWidget {
  /// Creates a section.
  const GallerySection({
    super.key,
    required this.id,
    required this.title,
    required this.children,
    this.description,
  });

  /// Contract section number ("8.1").
  final String id;

  /// Section title.
  final String title;

  /// One-line description.
  final String? description;

  /// Section content.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: AppSpace.s6),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$id  ',
                    style: context.textTheme.labelLarge!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(text: title),
                ],
              ),
              style: context.textTheme.headlineMedium,
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: Text(
                description!,
                style: context.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s5),
          ...children,
        ],
      ),
    );
  }
}

/// A caption above one demo ("Default", "Disabled", "Error").
class GalleryLabel extends StatelessWidget {
  /// Creates a labelled demo cell.
  const GalleryLabel(this.label, {super.key, required this.child, this.width});

  /// The caption.
  final String label;

  /// The demo.
  final Widget child;

  /// Optional fixed width of the cell.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Widget cell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: Text(
            label,
            style: context.textTheme.labelSmall!.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        child,
      ],
    );
    return width == null ? cell : SizedBox(width: width, child: cell);
  }
}

/// A wrapping row of demo cells.
class GalleryWrap extends StatelessWidget {
  /// Creates a wrapping row.
  const GalleryWrap({super.key, required this.children, this.spacing = 24});

  /// The cells.
  final List<Widget> children;

  /// Gap between cells.
  final double spacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s5),
    child: Wrap(
      spacing: spacing,
      runSpacing: AppSpace.s5,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: children,
    ),
  );
}

/// A 360 wide "phone" frame: the width the mobile components are specified
/// against.
class GalleryPhone extends StatelessWidget {
  /// Creates a phone-width frame around [child].
  const GalleryPhone({super.key, required this.child, this.padding = true});

  /// The mobile content.
  final Widget child;

  /// Adds the 16 px screen gutter.
  final bool padding;

  /// The phone width.
  static const double width = 360;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Container(
      width: width,
      padding: padding ? const EdgeInsets.all(AppSpace.s4) : null,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.br5,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// A frame for admin-width components.
class GalleryPanel extends StatelessWidget {
  /// Creates an admin panel frame.
  const GalleryPanel({super.key, required this.child, this.padding = true});

  /// The admin content.
  final Widget child;

  /// Adds 24 px padding.
  final bool padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    return Container(
      padding: padding ? const EdgeInsets.all(AppSpace.s6) : null,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.br4,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
