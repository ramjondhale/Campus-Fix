import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/errors/error_screens.dart';
import '../features/login/login_screen.dart';
import '../providers/providers.dart';
import 'role_guard.dart';
import 'routes.dart';

/// The query parameter that remembers the route a signed-out user asked for,
/// so login can return there (screens-spec G-1).
const String kReturnToParam = 'from';

/// The auth + role redirect (screens-spec G-1).
///
/// * Signed out, anywhere but Login -> Login, remembering the requested route.
/// * Signed in on Login or `/` -> the requested route if the role may open it,
///   otherwise the role's home.
/// * Anything else stays where it is (role-forbidden screens render E-403
///   themselves, see [RoleGuard]).
String? appRedirect(AppUser? user, GoRouterState state) {
  final bool atLogin = state.matchedLocation == AppRoutes.login;
  if (user == null) {
    if (atLogin) return null;
    final String requested = state.uri.toString();
    if (requested == '/' || requested == AppRoutes.home) {
      return AppRoutes.login;
    }
    return Uri(
      path: AppRoutes.login,
      queryParameters: <String, String>{kReturnToParam: requested},
    ).toString();
  }
  if (atLogin || state.matchedLocation == '/') {
    final String? from = state.uri.queryParameters[kReturnToParam];
    if (from != null && roleMayOpen(user.role, from)) return from;
    return homeFor(user.role);
  }
  return null;
}

/// The app's router. It follows the session: a change of the signed-in user
/// re-runs [appRedirect], so signing in and out navigate by themselves.
final appRouterProvider = Provider<GoRouter>((ref) {
  final ValueNotifier<int> sessionChanges = ValueNotifier<int>(0);
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: sessionChanges,
    redirect: (context, state) => appRedirect(ref.read(sessionProvider), state),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const RoleGuard(
          roles: {UserRole.reporter, UserRole.maintenance, UserRole.verifier},
          child: Scaffold(
            body: EmptyState(icon: Icons.home_outlined, title: 'Home'),
          ),
        ),
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
