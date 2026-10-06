import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens/icon_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/semantic_tokens.dart';

/// Size of a [CategoryChip] (contract 6.1: icon size inside chip size).
enum CategoryChipSize {
  /// 24 chip, icon 16 (cards, table rows).
  s24(24, 16),

  /// 32 chip, icon 20 (default).
  s32(32, 20),

  /// 40 chip, icon 24 (tiles).
  s40(40, 24),

  /// 48 chip, icon 24 (large).
  s48(48, 24);

  const CategoryChipSize(this.chip, this.icon);

  /// Chip edge in logical pixels.
  final double chip;

  /// Icon size inside the chip.
  final double icon;

  /// Radius: `r3` up to 32, `r4` above (contract 5.1 shape rule).
  BorderRadius get radius => chip <= 32 ? AppRadius.br3 : AppRadius.br4;
}

/// A rounded square holding the category glyph, in the category `bg` / `fg`
/// (contract 2.5, 6.1). Category colour appears only here and in charts. The
/// chip is decorative: the category label is always printed next to it.
class CategoryChip extends StatelessWidget {
  /// Creates a chip for [category].
  const CategoryChip({
    super.key,
    required this.category,
    this.size = CategoryChipSize.s32,
  });

  /// The category to show.
  final ProblemCategory category;

  /// Chip size.
  final CategoryChipSize size;

  @override
  Widget build(BuildContext context) {
    final CategoryStyle style = context.categoryStyle(category);
    return ExcludeSemantics(
      child: Container(
        width: size.chip,
        height: size.chip,
        decoration: BoxDecoration(color: style.bg, borderRadius: size.radius),
        alignment: Alignment.center,
        child: Icon(
          AppCategoryIcons.of(category),
          size: size.icon,
          color: style.fg,
        ),
      ),
    );
  }
}
