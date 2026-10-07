import 'package:campusfix_core/campusfix_core.dart';

/// Route paths of the mobile app (screens-spec §1.1). Routes carry only the
/// Complaint ID, never a name, note or any other free text (privacy LK-5).
abstract final class AppRoutes {
  static const String login = '/login';

  // M-02 Home (role-aware)
  static const String home = '/home';

  // M-03..M-08 Report flow (reporter)
  static const String reportCategory = '/report/category';
  static const String reportLocation = '/report/location';
  static const String reportPhotos = '/report/photos';
  static const String reportDetails = '/report/details';
  static const String reportReview = '/report/review';
  static String reportDone(String id) => '/report/done/$id';

  // M-09 / M-10 My complaints (reporter)
  static const String complaints = '/complaints';
  static String complaint(String id) => '/complaints/$id';

  // M-11 / M-11b Campus Problem Board (all mobile roles)
  static const String board = '/board';
  static String boardItem(String id) => '/board/$id';

  // M-12 Notifications (all mobile roles)
  static const String notifications = '/notifications';

  // M-13..M-15 Assigned work (maintenance)
  static const String work = '/work';
  static String workItem(String id) => '/work/$id';
  static String workResolve(String id) => '/work/$id/resolve';

  // M-16 / M-17 Verification (verifier)
  static const String verify = '/verify';
  static String verifyItem(String id) => '/verify/$id';
}

/// The roles that may open each top-level path segment (screens-spec §5).
/// The admin console is on the web, so `admin` is never listed.
const Map<String, Set<UserRole>> _rolesBySegment = {
  'home': {UserRole.reporter, UserRole.maintenance, UserRole.verifier},
  'report': {UserRole.reporter},
  'complaints': {UserRole.reporter},
  'board': {UserRole.reporter, UserRole.maintenance, UserRole.verifier},
  'notifications': {UserRole.reporter, UserRole.maintenance, UserRole.verifier},
  'work': {UserRole.maintenance},
  'verify': {UserRole.verifier},
};

/// The roles allowed on the first segment of [location], or `null` when the
/// path is not a known mobile route.
Set<UserRole>? rolesAllowedAt(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return null;
  return _rolesBySegment[segments.first];
}

/// Whether [role] may open [location] (screens-spec G-1 / G-2).
bool roleMayOpen(UserRole role, String location) =>
    rolesAllowedAt(location)?.contains(role) ?? false;

/// The landing route of [role] (reporter, maintenance and verifier all land
/// on the role-aware Home, M-02).
String homeFor(UserRole role) => AppRoutes.home;
