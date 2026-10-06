import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

// -- Helpers -----------------------------------------------------------------

PriorityInputs make({
  ProblemCategory category = ProblemCategory.furniture,
  bool safetyFlag = false,
  Severity severity = Severity.minor,
  PeopleAffected people = PeopleAffected.individual,
  Duration waitingTime = Duration.zero,
}) => PriorityInputs(
  category: category,
  safetyFlag: safetyFlag,
  severity: severity,
  peopleAffected: people,
  waitingTime: waitingTime,
);

/// Independent band mapping (spec §3.5), used to cross-check the engine.
Priority bandOf(int score) {
  if (score >= 65) return Priority.critical;
  if (score >= 45) return Priority.high;
  if (score >= 25) return Priority.medium;
  return Priority.low;
}

/// Independent safety-floor definition (spec §3.6).
bool safetyFloor(PriorityInputs i) =>
    i.safetyFlag || i.category == ProblemCategory.safety;

/// Independent critical-trigger definition (spec §3.6).
bool safetyCritical(PriorityInputs i) =>
    safetyFloor(i) &&
    (i.severity == Severity.severe ||
        i.peopleAffected == PeopleAffected.campusWide);

/// One representative waiting time per aging bucket (A = 0, 5, 10, 15, 25).
const agingBuckets = <Duration>[
  Duration(hours: 2), // fresh
  Duration(hours: 48), // day-old
  Duration(days: 5), // stale
  Duration(days: 10), // week-old
  Duration(days: 30), // neglected
];

/// All 960 inputs: 8 categories x 3 severities x 4 people x 5 aging x 2 flags.
List<PriorityInputs> allInputs() => [
  for (final c in ProblemCategory.values)
    for (final s in Severity.values)
      for (final p in PeopleAffected.values)
        for (final w in agingBuckets)
          for (final f in [false, true])
            make(
              category: c,
              safetyFlag: f,
              severity: s,
              people: p,
              waitingTime: w,
            ),
];

typedef Vector = ({
  String id,
  ProblemCategory category,
  bool safetyFlag,
  Severity severity,
  PeopleAffected people,
  Duration waitingTime,
  int score,
  Priority result,
});

Vector v(
  String id,
  ProblemCategory category,
  bool safetyFlag,
  Severity severity,
  PeopleAffected people,
  Duration waitingTime,
  int score,
  Priority result,
) => (
  id: id,
  category: category,
  safetyFlag: safetyFlag,
  severity: severity,
  people: people,
  waitingTime: waitingTime,
  score: score,
  result: result,
);

// -- Golden vectors (spec §5) --------------------------------------------------

