/// Lifecycle stage of a complaint (R9), in order.
///
/// `reported -> reviewed -> assigned -> inProgress -> resolved -> verified
/// -> closed`. Allowed transitions are defined by the status machine, not here.
enum ComplaintStatus {
  reported('Reported', order: 0),
  reviewed('Reviewed', order: 1),
  assigned('Assigned', order: 2),
  inProgress('In Progress', order: 3),
  resolved('Resolved', order: 4),
  verified('Verified', order: 5),
  closed('Closed', order: 6);

  const ComplaintStatus(this.label, {required this.order});

  /// Human-readable name for UI.
  final String label;

  /// Position in the lifecycle, 0 (`reported`) to 6 (`closed`).
  final int order;

  /// True once no further transition is possible (`closed`).
  bool get isTerminal => this == ComplaintStatus.closed;
}
