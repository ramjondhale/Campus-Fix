import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import '../widgets/support/context_ext.dart';
import 'gallery_parts.dart';

/// Section 2 and 3 at a glance: the surface and brand colours and the type
/// scale, read from the theme so the swatches follow the light / dark toggle.
class TokensSection extends StatelessWidget {
  /// Creates the section.
  const TokensSection({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final TextTheme text = context.textTheme;
    final List<(String, Color, Color)> swatches = <(String, Color, Color)>[
      ('canvas', scheme.surface, scheme.onSurface),
      ('card', colors.card, scheme.onSurface),
      ('cardSubtle', colors.cardSubtle, scheme.onSurface),
      ('raised', colors.raised, scheme.onSurface),
      ('pressedFill', colors.pressedFill, scheme.onSurface),
      ('primary', scheme.primary, scheme.onPrimary),
      ('primaryContainer', scheme.primaryContainer, scheme.onPrimaryContainer),
      (
        'secondaryContainer',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ('error', scheme.error, scheme.onError),
      ('errorContainer', scheme.errorContainer, scheme.onErrorContainer),
      ('inverseSurface', scheme.inverseSurface, scheme.onInverseSurface),
    ];
    final List<(String, TextStyle)> scale = <(String, TextStyle)>[
      ('display-sm  Archivo 30/38 700', text.displaySmall!),
      ('headline-lg  Archivo 26/34 700', text.headlineLarge!),
      ('headline-sm  Archivo 20/28 600', text.headlineSmall!),
      ('title-lg  Archivo 18/26 600', text.titleLarge!),
      ('title-sm  Archivo 14/20 600', text.titleSmall!),
      ('body-lg  Public Sans 16/24 400', text.bodyLarge!),
      ('body-md  Public Sans 14/20 400', text.bodyMedium!),
      ('body-sm  Public Sans 12/16 400', text.bodySmall!),
      ('label-md  Archivo 12/16 600', text.labelMedium!),
      ('mono-md  JetBrains Mono 14/20 500', AppTypography.monoMedium),
    ];
    return GallerySection(
      id: '2-3',
      title: 'Colour and type',
      description:
          'Brand, surface roles and the type scale as the widgets consume '
          'them. Status, priority and category sets appear in their own '
          'components below.',
      children: <Widget>[
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: <Widget>[
            for (final (String, Color, Color) s in swatches)
              Container(
                width: 132,
                height: 64,
                padding: const EdgeInsets.all(AppSpace.s2),
                decoration: BoxDecoration(
                  color: s.$2,
                  borderRadius: AppRadius.br4,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  s.$1,
                  style: text.labelSmall!.copyWith(color: s.$3),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s5),
        for (final (String, TextStyle) row in scale)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(row.$1, style: row.$2),
          ),
      ],
    );
  }
}
