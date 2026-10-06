import 'package:meta/meta.dart';

/// Matches a well-formed Complaint ID, e.g. `CF-2026-00042`.
/// Group 1 is the year, group 2 the sequence.
final RegExp complaintIdPattern = RegExp(r'^CF-(\d{4})-(\d{5})$');

/// Produces Complaint IDs `CF-<year>-<5-digit zero-padded sequence>` with a
/// monotonic counter per year: the first ID of a year ends in `00001`, and
/// the counter restarts at `00001` for each new year.
class ComplaintIdGenerator {
  /// Creates a generator. [initialCounters] maps a year to the last sequence
  /// already used in that year (useful when seeding existing complaints).
  ComplaintIdGenerator({Map<int, int> initialCounters = const {}})
    : _counters = {...initialCounters};

  /// Largest sequence representable in the 5-digit format.
  static const int maxSequence = 99999;

  final Map<int, int> _counters;

  /// Returns the next ID for the calendar year of [now] (its `year` field,
  /// as given - no time-zone conversion).
  ///
  /// Throws a [StateError] if that year's sequence is exhausted.
  String next(DateTime now) {
    final year = now.year;
    final sequence = (_counters[year] ?? 0) + 1;
    if (sequence > maxSequence) {
      throw StateError('Complaint ID sequence exhausted for $year.');
    }
    _counters[year] = sequence;
    return 'CF-${year.toString().padLeft(4, '0')}-'
        '${sequence.toString().padLeft(5, '0')}';
  }

  /// Forgets all counters, so every year starts again at `00001`.
  void reset() => _counters.clear();
}

final ComplaintIdGenerator _defaultGenerator = ComplaintIdGenerator();

/// Returns the next Complaint ID (`CF-YYYY-NNNNN`) for the year of [now], using
/// a process-wide monotonic counter per year.
String nextComplaintId(DateTime now) => _defaultGenerator.next(now);

/// Resets the process-wide counters used by [nextComplaintId].
@visibleForTesting
void resetComplaintIdCounters() => _defaultGenerator.reset();