final goldenVectors = <Vector>[
  v(
    'E1',
    ProblemCategory.furniture,
    false,
    Severity.minor,
    PeopleAffected.individual,
    const Duration(hours: 2),
    15,
    Priority.low,
  ),
  v(
    'E2',
    ProblemCategory.furniture,
    false,
    Severity.minor,
    PeopleAffected.small,
    const Duration(hours: 23, minutes: 59),
    20,
    Priority.low,
  ),
  v(
    'E3',
    ProblemCategory.furniture,
    false,
    Severity.minor,
    PeopleAffected.small,
    const Duration(hours: 24),
    25,
    Priority.medium,
  ),
  v(
    'E4',
    ProblemCategory.furniture,
    false,
    Severity.moderate,
    PeopleAffected.individual,
    Duration.zero,
    25,
    Priority.medium,
  ),
  v(
    'E5',
    ProblemCategory.it,
    false,
    Severity.moderate,
    PeopleAffected.many,
    const Duration(hours: 1),
    40,
    Priority.medium,
  ),
  v(
    'E6',
    ProblemCategory.civil,
    false,
    Severity.moderate,
    PeopleAffected.many,
    Duration.zero,
    45,
    Priority.high,
  ),
  v(
    'E7',
    ProblemCategory.plumbing,
    false,
    Severity.severe,
    PeopleAffected.many,
    const Duration(hours: 1),
    55,
    Priority.high,
  ),
  v(
    'E8',
    ProblemCategory.electrical,
    false,
    Severity.severe,
    PeopleAffected.individual,
    Duration.zero,
    50,
    Priority.high,
  ),
  v(
    'E9',
    ProblemCategory.electrical,
    false,
    Severity.severe,
    PeopleAffected.campusWide,
    Duration.zero,
    65,
    Priority.critical,
  ),
  v(
    'E10',
    ProblemCategory.it,
    false,
    Severity.severe,
    PeopleAffected.campusWide,
    Duration.zero,
    55,
    Priority.high,
  ),
  v(
    'E11',
    ProblemCategory.it,
    false,
    Severity.severe,
    PeopleAffected.many,
    const Duration(days: 7),
    65,
    Priority.critical,
  ),
  v(
    'E12',
    ProblemCategory.it,
    false,
    Severity.severe,
    PeopleAffected.many,
    const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    60,
    Priority.high,
  ),
  v(
    'E13',
    ProblemCategory.furniture,
    false,
    Severity.minor,
    PeopleAffected.individual,
    const Duration(days: 30),
    40,
    Priority.medium,
  ),
  v(
    'E14',
    ProblemCategory.electrical,
    true,
    Severity.minor,
    PeopleAffected.individual,
    Duration.zero,
    30,
    Priority.high,
  ),
  v(
    'E15',
    ProblemCategory.furniture,
    true,
    Severity.minor,
    PeopleAffected.individual,
    Duration.zero,
    15,
    Priority.high,
  ),
  v(
    'E16',
    ProblemCategory.civil,
    true,
    Severity.severe,
    PeopleAffected.individual,
    Duration.zero,
    45,
    Priority.critical,
  ),
  v(
    'E17',
    ProblemCategory.plumbing,
    true,
    Severity.moderate,
    PeopleAffected.campusWide,
    Duration.zero,
    50,
    Priority.critical,
  ),
  v(
    'E18',
    ProblemCategory.safety,
    false,
    Severity.minor,
    PeopleAffected.individual,
    Duration.zero,
    35,
    Priority.high,
  ),
  v(
    'E19',
    ProblemCategory.safety,
    false,
    Severity.severe,
    PeopleAffected.small,
    Duration.zero,
    60,
    Priority.critical,
  ),
  v(
    'E20',
    ProblemCategory.safety,
    true,
    Severity.moderate,
    PeopleAffected.small,
    const Duration(days: 10),
    65,
    Priority.critical,
  ),
  v(
    'E21',
    ProblemCategory.other,
    false,
    Severity.minor,
    PeopleAffected.individual,
    const Duration(minutes: -5),
    15,
    Priority.low,
  ),
  v(
    'E22',
    ProblemCategory.electrical,
    true,
    Severity.moderate,
    PeopleAffected.many,
    Duration.zero,
    50,
    Priority.high,
  ),
];

