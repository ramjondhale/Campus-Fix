/// Role of an authenticated user.
enum UserRole {
  reporter('Reporter'),
  maintenance('Maintenance'),
  verifier('Verifier'),
  admin('Admin');

  const UserRole(this.label);

  /// Human-readable name for UI.
  final String label;

  /// Only [admin] may see the reporter's identity (R5).
  bool get canSeeReporterIdentity => this == UserRole.admin;
}
