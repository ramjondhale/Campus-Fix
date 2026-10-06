import 'dart:convert';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

Map<String, Object?> roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final n = AppNotification(
    id: 'ntf-1',
    recipientId: 'u-rep-01',
    complaintId: 'CF-2026-00001',
    type: NotificationType.assignment,
    title: 'Complaint assigned',
    body: 'CF-2026-00001 assigned to Electrician.',
    createdAt: t0,
  );

  group('AppNotification', () {
    test('read defaults to false', () {
      expect(n.read, isFalse);
    });

    test('equality and hashCode cover every field', () {
      final same = n.copyWith();
      expect(same, n);
      expect(same.hashCode, n.hashCode);
      for (final other in [
        n.copyWith(id: 'ntf-2'),
        n.copyWith(recipientId: 'u-rep-02'),
        n.copyWith(complaintId: 'CF-2026-00002'),
        n.copyWith(type: NotificationType.closure),
        n.copyWith(title: 'Other'),
        n.copyWith(body: 'Other'),
        n.copyWith(createdAt: t0.add(const Duration(minutes: 1))),
        n.copyWith(read: true),
      ]) {
        expect(other, isNot(n));
      }
    });

    test('copyWith replaces only the given fields', () {
      final read = n.copyWith(read: true);
      expect(read.read, isTrue);
      expect(read.id, n.id);
      expect(read.recipientId, n.recipientId);
      expect(read.complaintId, n.complaintId);
      expect(read.type, n.type);
      expect(read.title, n.title);
      expect(read.body, n.body);
      expect(read.createdAt, n.createdAt);
    });

    test('toJson has exactly the 8 fields, enums by name, ISO dates', () {
      final json = n.toJson();
      expect(json.keys.toSet(), {
        'id',
        'recipientId',
        'complaintId',
        'type',
        'title',
        'body',
        'createdAt',
        'read',
      });
      expect(json['type'], 'assignment');
      expect(json['createdAt'], t0.toIso8601String());
      expect(json['read'], false);
    });

    test('toJson -> fromJson round-trips through real JSON text', () {
      expect(AppNotification.fromJson(roundTrip(n.toJson())), n);
      final read = n.copyWith(read: true, type: NotificationType.closure);
      expect(AppNotification.fromJson(roundTrip(read.toJson())), read);
    });

    test('every NotificationType survives a round-trip', () {
      for (final type in NotificationType.values) {
        final x = n.copyWith(type: type);
        expect(AppNotification.fromJson(roundTrip(x.toJson())).type, type);
      }
    });

    test('fromJson tolerates a missing read flag (-> false)', () {
      final json = n.toJson()..remove('read');
      expect(AppNotification.fromJson(json).read, isFalse);
    });

    test('fromJson rejects missing, mistyped and unknown values', () {
      for (final key in ['id', 'recipientId', 'complaintId', 'type']) {
        final json = n.toJson()..remove(key);
        expect(
          () => AppNotification.fromJson(json),
          throwsFormatException,
          reason: 'missing $key',
        );
      }
      expect(
        () => AppNotification.fromJson(n.toJson()..['type'] = 'nope'),
        throwsFormatException,
      );
      expect(
        () => AppNotification.fromJson(n.toJson()..['createdAt'] = 'x'),
        throwsFormatException,
      );
      expect(
        () => AppNotification.fromJson(n.toJson()..['read'] = 'yes'),
        throwsFormatException,
      );
    });

    test('toString is concise and omits the message text', () {
      final s = n.toString();
      expect(s, contains('ntf-1'));
      expect(s, isNot(contains(n.body)));
    });
  });
}
