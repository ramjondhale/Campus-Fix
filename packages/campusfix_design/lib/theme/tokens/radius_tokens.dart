import 'package:flutter/painting.dart';

/// Corner radii (contract 5.1). Doubles are `rN`; matching `BorderRadius`
/// values are `brN`.
///
/// Shape rule: status = pill (`full`), priority = rectangle (`r2`), category =
/// rounded square (`r3` or `r4`), cards and fields = `r4`, dialogs and
/// tiles = `r5`.
abstract final class AppRadius {
  /// Table cells, full-bleed images.
  static const double r0 = 0;

  /// Progress segments, tiny marks.
  static const double r1 = 2;

  /// PriorityTag, role pill, banner tag.
  static const double r2 = 4;

  /// Small buttons, menu items.
  static const double r3 = 6;

  /// Buttons, fields, cards, chips, thumbnails.
  static const double r4 = 8;

  /// Dialogs, tiles, CategoryTile.
  static const double r5 = 12;

  /// Bottom sheet top corners.
  static const double r6 = 16;

  /// StatusBadge, avatar, switch, badge.
  static const double full = 999;

  /// [r0] as a [BorderRadius].
  static const BorderRadius br0 = BorderRadius.all(Radius.circular(r0));

  /// [r1] as a [BorderRadius].
  static const BorderRadius br1 = BorderRadius.all(Radius.circular(r1));

  /// [r2] as a [BorderRadius].
  static const BorderRadius br2 = BorderRadius.all(Radius.circular(r2));

  /// [r3] as a [BorderRadius].
  static const BorderRadius br3 = BorderRadius.all(Radius.circular(r3));

  /// [r4] as a [BorderRadius].
  static const BorderRadius br4 = BorderRadius.all(Radius.circular(r4));

  /// [r5] as a [BorderRadius].
  static const BorderRadius br5 = BorderRadius.all(Radius.circular(r5));

  /// [r6] as a [BorderRadius].
  static const BorderRadius br6 = BorderRadius.all(Radius.circular(r6));

  /// [full] as a [BorderRadius] (pill).
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));

  /// Bottom sheet shape: [r6] on the top corners only.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(r6),
  );

  /// Every radius keyed by its contract name (Appendix A `radii`).
  static const Map<String, double> byToken = <String, double>{
    'r0': r0,
    'r1': r1,
    'r2': r2,
    'r3': r3,
    'r4': r4,
    'r5': r5,
    'r6': r6,
    'full': full,
  };
}
