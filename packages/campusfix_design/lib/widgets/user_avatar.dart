import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/tokens/radius_tokens.dart';
import 'support/context_ext.dart';

/// Size of a [UserAvatar] (contract 8.23): 24, 32 or 40.
enum UserAvatarSize {
  /// 24 px, `label-sm` initials.
  s24(24),

  /// 32 px, `label-md` initials.
  s32(32),

  /// 40 px, `label-lg` initials.
  s40(40);

  const UserAvatarSize(this.edge);

  /// Diameter in logical pixels.
  final double edge;
}

/// A circular avatar with initials (contract 8.23): `secondaryContainer` fill,
/// `onSecondaryContainer` initials. No photos.
///
/// **Never use it on a board item, card, list row or maintenance screen.** It
/// belongs to the signed-in user's own header and menu and to admin-only
/// panels.
class UserAvatar extends StatelessWidget {
  /// Creates an avatar showing [initials] (one or two letters).
  const UserAvatar({
    super.key,
    required this.initials,
    this.size = UserAvatarSize.s32,
    this.semanticLabel,
  });

  /// One or two initials.
  final String initials;

  /// Avatar size.
  final UserAvatarSize size;

  /// Semantics label; the avatar is decorative when null.
  final String? semanticLabel;

  /// Initials of [name]: the first letters of its first two words, in upper
  /// case. Returns "?" for an empty name.
  static String initialsOf(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final String first = parts.first.substring(0, 1);
    final String second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final TextStyle style = switch (size) {
      UserAvatarSize.s24 => context.textTheme.labelSmall!,
      UserAvatarSize.s32 => context.textTheme.labelMedium!,
      UserAvatarSize.s40 => context.textTheme.labelLarge!,
    };
    final Widget avatar = Container(
      width: size.edge,
      height: size.edge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: style.copyWith(color: scheme.onSecondaryContainer),
        maxLines: 1,
        softWrap: false,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: avatar);
    return Semantics(label: semanticLabel, image: true, child: avatar);
  }
}

/// A role as a small rectangle (contract 8.23): height 22, radius `r2`, 1 px
/// `outlineVariant`, a role glyph 12 and the `label-sm` role label.
/// `admin` uses `primaryContainer` with `onPrimaryContainer` and no border.
///
/// A RolePill names a role, never a person; it is the only actor information
/// the public timeline shows.
class RolePill extends StatelessWidget {
  /// Creates a pill for [role].
  const RolePill({super.key, required this.role});

  /// The role to name.
  final UserRole role;

  /// The glyph of [role].
  static IconData iconFor(UserRole role) => switch (role) {
    UserRole.admin => Icons.admin_panel_settings_outlined,
    UserRole.maintenance => Icons.build_outlined,
    UserRole.verifier => Icons.fact_check_outlined,
    // The remaining role is the person who reports a problem.
    _ => Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool admin = role == UserRole.admin;
    final Color fg = admin
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Semantics(
      label: 'Role: ${role.label}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: admin ? scheme.primaryContainer : null,
          borderRadius: AppRadius.br2,
          border: admin ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(iconFor(role), size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              role.label,
              style: context.textTheme.labelSmall!.copyWith(color: fg),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
