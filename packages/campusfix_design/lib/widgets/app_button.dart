import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/motion_tokens.dart';
import '../theme/tokens/radius_tokens.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// Visual variant of an [AppButton] (contract 8.1).
enum AppButtonVariant {
  /// Filled `primary`. One per screen region.
  primary,

  /// Transparent with a 1 px `outline` border and `primary` label.
  secondary,

  /// Transparent, no border, `primary` label.
  tertiary,

  /// Filled `error`. Only for rejecting, discarding or deleting, behind a
  /// confirm dialog.
  destructive,

  /// Transparent with a 1 px `error` border and `error` label.
  destructiveOutlined,
}

/// Size of an [AppButton] (contract 8.1).
enum AppButtonSize {
  /// 48 high: mobile primary action, may be full width.
  lg(48, 24),

  /// 40 high: default.
  md(40, 20),

  /// 32 high: dense admin toolbars.
  sm(32, 12);

  const AppButtonSize(this.height, this.padding);

  /// Button height.
  final double height;

  /// Horizontal padding (tertiary always uses 12).
  final double padding;
}

/// The CampusFix button (contract 8.1): primary, secondary, tertiary,
/// destructive and destructive outlined, in `lg`, `md` and `sm`, with
/// default, hover, pressed, focus, disabled and loading states.
///
/// Labels are verbs ("Submit", "Mark as resolved"), never "OK". A null
/// [onPressed] disables the button. While [loading] the button keeps its
/// size, hides the label, shows an 18 px spinner and ignores taps.
class AppButton extends StatelessWidget {
  /// Creates a button.
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
  });

  /// Visible label (a verb).
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Variant.
  final AppButtonVariant variant;

  /// Size.
  final AppButtonSize size;

  /// Optional leading icon (20, or 16 in `sm`).
  final IconData? leadingIcon;

  /// Loading state: spinner in the label colour, width preserved, taps
  /// ignored.
  final bool loading;

  /// Fills the available width (mobile primary action).
  final bool expand;

  /// Overrides the semantics label (defaults to [label]).
  final String? semanticLabel;

  static const double _spinner = 18;
  static const double _minWidth = 64;

  bool get _filled =>
      variant == AppButtonVariant.primary ||
      variant == AppButtonVariant.destructive;

  Color _foreground(ColorScheme scheme) => switch (variant) {
    AppButtonVariant.primary => scheme.onPrimary,
    AppButtonVariant.secondary || AppButtonVariant.tertiary => scheme.primary,
    AppButtonVariant.destructive => scheme.onError,
    AppButtonVariant.destructiveOutlined => scheme.error,
  };

  Color _fill(ColorScheme scheme, CampusColors colors, Set<WidgetState> s) {
    if (s.contains(WidgetState.disabled)) {
      return _filled
          ? scheme.onSurface.withValues(alpha: AppStateLayer.disabledContainer)
          : Colors.transparent;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        if (s.contains(WidgetState.pressed)) return colors.primaryPressed;
        if (s.contains(WidgetState.hovered)) return colors.primaryHover;
        return scheme.primary;
      case AppButtonVariant.destructive:
        if (s.contains(WidgetState.pressed)) {
          return Color.alphaBlend(
            scheme.onError.withValues(alpha: 0.22),
            scheme.error,
          );
        }
        if (s.contains(WidgetState.hovered)) {
          return Color.alphaBlend(
            scheme.onError.withValues(alpha: 0.12),
            scheme.error,
          );
        }
        return scheme.error;
      case AppButtonVariant.secondary:
      case AppButtonVariant.tertiary:
      case AppButtonVariant.destructiveOutlined:
        return applyStateLayer(Colors.transparent, _foreground(scheme), s);
    }
  }

  BorderSide _border(ColorScheme scheme, Set<WidgetState> s) {
    final bool disabled = s.contains(WidgetState.disabled);
    switch (variant) {
      case AppButtonVariant.secondary:
        return BorderSide(
          color: disabled
              ? scheme.onSurface.withValues(
                  alpha: AppStateLayer.disabledContainer,
                )
              : scheme.outline,
        );
      case AppButtonVariant.destructiveOutlined:
        return BorderSide(
          color: disabled
              ? scheme.onSurface.withValues(
                  alpha: AppStateLayer.disabledContainer,
                )
              : scheme.error,
        );
      case AppButtonVariant.primary:
      case AppButtonVariant.tertiary:
      case AppButtonVariant.destructive:
        return BorderSide.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final bool sm = size == AppButtonSize.sm;
    final BorderRadius radius = sm ? AppRadius.br3 : AppRadius.br4;
    final double horizontal = variant == AppButtonVariant.tertiary
        ? 12
        : size.padding;
    final double iconSize = sm ? 16 : 20;
    final TextStyle labelStyle = (sm
        ? context.textTheme.labelMedium
        : context.textTheme.labelLarge)!;

    return AppPressable(
      radius: radius,
      semanticLabel: loading
          ? '${semanticLabel ?? label}, loading'
          : (semanticLabel ?? label),
      // While loading taps are ignored but the button keeps its look.
      onTap: loading ? () {} : onPressed,
      builder: (BuildContext context, Set<WidgetState> states) {
        final bool disabled = states.contains(WidgetState.disabled);
        final Color foreground = disabled
            ? scheme.onSurface.withValues(alpha: AppStateLayer.disabledContent)
            : _foreground(scheme);
        final Widget content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (leadingIcon != null) ...<Widget>[
              Icon(leadingIcon, size: iconSize, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: labelStyle.copyWith(color: foreground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        );
        return Container(
          constraints: BoxConstraints(
            minWidth: _minWidth,
            minHeight: size.height,
          ),
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          decoration: BoxDecoration(
            color: _fill(scheme, colors, states),
            borderRadius: radius,
            border: _border(scheme, states) == BorderSide.none
                ? null
                : Border.fromBorderSide(_border(scheme, states)),
          ),
          // Centre without expanding: an `alignment` on the Container would
          // make the button fill the whole width it is offered.
          child: Center(
            widthFactor: 1,
            child: loading
                ? Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Opacity(opacity: 0, child: content),
                      SizedBox.square(
                        dimension: _spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      ),
                    ],
                  )
                : content,
          ),
        );
      },
    );
  }
}

