/// Reporter-rated severity of a problem; an input to the priority engine.
enum Severity {
  minor('Minor', weight: 1),
  moderate('Moderate', weight: 2),
  severe('Severe', weight: 3);

  const Severity(this.label, {required this.weight});

  /// Human-readable name for UI.
  final String label;

  /// Numeric weight, 1 (`minor`) to 3 (`severe`).
  final int weight;
}
