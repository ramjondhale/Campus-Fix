import 'package:flutter/material.dart';

import '../theme/extensions/campus_colors.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/radius_tokens.dart';
import '../theme/tokens/spacing_tokens.dart';
import 'support/context_ext.dart';

/// The CampusFix search field (contract 8.4): 40 high (48 hit area on
/// mobile), radius `r4`, fill `cardSubtle`, no border until hover
/// (`outline`) or focus (2 px `primary`). Leading `search` 20, trailing clear
/// button when there is text, text `body-md`.
///
/// The default placeholder names only public searchable fields; there is no
/// reporter-based search (PV-5).
class AppSearchField extends StatefulWidget {
  /// Creates a search field.
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = defaultHint,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  /// "Search by ID, description or location".
  static const String defaultHint = 'Search by ID, description or location';

  /// Text controller.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Placeholder.
  final String hintText;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits.
  final ValueChanged<String>? onSubmitted;

  /// Disabled state.
  final bool enabled;

  /// Whether to autofocus.
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;
  FocusNode? _ownFocus;
  bool _hovered = false;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'AppSearch'));

  @override
  void dispose() {
    _own?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final CampusColors colors = context.campusColors;
    final BorderSide side = _focused
        ? BorderSide(color: scheme.primary, width: 2)
        : (_hovered && widget.enabled
              ? BorderSide(color: scheme.outline)
              : const BorderSide(width: 0, style: BorderStyle.none));
    final bool compact = context.windowClass == AppWindowClass.compact;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 48 : 40),
      child: Center(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Focus(
            skipTraversal: true,
            onFocusChange: (bool v) => setState(() => _focused = v),
            child: Container(
              height: AppLayout.controlHeightAdmin,
              padding: const EdgeInsets.only(left: AppSpace.s3),
              decoration: BoxDecoration(
                color: colors.cardSubtle,
                borderRadius: AppRadius.br4,
                border: side.style == BorderStyle.none
                    ? null
                    : Border.fromBorderSide(side),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      enabled: widget.enabled,
                      style: context.textTheme.bodyMedium,
                      cursorColor: scheme.primary,
                      textInputAction: TextInputAction.search,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hintText,
                        hintStyle: context.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (BuildContext context, TextEditingValue v, _) {
                      if (v.text.isEmpty || !widget.enabled) {
                        return const SizedBox(width: AppSpace.s3);
                      }
                      return IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clear,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        icon: const Icon(Icons.close),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