/// An icon-only button with a 48 x 48 hit area, a tooltip and a semantics
/// label (contract 9 rule 5). Optional unread [badgeCount] / [showDot].
class AppIconButton extends StatelessWidget {
  /// Creates an icon button.
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
    this.badgeCount,
    this.showDot = false,
    this.color,
  });

  /// The glyph.
  final IconData icon;

  /// Tooltip and semantics label (required: icon-only controls need one).
  final String tooltip;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Icon size (24 default; 20 in dense rows).
  final double iconSize;

  /// Unread count shown in a badge ("99+" cap). Null or 0 shows no badge.
  final int? badgeCount;

  /// Shows a bare 8 px dot (unread without a count).
  final bool showDot;

  /// Icon colour; defaults to `onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final int count = badgeCount ?? 0;
    final String semantics = count > 0
        ? '$tooltip, $count unread'
        : (showDot ? '$tooltip, unread' : tooltip);
    return Tooltip(
      message: tooltip,
      child: AppPressable(
        radius: AppRadius.brFull,
        semanticLabel: semantics,
        onTap: onPressed,
        builder: (BuildContext context, Set<WidgetState> states) {
          final bool disabled = states.contains(WidgetState.disabled);
          final Color base = color ?? scheme.onSurface;
          final Color fg = disabled
              ? base.withValues(alpha: AppStateLayer.disabledContent)
              : base;
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: applyStateLayer(Colors.transparent, base, states),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(icon, size: iconSize, color: fg),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: CountBadge(count: count),
                  )
                else if (showDot)
                  const Positioned(top: -2, right: -2, child: DotBadge()),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A numeric badge: `error` fill, `onError` text `label-sm` 700, minimum 16
/// high, "99+" cap (contract 8.19).
class CountBadge extends StatelessWidget {
  /// Creates a badge for [count].
  const CountBadge({super.key, required this.count});

  /// The unread count.
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: AppRadius.brFull,
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: context.textTheme.labelSmall!.copyWith(
            color: scheme.onError,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// A bare 8 px `error` dot: unread without a count (contract 8.19).
class DotBadge extends StatelessWidget {
  /// Creates a dot badge.
  const DotBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: context.colorScheme.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
