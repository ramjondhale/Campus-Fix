import '../router/routes.dart';

/// The route each destination of `AdminSideNav.defaultDestinations` opens, in
/// the same order: Dashboard (A-02), Complaints (A-03). Admins and verifiers
/// share the two destinations (screens-spec section 5).
const List<String> kAdminNavPaths = <String>[
  AppRoutes.dashboard,
  AppRoutes.complaints,
];

/// The side-nav destination that [location] belongs to. The complaint detail
/// (`/complaints/:id`, A-04) lives under Complaints; unknown paths fall back
/// to the first destination.
int navIndexFor(String location) {
  final List<String> segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return 0;
  final int index = kAdminNavPaths.indexOf('/${segments.first}');
  return index < 0 ? 0 : index;
}

/// The page title shown in the top bar for [location].
String pageTitleFor(String location) {
  final List<String> segments = Uri.parse(location).pathSegments;
  if (segments.isEmpty) return 'Dashboard';
  return switch (segments.first) {
    'complaints' => segments.length > 1 ? 'Complaint details' : 'Complaints',
    _ => 'Dashboard',
  };
}
