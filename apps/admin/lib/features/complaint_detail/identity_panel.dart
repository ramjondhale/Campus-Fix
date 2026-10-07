// The reporter-identity reveal panel of A-04 (screens-spec A-04, privacy-spec
// PV-4 / PV-5 / LK-8).
//
// **This is the only file in the admin app that reads the reporter.** Core's
// PR-T14 guard and the admin architecture guard allow `ReporterIdentity` /
// `.reporter` here and nowhere else. The panel exists only for an admin: the
// detail screen builds it from an `AdminComplaintView`, which only an admin
// can get, so a verifier has no identity panel at all (AC-52).
//
// **Reveal UX (LK-8).**
//
// * Collapsed by default. While collapsed the identity is not even built into
//   the widget tree, so the page text carries none of it (AC-51).
// * Revealing is an explicit click on **Reveal reporter identity**, under a
//   one-line reminder.
// * It re-collapses on navigation (the panel's state dies with the screen, and
//   a different complaint starts collapsed too) and on sign-out / a change of
//   the signed-in user.
// * No export, no copy-all. The identity is never put in the page title or the
//   URL (the route carries the complaint ID only).
//
// Phase 2 will write an audit entry on reveal (privacy-spec section 9); v1 has
// no audit store, so this is the gated UI only.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../dashboard/dashboard_layout.dart' show DashboardPanel;

/// The one-line reminder shown above the reveal action (LK-8).
const String kIdentityReminder =
    'Reporter details are confidential. Reveal them only when you need to '
    'contact or identify the reporter.';

/// The reporter-identity panel of [view]: collapsed until the admin reveals it.
class IdentityPanel extends ConsumerStatefulWidget {
  const IdentityPanel({super.key, required this.view});

  /// The admin view of the complaint whose reporter this panel can reveal.
  final AdminComplaintView view;

  @override
  ConsumerState<IdentityPanel> createState() => _IdentityPanelState();
}

class _IdentityPanelState extends ConsumerState<IdentityPanel> {
  bool _revealed = false;

  @override
  void didUpdateWidget(IdentityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another complaint in the same screen starts collapsed (LK-8).
    if (oldWidget.view.id != widget.view.id) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    // Sign-out, or another user signing in, hides the identity again.
    ref.listen<AppUser?>(sessionProvider, (AppUser? previous, AppUser? next) {
      if (previous?.id != next?.id && _revealed) {
        setState(() => _revealed = false);
      }
    });

    return DashboardPanel(
      title: 'Reporter identity',
      subtitle: _revealed ? null : kIdentityReminder,
      actionLabel: _revealed ? 'Hide' : null,
      onAction: _revealed ? () => setState(() => _revealed = false) : null,
      child: _revealed
          ? _RevealedIdentity(identity: widget.view.reporter)
          : _CollapsedIdentity(
              onReveal: () => setState(() => _revealed = true),
            ),
    );
  }
}

class _CollapsedIdentity extends StatelessWidget {
  const _CollapsedIdentity({required this.onReveal});

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const AdminOnlyTag(),
        AppButton(
          label: 'Reveal reporter identity',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          leadingIcon: Icons.visibility_outlined,
          onPressed: onReveal,
        ),
      ],
    );
  }
}

class _RevealedIdentity extends StatelessWidget {
  const _RevealedIdentity({required this.identity});

  final ReporterIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            UserAvatar(
              initials: UserAvatar.initialsOf(identity.fullName),
              semanticLabel: 'Reporter',
            ),
            const SizedBox(width: AppSpace.s3),
            const AdminOnlyTag(),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        _IdentityRow(label: 'Full name', value: identity.fullName),
        _IdentityRow(label: 'ID number', value: identity.idNumber),
        _IdentityRow(label: 'Email', value: identity.email),
        _IdentityRow(
          label: 'Phone',
          value: identity.phone ?? 'Not provided',
          last: true,
        ),
      ],
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
