/// Maintenance department a complaint can be routed to (R8).
///
/// Safety / Other complaints have no default department and are triaged
/// manually (see `ProblemCategory.defaultDepartment`).
enum Department {
  electrician('Electrician'),
  plumber('Plumber'),
  carpenter('Carpenter'),
  civilMaintenance('Civil Maintenance'),
  itTeam('IT Team'),
  housekeeping('Housekeeping');

  const Department(this.label);

  /// Human-readable name for UI.
  final String label;
}
