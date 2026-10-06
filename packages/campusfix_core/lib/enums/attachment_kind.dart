/// Role a photo/file plays on a complaint.
enum AttachmentKind {
  /// Uploaded by the reporter when submitting.
  beforePhoto('Before photo'),

  /// Uploaded by maintenance after the repair (R10).
  afterPhoto('After photo'),
  other('Other');

  const AttachmentKind(this.label);

  /// Human-readable name for UI.
  final String label;
}
