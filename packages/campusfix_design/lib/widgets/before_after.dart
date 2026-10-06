import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'complaint_photo.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// Variant of a [BeforeAfter] comparator (contract 8.13).
enum BeforeAfterVariant {
  /// One 4:3 frame; the After photo is clipped from a draggable divider to
  /// the right edge.
  slider,

  /// Two 4:3 panes side by side (stacked below 320 px) with captions: the
  /// no-drag alternative.
  split,
}

/// The Before / After comparator (contract 8.13): M-10, M-17, A-04.
///
/// Max width 520 (full width on mobile), 4:3, radius `r4`, 1 px
/// `outlineVariant`. The `slider` variant is a keyboard slider: left and
/// right move 5%, with Shift 20%, Home 2% and End 98%; pointer drag anywhere
/// moves the divider; semantics are `slider` with a value from 0 to 100.
/// Several After photos show as a thumbnail strip under the comparator;
/// tapping one swaps it in. Photos render as drawn [ComplaintPhoto]
/// placeholders tinted by [category].
class BeforeAfter extends StatefulWidget {
  /// Creates a comparator. [after] must not be empty.
  const BeforeAfter({
    super.key,
    required this.category,
    required this.before,
    required this.after,
    this.variant = BeforeAfterVariant.slider,
    this.initialPosition = 0.5,
  }) : assert(after.length > 0, 'BeforeAfter needs at least one after photo');

  /// Category used to tint the placeholders.
  final ProblemCategory category;

  /// The reporter's before photo.
  final Attachment before;

  /// The maintenance after photo(s).
  final List<Attachment> after;

  /// Comparator variant.
  final BeforeAfterVariant variant;

  /// Initial divider position from 0 (left) to 1 (right).
  final double initialPosition;

  /// Maximum width of the comparator.
  static const double maxWidth = 520;

  @override
  State<BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<BeforeAfter> {
  static const double _min = 0.02;
  static const double _max = 0.98;

  late double _position = widget.initialPosition.clamp(_min, _max);
  int _afterIndex = 0;

  void _move(double value) =>
      setState(() => _position = value.clamp(_min, _max));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    final double step = shift ? 0.2 : 0.05;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(_position - step);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(_position + step);
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _move(_min);
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _move(_max);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final Attachment after = widget.after[_afterIndex];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BeforeAfter.maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.variant == BeforeAfterVariant.slider)
            _SliderFrame(
              category: widget.category,
              before: widget.before,
              after: after,
              position: _position,
              onMove: _move,
              onKey: _onKey,
            )
          else
            _SplitFrame(
              category: widget.category,
              before: widget.before,
              after: after,
            ),
          if (widget.after.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: <Widget>[
                  for (int i = 0; i < widget.after.length; i++)
                    PhotoThumbnail(
                      category: widget.category,
                      attachment: widget.after[i],
                      size: PhotoThumbnailSize.s56,
                      selected: i == _afterIndex,
                      onTap: () => setState(() => _afterIndex = i),
                      semanticLabel:
                          'After photo ${i + 1} of ${widget.after.length}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: AppRadius.br4,
          border: Border.all(color: context.colorScheme.outlineVariant),
        ),
        child: ClipRRect(borderRadius: AppRadius.br4, child: child),
      ),
    );
  }
}

class _SliderFrame extends StatelessWidget {
  const _SliderFrame({
    required this.category,
    required this.before,
    required this.after,
    required this.position,
    required this.onMove,
    required this.onKey,
  });

  final ProblemCategory category;
  final Attachment before;
  final Attachment after;
  final double position;
  final ValueChanged<double> onMove;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;

  @override
  Widget build(BuildContext context) {
    final CampusColors colors = context.campusColors;
    final int percent = (position * 100).round();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        double fromLocal(Offset local) => local.dx / width;
        return Semantics(
          container: true,
          slider: true,
          label: 'Before and after comparison',
          value: '$percent',
          increasedValue: '${(percent + 5).clamp(2, 98)}',
          decreasedValue: '${(percent - 5).clamp(2, 98)}',
          onIncrease: () => onMove(position + 0.05),
          onDecrease: () => onMove(position - 0.05),
          child: _SliderFocus(
            onKey: onKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails d) =>
                  onMove(fromLocal(d.localPosition)),
              onHorizontalDragUpdate: (DragUpdateDetails d) =>
                  onMove(fromLocal(d.localPosition)),
              child: _Frame(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ComplaintPhoto(category: category, attachment: before),
                    ClipRect(
                      clipper: _RightOf(position),
                      child: ComplaintPhoto(
                        category: category,
                        attachment: after,
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: ExcludeSemantics(
                        child: PhotoKindLabel(label: 'BEFORE', big: true),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: ExcludeSemantics(
                        child: PhotoKindLabel(label: 'AFTER', big: true),
                      ),
                    ),
                    Positioned(
                      left: position * width - 20,
                      top: 0,
                      bottom: 0,
                      width: 40,
                      child: _Divider(colors: colors),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliderFocus extends StatefulWidget {
  const _SliderFocus({required this.child, required this.onKey});

  final Widget child;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;

  @override
  State<_SliderFocus> createState() => _SliderFocusState();
}

class _SliderFocusState extends State<_SliderFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: widget.onKey,
      onFocusChange: (bool v) => setState(() => _focused = v),
      child: FocusRing(visible: _focused, child: widget.child),
    );
  }
}

class _RightOf extends CustomClipper<Rect> {
  const _RightOf(this.position);

  final double position;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * position, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightOf old) => old.position != position;
}

/// The divider: 2 px white line with a 1 px dark halo and a 40 px white
/// knob with two chevrons (contract 8.13).
class _Divider extends StatelessWidget {
  const _Divider({required this.colors});

  final CampusColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: 2,
          decoration: BoxDecoration(
            color: colors.photoOverlayForeground,
            boxShadow: <BoxShadow>[
              BoxShadow(color: colors.photoOverlayBackground, spreadRadius: 1),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.photoOverlayForeground,
            border: Border.all(color: colors.photoOverlayBackground),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.chevron_left,
                size: 16,
                color: colors.photoOverlayBackground,
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.photoOverlayBackground,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitFrame extends StatelessWidget {
  const _SplitFrame({
    required this.category,
    required this.before,
    required this.after,
  });

  final ProblemCategory category;
  final Attachment before;
  final Attachment after;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    Widget pane(Attachment a, String caption) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PhotoThumbnail(
          category: category,
          attachment: a,
          size: PhotoThumbnailSize.ratio43,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s1),
          child: Text(
            caption,
            style: context.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget first = pane(before, 'Added with the report');
        final Widget second = pane(after, 'Added when resolved');
        if (constraints.maxWidth < 320) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[first, const SizedBox(height: 8), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 8),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
