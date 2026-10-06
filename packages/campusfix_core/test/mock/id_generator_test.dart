import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  final y2026 = DateTime(2026, 6, 15, 12);
  final y2027 = DateTime(2027, 1, 1);

  group('ComplaintIdGenerator', () {
    test('first ID of a year is CF-<year>-00001', () {
      expect(ComplaintIdGenerator().next(y2026), 'CF-2026-00001');
    });

    test('matches the CF-YYYY-NNNNN format', () {
      final gen = ComplaintIdGenerator();
      for (var i = 0; i < 50; i++) {
        final id = gen.next(y2026);
        expect(id, matches(complaintIdPattern));
        expect(id, hasLength('CF-2026-00001'.length));
      }
    });

    test('sequence is monotonic, gapless and zero-padded', () {
      final gen = ComplaintIdGenerator();
      final ids = [for (var i = 0; i < 12; i++) gen.next(y2026)];
      expect(ids.first, 'CF-2026-00001');
      expect(ids[9], 'CF-2026-00010');
      expect(ids.last, 'CF-2026-00012');
      final seqs = ids.map(
        (id) => int.parse(complaintIdPattern.firstMatch(id)!.group(2)!),
      );
      expect(seqs, [for (var i = 1; i <= 12; i++) i]);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('IDs sort lexicographically in creation order', () {
      final gen = ComplaintIdGenerator();
      final ids = [for (var i = 0; i < 120; i++) gen.next(y2026)];
      expect([...ids]..sort(), ids);
    });

    test('year rollover restarts the sequence at 00001', () {
      final gen = ComplaintIdGenerator();
      gen
        ..next(y2026)
        ..next(y2026);
      expect(gen.next(y2026), 'CF-2026-00003');
      expect(gen.next(y2027), 'CF-2027-00001');
      expect(gen.next(y2027), 'CF-2027-00002');
    });

    test('each year keeps its own counter', () {
      final gen = ComplaintIdGenerator();
      expect(gen.next(y2026), 'CF-2026-00001');
      expect(gen.next(y2027), 'CF-2027-00001');
      // Back in 2026 the counter carries on rather than restarting.
      expect(gen.next(y2026), 'CF-2026-00002');
    });

    test('Dec 31 -> Jan 1 rolls the year', () {
      final gen = ComplaintIdGenerator();
      expect(gen.next(DateTime(2026, 12, 31, 23, 59, 59)), 'CF-2026-00001');
      expect(gen.next(DateTime(2027, 1, 1)), 'CF-2027-00001');
    });

    test('initialCounters continue from the last used sequence', () {
      final gen = ComplaintIdGenerator(initialCounters: {2026: 41});
      expect(gen.next(y2026), 'CF-2026-00042');
      expect(gen.next(y2027), 'CF-2027-00001');
    });

    test('does not alias the initialCounters map', () {
      final seed = {2026: 5};
      final gen = ComplaintIdGenerator(initialCounters: seed);
      gen.next(y2026);
      expect(seed, {2026: 5});
    });

    test('generators are independent', () {
      final a = ComplaintIdGenerator();
      final b = ComplaintIdGenerator();
      a.next(y2026);
      expect(b.next(y2026), 'CF-2026-00001');
    });

    test('reset restarts every year', () {
      final gen = ComplaintIdGenerator();
      gen
        ..next(y2026)
        ..next(y2027)
        ..reset();
      expect(gen.next(y2026), 'CF-2026-00001');
      expect(gen.next(y2027), 'CF-2027-00001');
    });

    test('throws StateError when the 5-digit sequence is exhausted', () {
      final gen = ComplaintIdGenerator(
        initialCounters: {2026: ComplaintIdGenerator.maxSequence - 1},
      );
      expect(gen.next(y2026), 'CF-2026-99999');
      expect(() => gen.next(y2026), throwsStateError);
      // Other years are unaffected.
      expect(gen.next(y2027), 'CF-2027-00001');
    });
  });

  group('nextComplaintId (process-wide)', () {
    setUp(resetComplaintIdCounters);
    tearDown(resetComplaintIdCounters);

    test('produces monotonic IDs per year', () {
      expect(nextComplaintId(y2026), 'CF-2026-00001');
      expect(nextComplaintId(y2026), 'CF-2026-00002');
      expect(nextComplaintId(y2027), 'CF-2027-00001');
      expect(nextComplaintId(y2026), 'CF-2026-00003');
    });

    test('reset starts over', () {
      nextComplaintId(y2026);
      resetComplaintIdCounters();
      expect(nextComplaintId(y2026), 'CF-2026-00001');
    });
  });

  group('complaintIdPattern', () {
    test('accepts well-formed IDs and exposes year/sequence', () {
      final m = complaintIdPattern.firstMatch('CF-2026-00042')!;
      expect(m.group(1), '2026');
      expect(m.group(2), '00042');
    });

    test('rejects malformed IDs', () {
      for (final bad in [
        'CF-2026-42',
        'CF-26-00042',
        'cf-2026-00042',
        'CF-2026-000042',
        'CF-2026-00042 ',
        'XX-2026-00042',
        '',
      ]) {
        expect(complaintIdPattern.hasMatch(bad), isFalse, reason: bad);
      }
    });
  });
}
