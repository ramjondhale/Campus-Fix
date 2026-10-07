import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/errors/error_screens.dart';
import '../providers/providers.dart';

/// Shows [child] only to the [roles] that may open it; any other signed-in
/// role gets the E-403 "You don't have access to this page" screen with a
/// Sign out action (screens-spec G-2, AC-45). The router already sends such a
/// role to E-403 and signed-out users to Login; this guard is the second line
/// that keeps a console screen from ever being built for the wrong role.
class RoleGuard extends ConsumerWidget {
  const RoleGuard({super.key, required this.roles, required this.child});

  final Set<UserRole> roles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    if (!roles.contains(user.role)) return const NotAuthorizedScreen();
    return child;
  }
}
