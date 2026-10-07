import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/complaint_detail/complaint_detail_screen.dart';
import '../features/complaints/complaint_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/errors/error_screens.dart';
import '../features/login/login_screen.dart';
import '../providers/providers.dart';
import '../shell/admin_shell.dart';
import 'role_guard.dart';
import 'routes.dart';

/// The query parameter that remembers the route a signed-out user asked for,
/// so login can return there (screens-spec G-1).
const String kReturnToParam = 'from';

/// The auth + role redirect (screens-spec G-1, G-2).
///
/// * Signed out, anywhere but Login -> Login, remembering the requested route.
/// * Signed in with a role the console has no screens for (reporter,
///   maintenance) -> E-403, wherever they go (AC-45).
/// * Signed in (admin or verifier) on Login, `/` or E-403 -> the requested
///   route if the role may open it, otherwise the dashboard.
/// * Anything else stays where it is.
String? appRedirect(AppUser? user, GoRouterState state) {
  final String location = state.matchedLocation;
  final bool atLogin = location == AppRoutes.login;
  if (user == null) {
    if (atLogin) return null;
    final String requested = state.uri.toString();
    if (requested == '/' ||
        requested == AppRoutes.dashboard ||
        requested == AppRoutes.forbidden) {
      return AppRoutes.login;
    }
    return Uri(
      path: AppRoutes.login,
      queryParameters: <String, String>{kReturnToParam: requested},
    ).toString();
  }
  if (!mayUseConsole(user.role)) {
    return location == AppRoutes.forbidden ? null : AppRoutes.forbidden;
  }
  if (atLogin || location == '/' || location == AppRoutes.forbidden) {
    final String? from = state.uri.queryParameters[kReturnToParam];
    if (from != null && roleMayOpen(user.role, from)) return from;
    return homeFor(user.role);
  }
  return null;
}

Widget _guard(Widget child) => RoleGuard(roles: kConsoleRoles, child: child);

/// The console's router. It follows the session: a change of the signed-in
/// user re-runs [appRedirect], so signing in and out navigate by themselves.
///
/// The three console screens (dashboard, list, detail) live in a
/// [ShellRoute] whose [AdminShell] adds the side navigation and the top bar,
/// so the detail opens inside the shell, next to the nav. Login and E-403 are
/// full-window pages outside it.
final appRouterProvider = Provider<GoRouter>((ref) {
  final ValueNotifier<int> sessionChanges = ValueNotifier<int>(0);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: sessionChanges,
    redirect: (context, state) => appRedirect(ref.read(sessionProvider), state),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forbidden,
        builder: (context, state) => const NotAuthorizedScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => _guard(const DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.complaints,
            builder: (context, state) => _guard(const ComplaintListScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) => _guard(
                  ComplaintDetailScreen(
                    complaintId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.listen<AppUser?>(sessionProvider, (previous, next) {
    // Signing out always lands on a clean Login, not a "return to" one.
    if (previous != null && next == null) router.go(AppRoutes.login);
    sessionChanges.value++;
  });
  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});
