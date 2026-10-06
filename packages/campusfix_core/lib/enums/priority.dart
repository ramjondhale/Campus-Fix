/// Urgency of a complaint (R7).
enum Priority {
  critical('Critical', weight: 4, rank: 0),
  high('High', weight: 3, rank: 1),
  medium('Medium', weight: 2, rank: 2),
  low('Low', weight: 1, rank: 3);

  const Priority(this.label, {required this.weight, required this.rank});

  /// Human-readable name for UI.
  final String label;

  /// Numeric severity of the priority: `critical` = 4 ... `low` = 1.
  /// Larger means more urgent.
  final int weight;

  /// Sort position when listing most-urgent first: `critical` = 0 ... `low` = 3.
  /// Sorting ascending by [rank] puts the most urgent complaints on top.
  final int rank;
}
