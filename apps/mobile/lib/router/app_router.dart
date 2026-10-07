import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/board/board_screen.dart';
import '../features/complaint_details/complaint_details_screen.dart';
import '../features/errors/error_screens.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/my_complaints/my_complaints_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/report/category_step.dart';
import '../features/report/location_step.dart';
import '../features/report/photos_step.dart';
import '../features/report/report_flow.dart';
import '../features/report/report_stub_screen.dart';
import '../features/verify/verify_screens.dart';
import '../features/work/work_screens.dart';
import '../providers/providers.dart';
import '../shell/role_scaffold.dart';
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

const Set<UserRole> _reporter = {UserRole.reporter};
const Set<UserRole> _maintenance = {UserRole.maintenance};
const Set<UserRole> _verifier = {UserRole.verifier};
const Set<UserRole> _allMobile = {
  UserRole.reporter,
  UserRole.maintenance,
  UserRole.verifier,
};

Widget _guard(Set<UserRole> roles, Widget child) =>
    RoleGuard(roles: roles, child: child);

/// The app's router. It follows the session: a change of the signed-in user
/// re-runs [appRedirect], so signing in and out navigate by themselves.
///
/// Top-level screens (Home, My Complaints, Board, Notifications, the work and
/// verification queues) live in a [ShellRoute] whose [RoleScaffold] adds the
/// role's bottom navigation. Detail and flow screens (`/complaints/:id`,
/// `/board/:id`, `/work/:id[/resolve]`, `/verify/:id`, `/report/...`) are
/// pushed on the root navigator above it, so they have their own back
/// navigation and no bottom nav.
final appRouterProvider = Provider<GoRouter>((ref) {
  final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );
  final ValueNotifier<int> sessionChanges = ValueNotifier<int>(0);

  String id(GoRouterState state) => state.pathParameters['id']!;

  final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.home,
    refreshListenable: sessionChanges,
    redirect: (context, state) => appRedirect(ref.read(sessionProvider), state),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            RoleScaffold(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => _guard(_allMobile, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.complaints,
            builder: (context, state) =>
                _guard(_reporter, const MyComplaintsScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootKey,
                builder: (context, state) => _guard(
                  _reporter,
                  ComplaintDetailsScreen(complaintId: id(state)),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.board,
            builder: (context, state) =>
                _guard(_allMobile, const BoardScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootKey,
                builder: (context, state) => _guard(
                  _allMobile,
                  BoardItemDetailScreen(complaintId: id(state)),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) =>
                _guard(_allMobile, const NotificationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.work,
            builder: (context, state) =>
                _guard(_maintenance, const AssignedWorkScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootKey,
                builder: (context, state) => _guard(
                  _maintenance,
                  WorkDetailScreen(complaintId: id(state)),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'resolve',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => _guard(
                      _maintenance,
                      AfterRepairScreen(complaintId: id(state)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.verify,
            builder: (context, state) =>
                _guard(_verifier, const VerificationQueueScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootKey,
                builder: (context, state) => _guard(
                  _verifier,
                  VerifyCloseScreen(complaintId: id(state)),
                ),
              ),
            ],
          ),
        ],
      ),
      // Report flow (M-03..M-08): full-screen, reporter only.
      GoRoute(
        path: AppRoutes.reportCategory,
        builder: (context, state) =>
            _guard(_reporter, CategoryStep(edit: isEditMode(state))),
      ),
      GoRoute(
        path: AppRoutes.reportLocation,
        builder: (context, state) =>
            _guard(_reporter, LocationStep(edit: isEditMode(state))),
      ),
      GoRoute(
        path: AppRoutes.reportPhotos,
        builder: (context, state) =>
            _guard(_reporter, PhotosStep(edit: isEditMode(state))),
      ),
      GoRoute(
        path: AppRoutes.reportDetails,
        builder: (context, state) => _guard(
          _reporter,
          const ReportStubScreen(title: 'Description & impact'),
        ),
      ),
      GoRoute(
        path: AppRoutes.reportReview,
        builder: (context, state) =>
            _guard(_reporter, const ReportStubScreen(title: 'Review')),
      ),
      GoRoute(
        path: '/report/done/:id',
        builder: (context, state) =>
            _guard(_reporter, const ReportStubScreen(title: 'Confirmation')),
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
