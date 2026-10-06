import 'dart:convert';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  group('Complaint equality', () {
    test('two complaints built from equal parts are equal', () {
      final a = fullComplaint();
      final b = fullComplaint();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('list contents participate in equality (deep)', () {
      final a = fullComplaint();
      expect(a.copyWith(beforePhotos: [before('b1'), before('b2')]), a);
      expect(a.copyWith(beforePhotos: [before('b1')]), isNot(a));
      expect(a.copyWith(afterPhotos: const []), isNot(a));
      expect(a.copyWith(timeline: a.timeline.take(2).toList()), isNot(a));
    });

    test('differing scalar fields break equality', () {
      final a = minimalComplaint();
      expect(a.copyWith(status: ComplaintStatus.reviewed), isNot(a));
      expect(a.copyWith(safetyFlag: true), isNot(a));
      expect(a.copyWith(priorityOverride: Priority.low), isNot(a));
      expect(
        a.copyWith(updatedAt: t0.add(const Duration(seconds: 1))),
        isNot(a),
      );
    });

    test('toString carries no PII', () {
      final s = fullComplaint().toString();
      expect(s, contains('CF-2026-00042'));
      expect(s, isNot(contains(reporter.fullName)));
      expect(s, isNot(contains(reporter.email)));
    });
  });

  group('Complaint immutability', () {
    test('list fields are unmodifiable', () {
      final c = fullComplaint();
      expect(
        () => c.timeline.add(event('x', ComplaintStatus.closed)),
        throwsUnsupportedError,
      );
      expect(() => c.beforePhotos.add(before('x')), throwsUnsupportedError);
      expect(() => c.afterPhotos.clear(), throwsUnsupportedError);
    });

    test('constructor copies the lists it is given', () {
      final photos = [before('b1')];
      final c = minimalComplaint().copyWith(beforePhotos: photos);
      photos.add(before('b2'));
      expect(c.beforePhotos, hasLength(1));
    });

    test('timeline is appended via copyWith', () {
      final c = minimalComplaint();
      final next = c.copyWith(
        status: ComplaintStatus.reviewed,
        timeline: [...c.timeline, event('e1', ComplaintStatus.reviewed)],
      );
      expect(c.timeline, isEmpty);
      expect(next.timeline, hasLength(1));
    });
  });

  group('Complaint copyWith', () {
    test('no arguments returns an equal copy', () {
      expect(fullComplaint().copyWith(), fullComplaint());
    });

    test('replaces only the given fields', () {
      final c = fullComplaint();
      final d = c.copyWith(
        status: ComplaintStatus.verified,
        resolutionNote: 'Verified OK',
        title: 'New title',
      );
      expect(d.status, ComplaintStatus.verified);
      expect(d.resolutionNote, 'Verified OK');
      expect(d.title, 'New title');
      expect(d.id, c.id);
      expect(d.reporter, c.reporter);
      expect(d.timeline, c.timeline);
      expect(d.assignment, c.assignment);
    });

    test('null means keep; clear flags reset nullable fields', () {
      final c = fullComplaint();
      expect(c.copyWith(title: null).title, c.title);
      expect(c.copyWith(clearTitle: true).title, isNull);
      expect(c.copyWith(clearPriorityOverride: true).priorityOverride, isNull);
      expect(c.copyWith(clearAssignment: true).assignment, isNull);
      expect(c.copyWith(clearResolutionNote: true).resolutionNote, isNull);
    });
  });

  group('Complaint helpers', () {
    test('effectivePriority prefers the override', () {
      final c = fullComplaint();
      expect(c.priority, Priority.high);
      expect(c.priorityOverride, Priority.critical);
      expect(c.effectivePriority, Priority.critical);
    });

    test('effectivePriority falls back to computed priority', () {
      final c = fullComplaint().copyWith(clearPriorityOverride: true);
      expect(c.effectivePriority, Priority.high);
    });

    test('an override may lower priority too', () {
      final c = minimalComplaint().copyWith(priorityOverride: Priority.low);
      expect(c.priority, Priority.medium);
      expect(c.effectivePriority, Priority.low);
    });

    test('waitingTime is now - createdAt', () {
      final c = minimalComplaint();
      expect(c.waitingTime(t0), Duration.zero);
      expect(
        c.waitingTime(t0.add(const Duration(hours: 5, minutes: 30))),
        const Duration(hours: 5, minutes: 30),
      );
      expect(
        c.waitingTime(t0.add(const Duration(days: 3))),
        const Duration(days: 3),
      );
    });

    test('waitingTime never goes negative', () {
      final c = minimalComplaint();
      expect(
        c.waitingTime(t0.subtract(const Duration(minutes: 1))),
        Duration.zero,
      );
    });
  });

  group('Complaint JSON', () {
    Map<String, Object?> viaJsonText(Complaint c) =>
        jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>;

    test('round-trips a full complaint (photos + timeline)', () {
      final c = fullComplaint();
      final decoded = Complaint.fromJson(viaJsonText(c));
      expect(decoded, c);
      expect(decoded.hashCode, c.hashCode);
      expect(decoded.beforePhotos, hasLength(2));
      expect(decoded.afterPhotos, hasLength(1));
      expect(decoded.timeline.map((e) => e.status), [
        ComplaintStatus.reported,
        ComplaintStatus.reviewed,
        ComplaintStatus.assigned,
        ComplaintStatus.inProgress,
        ComplaintStatus.resolved,
      ]);
      expect(decoded.assignment, c.assignment);
      expect(decoded.priorityOverride, Priority.critical);
      expect(decoded.safetyFlag, isTrue);
    });

    test('round-trips without going through JSON text', () {
      final c = fullComplaint();
      expect(Complaint.fromJson(c.toJson()), c);
    });

    test('round-trips a minimal complaint (nulls and empty lists)', () {
      final c = minimalComplaint();
      final decoded = Complaint.fromJson(viaJsonText(c));
      expect(decoded, c);
      expect(decoded.title, isNull);
      expect(decoded.assignment, isNull);
      expect(decoded.priorityOverride, isNull);
      expect(decoded.resolutionNote, isNull);
      expect(decoded.beforePhotos, isEmpty);
      expect(decoded.timeline, isEmpty);
    });

    test('serializes enums by name and dates as ISO-8601', () {
      final json = fullComplaint().toJson();
      expect(json['category'], 'electrical');
      expect(json['priority'], 'high');
      expect(json['priorityOverride'], 'critical');
      expect(json['status'], 'resolved');
      expect(json['severity'], 'severe');
      expect(json['peopleAffected'], 'many');
      expect(json['createdAt'], t0.toIso8601String());
      expect((json['assignment'] as Map)['department'], 'electrician');
      expect((json['timeline'] as List).first, isA<Map<String, Object?>>());
    });

    test('tolerates absent optional keys and lists', () {
      final json = viaJsonText(minimalComplaint())
        ..remove('beforePhotos')
        ..remove('afterPhotos')
        ..remove('timeline')
        ..remove('assignment')
        ..remove('safetyFlag');
      final decoded = Complaint.fromJson(json);
      expect(decoded.beforePhotos, isEmpty);
      expect(decoded.timeline, isEmpty);
      expect(decoded.assignment, isNull);
      expect(decoded.safetyFlag, isFalse);
    });

    test('fromJson rejects bad input with FormatException', () {
      expect(() => Complaint.fromJson({}), throwsFormatException);
      expect(
        () => Complaint.fromJson(
          viaJsonText(minimalComplaint())..['category'] = 'weather',
        ),
        throwsFormatException,
      );
      expect(
        () => Complaint.fromJson(
          viaJsonText(minimalComplaint())..['reporter'] = 'nope',
        ),
        throwsFormatException,
      );
      expect(
        () => Complaint.fromJson(
          viaJsonText(minimalComplaint())..['timeline'] = 'nope',
        ),
        throwsFormatException,
      );
    });

    test('a decode failure message does not leak PII', () {
      final json = viaJsonText(fullComplaint())..['status'] = 'bogus';
      try {
        Complaint.fromJson(json);
        fail('expected FormatException');
      } on FormatException catch (e) {
        final msg = e.toString();
        expect(msg, isNot(contains(reporter.fullName)));
        expect(msg, isNot(contains(reporter.email)));
        expect(msg, isNot(contains(reporter.idNumber)));
      }
    });
  });
}
