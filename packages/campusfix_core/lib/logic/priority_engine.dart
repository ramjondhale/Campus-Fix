/// Priority engine (R7): maps the signals of a complaint to a system
/// [Priority].
///
/// The algorithm is `additive score -> band -> safety rules`; see
/// `docs/specs/priority-engine-spec.md` for the full specification.
///
/// The engine is pure: it reads no clock, no randomness, no I/O and no global
/// state. The waiting time is injected by the caller, and the same inputs
/// always produce the same output. It is total: it never throws, and a
/// negative waiting time (clock skew) is treated as zero.
///
/// The engine only computes the *system* priority. The admin manual override
/// (`Complaint.priorityOverride`) is applied separately by
/// `Complaint.effectivePriority`.
library;

import 'package:meta/meta.dart';

import '../enums/people_affected.dart';
import '../enums/priority.dart';
import '../enums/problem_category.dart';
import '../enums/severity.dart';

/// The signals the priority engine scores.
///
/// Immutable value object with value equality.
///
/// `locationSensitivity` (labs, hostels, exam halls) is intentionally not part
/// of v1: it is not scored, and it can be added later without changing the
/// signature of [computePriority].
@immutable
class PriorityInputs {
  const PriorityInputs({
    required this.category,
    required this.safetyFlag,
    required this.severity,
    required this.peopleAffected,
    this.waitingTime = Duration.zero,
  });

  /// Kind of problem; sets the base weight of the score.
  final ProblemCategory category;

  /// Whether the complaint is flagged as a safety matter (reporter or admin).
  final bool safetyFlag;

  /// Reporter-rated severity.
  final Severity severity;

  /// How many people the problem affects.
  final PeopleAffected peopleAffected;

  /// Time since the complaint was created, supplied by the caller (never read
  /// from a clock here). Negative values are treated as zero.
  final Duration waitingTime;

  /// Returns a copy with the given fields replaced.
  PriorityInputs copyWith({
    ProblemCategory? category,
    bool? safetyFlag,
    Severity? severity,
    PeopleAffected? peopleAffected,
    Duration? waitingTime,
  }) {
    return PriorityInputs(
      category: category ?? this.category,
      safetyFlag: safetyFlag ?? this.safetyFlag,
      severity: severity ?? this.severity,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      waitingTime: waitingTime ?? this.waitingTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriorityInputs &&
          other.category == category &&
          other.safetyFlag == safetyFlag &&
          other.severity == severity &&
          other.peopleAffected == peopleAffected &&
          other.waitingTime == waitingTime;

  @override
  int get hashCode =>
      Object.hash(category, safetyFlag, severity, peopleAffected, waitingTime);

  @override
  String toString() =>
      'PriorityInputs(category: ${category.name}, safetyFlag: $safetyFlag, '
      'severity: ${severity.name}, peopleAffected: ${peopleAffected.name}, '
      'waitingTime: $waitingTime)';
}

// Band thresholds (inclusive lower bounds) on the raw score.
const int _criticalMinScore = 65;
const int _highMinScore = 45;
const int _mediumMinScore = 25;

/// Computes the system [Priority] for [inputs].
///
/// 1. Additive score `B + S + P + A` (category base, severity, people
///    affected, aging).
/// 2. The score is banded into critical / high / medium / low.
/// 3. Safety rules are applied on top and can only raise the band:
///    * safety floor (`safetyFlag` or category `safety`) => at least `high`;
///    * safety floor and (`severe` or `campusWide`) => `critical`.
Priority computePriority(PriorityInputs inputs) {
  final band = _bandOf(computePriorityScore(inputs));

  final safetyFloor =
      inputs.safetyFlag || inputs.category == ProblemCategory.safety;
  final safetyCritical =
      safetyFloor &&
      (inputs.severity == Severity.severe ||
          inputs.peopleAffected == PeopleAffected.campusWide);

  if (safetyCritical) return Priority.critical;
  if (safetyFloor) return _maxByWeight(band, Priority.high);
  return band;
}

/// Raw additive score (`B + S + P + A`) before the safety rules; range 15..95.
///
/// Exposed so tests can assert intermediate scores. Not part of the engine
/// contract.
@visibleForTesting
int computePriorityScore(PriorityInputs inputs) {
  return _categoryBase(inputs.category) +
      _severityScore(inputs.severity) +
      _peopleScore(inputs.peopleAffected) +
      _agingScore(inputs.waitingTime);
}

/// Category base weight (B): inherent hazard / urgency of the kind of problem.
int _categoryBase(ProblemCategory category) => switch (category) {
  ProblemCategory.safety => 20,
  ProblemCategory.electrical => 15,
  ProblemCategory.civil => 10,
  ProblemCategory.plumbing => 10,
  ProblemCategory.it => 5,
  ProblemCategory.cleanliness => 5,
  ProblemCategory.furniture => 0,
  ProblemCategory.other => 0,
};

/// Severity contribution (S): `10 x severity.weight`.
int _severityScore(Severity severity) => 10 * severity.weight;

/// People-affected contribution (P): `5 x peopleAffected.weight`.
int _peopleScore(PeopleAffected peopleAffected) => 5 * peopleAffected.weight;

const Duration _oneDay = Duration(hours: 24);
const Duration _threeDays = Duration(hours: 72);
const Duration _oneWeek = Duration(days: 7);
const Duration _twoWeeks = Duration(days: 14);

/// Aging contribution (A). Lower bound of each bucket is inclusive, the upper
/// bound exclusive. Negative waiting times are clamped to zero.
int _agingScore(Duration waitingTime) {
  final w = waitingTime.isNegative ? Duration.zero : waitingTime;
  if (w < _oneDay) return 0;
  if (w < _threeDays) return 5;
  if (w < _oneWeek) return 10;
  if (w < _twoWeeks) return 15;
  return 25;
}

Priority _bandOf(int score) {
  if (score >= _criticalMinScore) return Priority.critical;
  if (score >= _highMinScore) return Priority.high;
  if (score >= _mediumMinScore) return Priority.medium;
  return Priority.low;
}

Priority _maxByWeight(Priority a, Priority b) => a.weight >= b.weight ? a : b;
