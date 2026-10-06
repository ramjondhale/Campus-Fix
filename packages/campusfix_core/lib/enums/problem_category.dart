import 'department.dart';

/// Kind of problem being reported (R3).
///
/// Carries routing metadata: the [defaultDepartment] the complaint is sent to
/// and whether that routing is automatic ([autoRoutable]).
enum ProblemCategory {
  electrical('Electrical', Department.electrician),
  plumbing('Plumbing / Water / Washroom', Department.plumber),
  civil('Civil / Building', Department.civilMaintenance),
  furniture('Furniture', Department.carpenter),
  cleanliness('Cleanliness / Sanitation', Department.housekeeping),
  it('IT / Network / Projector / Computer', Department.itTeam),
  // Safety and Other have no default department: manual triage.
  safety('Safety', null),
  other('Other', null);

  const ProblemCategory(this.label, this.defaultDepartment);

  /// Human-readable name for UI.
  final String label;

  /// Department this category is routed to by default, or `null` when the
  /// complaint needs manual triage.
  final Department? defaultDepartment;

  /// Whether the complaint can be routed to a department automatically.
  /// Equivalent to `defaultDepartment != null`.
  bool get autoRoutable => defaultDepartment != null;
}
