// The header of A-04 (screens-spec A-04, "Header"): the complaint ID, its
// status, the **effective** priority (with the Overridden marker for an
// admin), the category, the location and the dates. Public data only: the
// override marker is a flag, not identity.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// The header block of the detail screen.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.complaint,
    required this.now,
    this.overridden = false,
  });

  final PublicComplaintView complaint;

  /// The console clock (the Waiting figure is measured against it).
  final DateTime now;

  /// Whether the effective priority is an admin override (admin form only).
  final bool overridden;

  @override
  Widget build(BuildContext context) {
    final PublicComplaintView c = complaint;
    final ThemeData theme = Theme.of(context);
    final TextStyle meta = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bool unresolved = c.status.order < ComplaintStatus.resolved.order;
    final Duration waited = now.difference(c.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpace.s3,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ComplaintIdText(id: c.id, size: ComplaintIdSize.md),
            StatusBadge(status: c.status),
            PriorityTag(priority: c.effectivePriority, overridden: overridden),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Row(
          children: <Widget>[
            CategoryChip(category: c.category),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  c.title ?? c.category.label,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Wrap(
          spacing: AppSpace.s5,
          runSpacing: AppSpace.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.place_outlined,
                  size: AppIconSize.s16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpace.s1),
                Text(
                  ComplaintCard.locationOf(c),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            Text('Created ${formatAbsoluteTime(c.createdAt)}', style: meta),
            Text('Updated ${formatAbsoluteTime(c.updatedAt)}', style: meta),
            if (unresolved)
              Text(
                'Waiting ${formatWaiting(waited.isNegative ? Duration.zero : waited)}',
                style: meta,
              ),
          ],
        ),
      ],
    );
  }
}