void main() {
  group('PriorityInputs', () {
    test('is const-constructible, defaults waitingTime to zero', () {
      const a = PriorityInputs(
        category: ProblemCategory.it,
        safetyFlag: false,
        severity: Severity.minor,
        peopleAffected: PeopleAffected.small,
      );
      expect(a.waitingTime, Duration.zero);
    });

    test('has value equality and a consistent hashCode', () {
      final a = make(
        category: ProblemCategory.civil,
        safetyFlag: true,
        severity: Severity.severe,
        people: PeopleAffected.many,
        waitingTime: const Duration(hours: 5),
      );
      final b = make(
        category: ProblemCategory.civil,
        safetyFlag: true,
        severity: Severity.severe,
        people: PeopleAffected.many,
        waitingTime: const Duration(minutes: 300),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('differs when any single field differs', () {
      final base = make();
      expect(base, isNot(base.copyWith(category: ProblemCategory.it)));
      expect(base, isNot(base.copyWith(safetyFlag: true)));
      expect(base, isNot(base.copyWith(severity: Severity.severe)));
      expect(base, isNot(base.copyWith(peopleAffected: PeopleAffected.many)));
      expect(
        base,
        isNot(base.copyWith(waitingTime: const Duration(seconds: 1))),
      );
    });

    test('copyWith with no arguments returns an equal value', () {
      final a = make(category: ProblemCategory.plumbing, safetyFlag: true);
      expect(a.copyWith(), a);
    });

    test('toString mentions the fields', () {
      final s = make(category: ProblemCategory.it).toString();
      expect(s, contains('it'));
      expect(s, contains('minor'));
    });
  });

  group('golden vectors E1-E22 (spec §5)', () {
    test('there are exactly 22 vectors', () {
      expect(goldenVectors, hasLength(22));
      expect(goldenVectors.map((g) => g.id), [
        for (var n = 1; n <= 22; n++) 'E$n',
      ]);
    });

    for (final g in goldenVectors) {
      final inputs = make(
        category: g.category,
        safetyFlag: g.safetyFlag,
        severity: g.severity,
        people: g.people,
        waitingTime: g.waitingTime,
      );

      test('${g.id}: score ${g.score}', () {
        expect(computePriorityScore(inputs), g.score);
      });

      test('${g.id}: result ${g.result.label}', () {
        expect(computePriority(inputs), g.result);
      });
    }
  });

  group('category base table (spec §5.1)', () {
    // severity = minor, people = individual, waitingTime = 0, safetyFlag = false
    const expectedScore = {
      ProblemCategory.safety: 35,
      ProblemCategory.electrical: 30,
      ProblemCategory.civil: 25,
      ProblemCategory.plumbing: 25,
      ProblemCategory.it: 20,
      ProblemCategory.cleanliness: 20,
      ProblemCategory.furniture: 15,
      ProblemCategory.other: 15,
    };
    const expectedBand = {
      ProblemCategory.safety: Priority.medium,
      ProblemCategory.electrical: Priority.medium,
      ProblemCategory.civil: Priority.medium,
      ProblemCategory.plumbing: Priority.medium,
      ProblemCategory.it: Priority.low,
      ProblemCategory.cleanliness: Priority.low,
      ProblemCategory.furniture: Priority.low,
      ProblemCategory.other: Priority.low,
    };

    test('covers all 8 categories', () {
      expect(expectedScore.keys.toSet(), ProblemCategory.values.toSet());
      expect(expectedBand.keys.toSet(), ProblemCategory.values.toSet());
    });

    for (final c in ProblemCategory.values) {
      test('${c.name}: raw score ${expectedScore[c]}', () {
        expect(computePriorityScore(make(category: c)), expectedScore[c]);
      });

      // Only the safety category is lifted by the safety rules (floor -> High).
      final expectedResult = c == ProblemCategory.safety
          ? Priority.high
          : expectedBand[c]!;
      test('${c.name}: result ${expectedResult.label}', () {
        expect(computePriority(make(category: c)), expectedResult);
      });

      test(
        '${c.name}: band before safety rules is ${expectedBand[c]!.label}',
        () {
          expect(
            bandOf(computePriorityScore(make(category: c))),
            expectedBand[c],
          );
        },
      );
    }
  });

  group('severity and people-affected contributions', () {
    // furniture (B = 0), waitingTime = 0: score is S + P.
    test('severity adds 10 x weight', () {
      for (final s in Severity.values) {
        final score = computePriorityScore(make(severity: s));
        expect(score, 10 * s.weight + 5); // + P(individual) = 5
      }
    });

    test('peopleAffected adds 5 x weight', () {
      for (final p in PeopleAffected.values) {
        final score = computePriorityScore(make(people: p));
        expect(score, 10 + 5 * p.weight); // + S(minor) = 10
      }
    });
  });

  group('aging boundaries (spec §3.4)', () {
    // Furniture, minor, individual => base score 15, so the score is 15 + A.
    int agingOf(Duration w) => computePriorityScore(make(waitingTime: w)) - 15;

    const cases = <(String, Duration, int)>[
      ('zero', Duration.zero, 0),
      ('23:59:59', Duration(hours: 23, minutes: 59, seconds: 59), 0),
      ('24:00:00', Duration(hours: 24), 5),
      ('71:59:59', Duration(hours: 71, minutes: 59, seconds: 59), 5),
      ('72:00:00', Duration(hours: 72), 10),
      (
        '6d 23:59:59',
        Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        10,
      ),
      ('7d', Duration(days: 7), 15),
      (
        '13d 23:59:59',
        Duration(days: 13, hours: 23, minutes: 59, seconds: 59),
        15,
      ),
      ('14d', Duration(days: 14), 25),
      ('365d', Duration(days: 365), 25),
    ];

    for (final (name, w, a) in cases) {
      test('$name => A = $a', () {
        expect(agingOf(w), a);
      });
    }

    test('one microsecond below each threshold stays in the lower bucket', () {
      const eps = Duration(microseconds: 1);
      expect(agingOf(const Duration(hours: 24) - eps), 0);
      expect(agingOf(const Duration(hours: 72) - eps), 5);
      expect(agingOf(const Duration(days: 7) - eps), 10);
      expect(agingOf(const Duration(days: 14) - eps), 15);
    });

    test('negative waitingTime is clamped to zero', () {
      expect(agingOf(const Duration(microseconds: -1)), 0);
      expect(agingOf(const Duration(minutes: -5)), 0);
      expect(agingOf(const Duration(days: -400)), 0);
      expect(
        computePriorityScore(make(waitingTime: const Duration(days: -30))),
        computePriorityScore(make()),
      );
      expect(
        computePriority(make(waitingTime: const Duration(days: -30))),
        computePriority(make()),
      );
    });
  });

  group('band boundaries (spec §3.5)', () {
    // Score is built from furniture (B = 0), waitingTime = 0:
    //   score = 10 x severity.weight + 5 x people.weight.
    Priority resultFor(Severity s, PeopleAffected p) =>
        computePriority(make(severity: s, people: p));
    int scoreFor(Severity s, PeopleAffected p) =>
        computePriorityScore(make(severity: s, people: p));

    test('score 20 -> low, 25 -> medium', () {
      expect(scoreFor(Severity.minor, PeopleAffected.campusWide), 30);
      expect(scoreFor(Severity.minor, PeopleAffected.small), 20);
      expect(resultFor(Severity.minor, PeopleAffected.small), Priority.low);
      expect(scoreFor(Severity.moderate, PeopleAffected.individual), 25);
      expect(
        resultFor(Severity.moderate, PeopleAffected.individual),
        Priority.medium,
      );
    });

    test('score 40 -> medium, 45 -> high', () {
      // moderate + campusWide = 40; severe + individual = 35 (furniture).
      expect(scoreFor(Severity.moderate, PeopleAffected.campusWide), 40);
      expect(
        resultFor(Severity.moderate, PeopleAffected.campusWide),
        Priority.medium,
      );
      // civil base 10 + moderate 20 + many 15 = 45 (E6).
      final e6 = make(
        category: ProblemCategory.civil,
        severity: Severity.moderate,
        people: PeopleAffected.many,
      );
      expect(computePriorityScore(e6), 45);
      expect(computePriority(e6), Priority.high);
    });

    test('score 60 -> high, 65 -> critical', () {
      // it base 5 + severe 30 + many 15 + A: 10 -> 60, 15 -> 65 (E12 / E11).
      final sixty = make(
        category: ProblemCategory.it,
        severity: Severity.severe,
        people: PeopleAffected.many,
        waitingTime: const Duration(days: 6),
      );
      final sixtyFive = sixty.copyWith(waitingTime: const Duration(days: 7));
      expect(computePriorityScore(sixty), 60);
      expect(computePriority(sixty), Priority.high);
      expect(computePriorityScore(sixtyFive), 65);
      expect(computePriority(sixtyFive), Priority.critical);
    });

    test('every reachable score maps to the spec band', () {
      final scores = <int>{};
      for (final i in allInputs()) {
        final s = computePriorityScore(i);
        scores.add(s);
        // Non-safety inputs follow the band exactly.
        if (!safetyFloor(i)) {
          expect(computePriority(i), bandOf(s), reason: '$i score $s');
        }
      }
      // Scores are multiples of 5 within 15..95 (so 64/44/24 are unreachable).
      expect(scores.every((s) => s % 5 == 0), isTrue);
      expect(scores.reduce((a, b) => a < b ? a : b), 15);
      expect(scores.reduce((a, b) => a > b ? a : b), 95);
      expect(scores.intersection({24, 44, 64}), isEmpty);
    });

    test(
      'maximum aging alone cannot lift a lowest-score complaint past Medium',
      () {
        // E13: score 15 + 25 = 40.
        final lowest = make(waitingTime: const Duration(days: 3650));
        expect(computePriorityScore(lowest), 40);
        expect(computePriority(lowest), Priority.medium);
      },
    );
  });

  group('safety rules (spec §3.6)', () {
    test('SR-1: safety floor is at least High (flag set, every category)', () {
      for (final c in ProblemCategory.values) {
        for (final s in Severity.values) {
          for (final p in PeopleAffected.values) {
            final r = computePriority(
              make(category: c, safetyFlag: true, severity: s, people: p),
            );
            expect(r.weight, greaterThanOrEqualTo(Priority.high.weight));
          }
        }
      }
    });

    test('SR-1: lowest possible inputs with the flag become High', () {
      expect(computePriority(make(safetyFlag: true)), Priority.high); // E15
    });

    test('SR-1: category safety is an implicit floor with the flag false', () {
      final i = make(category: ProblemCategory.safety, safetyFlag: false);
      expect(computePriorityScore(i), 35);
      expect(bandOf(35), Priority.medium);
      expect(computePriority(i), Priority.high); // E18
    });

    test(
      'SR-1: category safety, flag false, floor holds for every other input',
      () {
        for (final s in Severity.values) {
          for (final p in PeopleAffected.values) {
            for (final w in agingBuckets) {
              final r = computePriority(
                make(
                  category: ProblemCategory.safety,
                  safetyFlag: false,
                  severity: s,
                  people: p,
                  waitingTime: w,
                ),
              );
              expect(r.weight, greaterThanOrEqualTo(Priority.high.weight));
            }
          }
        }
      },
    );

    test('SR-2: floor + severe => Critical', () {
      expect(
        computePriority(
          make(
            category: ProblemCategory.civil,
            safetyFlag: true,
            severity: Severity.severe,
          ),
        ),
        Priority.critical,
      ); // E16
      // Implicit floor from category, flag false.
      expect(
        computePriority(
          make(
            category: ProblemCategory.safety,
            severity: Severity.severe,
            people: PeopleAffected.small,
          ),
        ),
        Priority.critical,
      ); // E19
    });

    test('SR-2: floor + campusWide => Critical', () {
      expect(
        computePriority(
          make(
            category: ProblemCategory.plumbing,
            safetyFlag: true,
            severity: Severity.moderate,
            people: PeopleAffected.campusWide,
          ),
        ),
        Priority.critical,
      ); // E17
      expect(
        computePriority(
          make(
            category: ProblemCategory.safety,
            people: PeopleAffected.campusWide,
          ),
        ),
        Priority.critical,
      );
    });

    test(
      'without a safety floor, severe + campusWide is not forced Critical',
      () {
        // E10: an IT network outage is only High by score.
        expect(
          computePriority(
            make(
              category: ProblemCategory.it,
              severity: Severity.severe,
              people: PeopleAffected.campusWide,
            ),
          ),
          Priority.high,
        );
      },
    );

    test('SR-3: rules never lower an already-Critical band (E20)', () {
      final i = make(
        category: ProblemCategory.safety,
        safetyFlag: true,
        severity: Severity.moderate,
        people: PeopleAffected.small,
        waitingTime: const Duration(days: 10),
      );
      expect(computePriorityScore(i), 65);
      expect(computePriority(i), Priority.critical);
    });

    test(
      'SR-3: a High-by-score safety complaint stays High (no Critical trigger)',
      () {
        // electrical 15 + moderate 20 + many 15 = 50, flagged: stays High (E22).
        final i = make(
          category: ProblemCategory.electrical,
          safetyFlag: true,
          severity: Severity.moderate,
          people: PeopleAffected.many,
        );
        expect(computePriorityScore(i), 50);
        expect(computePriority(i), Priority.high);
      },
    );

    test('SR-4: many + moderate do not trigger Critical on their own', () {
      // Highest non-trigger safety inputs: moderate + many, fresh.
      for (final c in ProblemCategory.values) {
        final i = make(
          category: c,
          safetyFlag: true,
          severity: Severity.moderate,
          people: PeopleAffected.many,
        );
        final band = bandOf(computePriorityScore(i));
        expect(
          computePriority(i),
          band.weight > Priority.high.weight ? band : Priority.high,
          reason: 'category ${c.name}',
        );
      }
      // Concretely (E22): electrical + flag + moderate + many => High.
      expect(
        computePriority(
          make(
            category: ProblemCategory.electrical,
            safetyFlag: true,
            severity: Severity.moderate,
            people: PeopleAffected.many,
          ),
        ),
        Priority.high,
      );
    });
  });

  group('purity and totality', () {
    test('priority_engine.dart does not read the clock, randomness or I/O', () {
      final source = File('lib/logic/priority_engine.dart').readAsStringSync();
      expect(source, isNot(contains('DateTime.now')));
      expect(source, isNot(contains('Random')));
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('dart:math')));
      expect(source, isNot(contains('Stopwatch')));
    });

    test('never throws, including extreme durations', () {
      const extremes = <Duration>[
        Duration(days: -100000000),
        Duration(microseconds: -1),
        Duration.zero,
        Duration(days: 100000000),
      ];
      for (final c in ProblemCategory.values) {
        for (final w in extremes) {
          expect(
            () => computePriority(make(category: c, waitingTime: w)),
            returnsNormally,
          );
          expect(
            () => computePriorityScore(make(category: c, waitingTime: w)),
            returnsNormally,
          );
        }
      }
    });
  });

  group('property tests over the full 960-input cross product', () {
    final inputs = allInputs();

    test('cross product has exactly 960 distinct inputs', () {
      expect(inputs, hasLength(960));
      expect(inputs.toSet(), hasLength(960));
    });

    test('determinism: equal inputs give equal outputs', () {
      for (final i in inputs) {
        final copy = i.copyWith();
        expect(computePriority(copy), computePriority(i), reason: '$i');
        expect(computePriority(i), computePriority(i), reason: '$i');
        expect(computePriorityScore(copy), computePriorityScore(i));
      }
    });

    test('monotone in severity', () {
      for (final i in inputs) {
        for (final s in Severity.values) {
          if (s.weight < i.severity.weight) continue;
          final raised = i.copyWith(severity: s);
          expect(
            computePriority(raised).weight,
            greaterThanOrEqualTo(computePriority(i).weight),
            reason: '$i -> severity ${s.name}',
          );
        }
      }
    });

    test('monotone in peopleAffected', () {
      for (final i in inputs) {
        for (final p in PeopleAffected.values) {
          if (p.weight < i.peopleAffected.weight) continue;
          final raised = i.copyWith(peopleAffected: p);
          expect(
            computePriority(raised).weight,
            greaterThanOrEqualTo(computePriority(i).weight),
            reason: '$i -> people ${p.name}',
          );
        }
      }
    });

    test('monotone in waitingTime', () {
      for (final i in inputs) {
        for (final w in agingBuckets) {
          if (w < i.waitingTime) continue;
          final older = i.copyWith(waitingTime: w);
          expect(
            computePriority(older).weight,
            greaterThanOrEqualTo(computePriority(i).weight),
            reason: '$i -> waiting $w',
          );
          expect(
            computePriorityScore(older),
            greaterThanOrEqualTo(computePriorityScore(i)),
          );
        }
      }
    });

    test(
      'safety dominance: flag=true result >= flag=false result and >= High',
      () {
        for (final i in inputs) {
          final flagged = i.copyWith(safetyFlag: true);
          final unflagged = i.copyWith(safetyFlag: false);
          expect(
            computePriority(flagged).weight,
            greaterThanOrEqualTo(computePriority(unflagged).weight),
            reason: '$i',
          );
          expect(
            computePriority(flagged).weight,
            greaterThanOrEqualTo(Priority.high.weight),
            reason: '$i',
          );
        }
      },
    );

    test('safety flag does not change the raw score', () {
      for (final i in inputs) {
        expect(
          computePriorityScore(i.copyWith(safetyFlag: true)),
          computePriorityScore(i.copyWith(safetyFlag: false)),
        );
      }
    });

    test('floor-only-raises (SR-3): result >= band of the raw score', () {
      for (final i in inputs) {
        final band = bandOf(computePriorityScore(i));
        expect(
          computePriority(i).weight,
          greaterThanOrEqualTo(band.weight),
          reason: '$i',
        );
      }
    });

    test('result equals the band whenever there is no safety floor', () {
      for (final i in inputs.where((i) => !safetyFloor(i))) {
        expect(
          computePriority(i),
          bandOf(computePriorityScore(i)),
          reason: '$i',
        );
      }
    });

    test('critical triggers: floor && (severe || campusWide) => critical', () {
      var triggered = 0;
      for (final i in inputs) {
        if (safetyCritical(i)) {
          triggered++;
          expect(computePriority(i), Priority.critical, reason: '$i');
        }
      }
      expect(triggered, greaterThan(0));
    });

    test('critical only arises from the band or a safety trigger', () {
      for (final i in inputs) {
        if (computePriority(i) == Priority.critical) {
          expect(
            bandOf(computePriorityScore(i)) == Priority.critical ||
                safetyCritical(i),
            isTrue,
            reason: '$i',
          );
        }
      }
    });

    test('output is always one of the four Priority values', () {
      for (final i in inputs) {
        expect(Priority.values, contains(computePriority(i)));
      }
    });

    test(
      'Priority.rank is consistent with weight (descending weight, ascending rank)',
      () {
        final byRank = [...Priority.values]..sort((a, b) => a.rank - b.rank);
        expect(byRank.map((p) => p.weight).toList(), [4, 3, 2, 1]);
      },
    );
  });
}
