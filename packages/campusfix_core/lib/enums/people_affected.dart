/// How many people a problem affects; an input to the priority engine.
enum PeopleAffected {
  individual('Individual', weight: 1),

  /// A few people.
  small('A few people', weight: 2),

  /// A class, lab, or floor.
  many('A class / lab / floor', weight: 3),
  campusWide('Campus-wide', weight: 4);

  const PeopleAffected(this.label, {required this.weight});

  /// Human-readable name for UI.
  final String label;

  /// Numeric weight, 1 (`individual`) to 4 (`campusWide`).
  final int weight;
}
