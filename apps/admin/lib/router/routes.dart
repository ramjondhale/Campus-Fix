import 'package:campusfix_core/campusfix_core.dart';

import '../providers/session.dart';

/// Route paths of the admin web console (screens-spec section 4). Routes carry
/// only the Complaint ID, never a name, note or any other free text (privacy
/// LK-5); filter state on `/complaints` travels as query values only.
abstract final class AppRoutes {
  /// A-01 Admin Login.
  static const String login = '/login';

  /// E-403 for a signed-in role the console has no screen for (AC-45).
  static const String forbidden = '/forbidden';

  /// A-02 Admin Dashboard (the landing route after login).
  static const String dashboard = '/dashboard';

  /// A-03 Complaint List + Filters.
  static const String complaints = '/complaints';

  /// A-04 Complaint Detail / Manage.
  static String complaint(String id) => '/complaints/$id';
}

/// The roles that may open each top-level path segment of the console
/// (screens-spec section 5): the dashboard, the list and the detail are open
/// to admins and verifiers; per-screen limits for verifiers are the screens'
/// own business.
const Map<String, Set<UserRole>> _rolesBySegment = <String, Set<UserRole>>{
  'dashboard': kConsoleRoles,
  'complaints': kConsoleRoles,
};

/// The roles allowed on the first segment of [location], or `null` when the
/// path is not a known console route (or is not a plain in-app path).
Set<UserRole>? rolesAllowedAt(String location) {
  final Uri uri = Uri.parse(location);
  // A return-to target is only ever an in-app path, never another origin.
  if (uri.hasScheme || uri.hasAuthority) return null;
  final List<String> segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  return _rolesBySegment[segments.first];
}

/// Whether [role] may open [location] (screens-spec G-1 / G-2).
bool roleMayOpen(UserRole role, String location) =>
    rolesAllowedAt(location)?.contains(role) ?? false;

/// The landing route of every console role (the dashboard, A-02).
String homeFor(UserRole role) => AppRoutes.dashboard;
