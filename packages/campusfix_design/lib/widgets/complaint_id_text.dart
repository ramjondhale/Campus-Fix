import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_typography.dart';
import 'app_toast.dart';
import 'support/app_pressable.dart';
import 'support/context_ext.dart';

/// Size of a [ComplaintIdText] (contract 8.9).
enum ComplaintIdSize {
  /// `mono-sm`, `onSurfaceVariant`: cards and dense rows.
  sm,

  /// `mono-md`, `onSurface`: detail headers and table cells.
  md,

  /// `mono-lg`, `onSurface`: the M-08 confirmation.
  lg,
}

/// A complaint ID in JetBrains Mono, exactly as stored (`CF-YYYY-NNNNN`)
/// (contract 8.9). It never wraps or truncates.
///
/// [copyable] defaults to true for `md` and `lg` (detail headers, M-08): a
/// tap copies the ID to the clipboard, shows the toast "Copied CF-2026-00042"
/// and calls [onCopied]. The tap target is at least 48 high.
class ComplaintIdText extends StatelessWidget {
  /// Creates the ID text for [id].
  const ComplaintIdText({
    super.key,
    required this.id,
    this.size = ComplaintIdSize.sm,
    this.copyable,
    this.showToast = true,
    this.onCopied,
  });

  /// The complaint ID, rendered exactly as given.
  final String id;

  /// Text size.
  final ComplaintIdSize size;

  /// Whether a tap copies the ID. Defaults to `size != sm`.
  final bool? copyable;

  /// Whether copying shows the "Copied ..." toast.
  final bool showToast;

  /// Called after the ID was copied.
  final VoidCallback? onCopied;

  bool get _copyable => copyable ?? size != ComplaintIdSize.sm;

  TextStyle _style(BuildContext context) {
    final TextStyle base = switch (size) {
      ComplaintIdSize.sm => AppTypography.monoSmall,
      ComplaintIdSize.md => AppTypography.monoMedium,
      ComplaintIdSize.lg => AppTypography.monoLarge,
    };
    final Color color = size == ComplaintIdSize.sm
        ? context.colorScheme.onSurfaceVariant
        : context.colorScheme.onSurface;
    return base.copyWith(color: color);
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    if (showToast) {
      AppToast.show(context, 'Copied $id', kind: AppToastKind.success);
    }
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Text text = Text(
      id,
      style: _style(context),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
    if (!_copyable) {
      return Semantics(
        label: 'Complaint ID $id',
        excludeSemantics: true,
        child: text,
      );
    }
    final Color icon = context.colorScheme.onSurfaceVariant;
    return AppPressable(
      semanticLabel: 'Complaint ID $id. Copy',
      onTap: () => _copy(context),
      builder: (BuildContext context, Set<WidgetState> states) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              text,
              const SizedBox(width: 8),
              Icon(Icons.content_copy, size: 20, color: icon),
            ],
          ),
        );
      },
    );
  }
}
