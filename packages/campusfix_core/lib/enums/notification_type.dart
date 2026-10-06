/// Kind of in-app notification (R11), used to pick an icon and group items.
///
/// Mapping from complaint events (status-machine-spec §5.1):
/// creation -> [submission]; assignment / reassignment (T2, T8) ->
/// [assignment]; review, work started, verification, rejection (T1, T3, T5,
/// T7) -> [statusChange]; repair completed (T4) -> [completion]; closed (T6)
/// -> [closure].
enum NotificationType {
  /// A complaint was submitted.
  submission('Submitted'),

  /// A complaint was assigned (or reassigned) to a department.
  assignment('Assignment'),

  /// A complaint moved between stages (reviewed, started, verified, rework).
  statusChange('Status update'),

  /// The repair was completed and awaits verification.
  completion('Completed'),

  /// The complaint was closed.
  closure('Closed');

  const NotificationType(this.label);

  /// Human-readable name for UI.
  final String label;
}
