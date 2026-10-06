import 'package:flutter/material.dart';

import '../../theme/theme_context.dart';
import '../../theme/tokens/motion_tokens.dart';
import '../../theme/tokens/radius_tokens.dart';

/// Builds the visual content of an [AppPressable] for the current widget
/// [states] (hovered, focused, pressed, disabled, selected).
typedef PressableBuilder =
    Widget Function(BuildContext context, Set<WidgetState> states);

/// Blends the hover or pressed state layer of [content] over [base]
/// (contract 7.2). [base] may be transparent.
///
/// Hover is 8% and pressed 12% unless overridden; disabled controls get no
/// feedback.
Color applyStateLayer(
  Color base,
  Color content,
  Set<WidgetState> states, {
  double hover = AppStateLayer.hover,
  double pressed = AppStateLayer.pressed,
}) {
  if (states.contains(WidgetState.disabled)) return base;
  if (states.contains(WidgetState.pressed)) {
    return Color.alphaBlend(content.withValues(alpha: pressed), base);
  }
  if (states.contains(WidgetState.hovered)) {
    return Color.alphaBlend(content.withValues(alpha: hover), base);
  }
  return base;
}

/// Draws the focus ring (contract 7.2): 2 px, 2 px outside the child, in
/// the `focusRing` colour. The ring never affects layout.
class FocusRing extends StatelessWidget {
  /// Creates a focus ring around [child]; it is drawn only when [visible].
  const FocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.radius = AppRadius.br4,
  });

  /// Whether the ring is drawn.
  final bool visible;

  /// Corner radius of the wrapped control; the ring grows it by the offset.
  final BorderRadius radius;

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const double inset =
        AppStateLayer.focusRingOffset + AppStateLayer.focusRingWidth;
    final BorderRadius outer = BorderRadius.only(
      topLeft: Radius.circular(radius.topLeft.x + inset),
      topRight: Radius.circular(radius.topRight.x + inset),
      bottomLeft: Radius.circular(radius.bottomLeft.x + inset),
      bottomRight: Radius.circular(radius.bottomRight.x + inset),
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        if (visible)
          Positioned(
            left: -inset,
            top: -inset,
            right: -inset,
            bottom: -inset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: outer,
                  border: Border.all(
                    color: context.campusColors.focusRing,
                    width: AppStateLayer.focusRingWidth,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A tappable, focusable, hoverable surface shared by every interactive
/// CampusFix widget.
///
/// It tracks the Material [WidgetState]s, draws the focus ring, activates on
/// Enter / Space, shows the click cursor and exposes button semantics. The
/// visual content comes from [builder], which receives the states and applies
/// the state layers itself (see [applyStateLayer]).
class AppPressable extends StatefulWidget {
  /// Creates a pressable surface.
  const AppPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.radius = AppRadius.br4,
    this.semanticLabel,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup = false,
    this.isButton = true,
    this.focusNode,
    this.autofocus = false,
  });

  /// Builds the content for the current states.
  final PressableBuilder builder;

  /// Called on tap, Enter or Space. A null callback disables the surface.
  final VoidCallback? onTap;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// False disables the surface regardless of [onTap].
  final bool enabled;

  /// Corner radius used for the focus ring.
  final BorderRadius radius;

  /// Replaces the descendants' semantics with this label when non-null.
  final String? semanticLabel;

  /// Selected state: adds [WidgetState.selected] and the semantics flag.
  final bool? selected;

  /// Checked semantics (radio / checkbox like controls).
  final bool? checked;

  /// Toggled semantics (switch like controls).
  final bool? toggled;

  /// Semantics: the control belongs to a mutually exclusive group (radio).
  final bool inMutuallyExclusiveGroup;

  /// Semantics: whether this is announced as a button.
  final bool isButton;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus on first build.
  final bool autofocus;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onTap != null;

  void _set(void Function() change) {
    if (mounted) setState(change);
  }

  @override
  void didUpdateWidget(AppPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && (_pressed || _hovered)) {
      _pressed = false;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    final Set<WidgetState> states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (enabled && _hovered) WidgetState.hovered,
      if (enabled && _focused) WidgetState.focused,
      if (enabled && _pressed) WidgetState.pressed,
      if (widget.selected ?? false) WidgetState.selected,
    };

    Widget content = FocusRing(
      visible: enabled && _focused,
      radius: widget.radius,
      child: widget.builder(context, states),
    );

    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? widget.onTap : null,
      onLongPress: enabled ? widget.onLongPress : null,
      onTapDown: enabled ? (_) => _set(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => _set(() => _pressed = false) : null,
      onTapCancel: enabled ? () => _set(() => _pressed = false) : null,
      child: content,
    );

    content = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (bool v) => _set(() => _hovered = v),
      onShowFocusHighlight: (bool v) => _set(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: content,
    );

    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: enabled ? widget.onTap : null,
      child: content,
    );
  }
}
