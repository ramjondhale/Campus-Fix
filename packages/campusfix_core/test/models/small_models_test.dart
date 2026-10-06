import 'dart:convert';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Encodes then decodes through real JSON text, as a datastore would.
Map<String, Object?> roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('ReporterIdentity', () {
    test('equality and hashCode', () {
      final a = reporter.copyWith();
      expect(a, reporter);
      expect(a.hashCode, reporter.hashCode);
      expect(reporter.copyWith(email: 'x@y.z'), isNot(reporter));
    });

    test('copyWith replaces and clears', () {
      final c = reporter.copyWith(fullName: 'New Name');
      expect(c.fullName, 'New Name');
      expect(c.idNumber, reporter.idNumber);
      expect(c.phone, reporter.phone);
      expect(reporter.copyWith(clearPhone: true).phone, isNull);
    });

    test('toJson -> fromJson round-trips, with and without phone', () {
      expect(ReporterIdentity.fromJson(roundTrip(reporter.toJson())), reporter);
      final noPhone = reporter.copyWith(clearPhone: true);
      expect(ReporterIdentity.fromJson(roundTrip(noPhone.toJson())), noPhone);
    });

    test('toString is redacted', () {
      final s = reporter.toString();
      for (final pii in [
        reporter.fullName,
        reporter.idNumber,
        reporter.email,
        reporter.phone!,
      ]) {
        expect(s, isNot(contains(pii)));
      }
    });

    test('fromJson rejects a missing required field', () {
      final json = reporter.toJson()..remove('email');
      expect(() => ReporterIdentity.fromJson(json), throwsFormatException);
    });
  });

  group('AppUser', () {
    const user = AppUser(
      id: 'm-7',
      idNumber: 'E-1007',
      displayName: 'Ravi Kumar',
      role: UserRole.maintenance,
      email: 'ravi@campus.edu',
      department: Department.electrician,
    );

    test('equality, hashCode, copyWith', () {
      expect(user.copyWith(), user);
      expect(user.copyWith().hashCode, user.hashCode);
      expect(user.copyWith(role: UserRole.admin), isNot(user));
      expect(user.copyWith(displayName: 'R').displayName, 'R');
      expect(user.copyWith(clearDepartment: true).department, isNull);
    });

    test('round-trips with and without department', () {
      expect(AppUser.fromJson(roundTrip(user.toJson())), user);
      final admin = user.copyWith(role: UserRole.admin, clearDepartment: true);
      final decoded = AppUser.fromJson(roundTrip(admin.toJson()));
      expect(decoded, admin);
      expect(decoded.department, isNull);
    });

    test('fromJson rejects an unknown role', () {
      final json = user.toJson()..['role'] = 'superuser';
      expect(() => AppUser.fromJson(json), throwsFormatException);
    });
  });

  group('Attachment', () {
    test('equality, hashCode, copyWith', () {
      final a = before('b1');
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
      expect(a.copyWith(ref: 'other.jpg'), isNot(a));
      expect(a.copyWith(clearCaption: true).caption, isNull);
      expect(a.copyWith(kind: AttachmentKind.other).kind, AttachmentKind.other);
    });

    test('round-trips (caption present and absent)', () {
      for (final a in [before('b1'), after('a1')]) {
        expect(Attachment.fromJson(roundTrip(a.toJson())), a);
      }
    });

    test('round-trips a local (non-UTC) timestamp', () {
      final a = before('b1').copyWith(createdAt: DateTime(2026, 5, 4, 3, 2, 1));
      expect(Attachment.fromJson(roundTrip(a.toJson())), a);
    });

    test('fromJson rejects a malformed date', () {
      final json = before('b1').toJson()..['createdAt'] = 'not-a-date';
      expect(() => Attachment.fromJson(json), throwsFormatException);
    });
  });

  group('StatusEvent', () {
    test('equality, hashCode, copyWith', () {
      final e = event('e1', ComplaintStatus.reviewed, note: 'ok');
      expect(e.copyWith(), e);
      expect(e.copyWith().hashCode, e.hashCode);
      expect(e.copyWith(status: ComplaintStatus.closed), isNot(e));
      expect(e.copyWith(clearNote: true).note, isNull);
      expect(
        e.copyWith(actorRole: UserRole.verifier).actorRole,
        UserRole.verifier,
      );
    });

    test('round-trips (note present and absent)', () {
      for (final e in [
        event('e1', ComplaintStatus.reviewed, note: 'ok'),
        event('e2', ComplaintStatus.closed),
      ]) {
        expect(StatusEvent.fromJson(roundTrip(e.toJson())), e);
      }
    });
  });

  group('Assignment', () {
    final a = Assignment(
      department: Department.plumber,
      assigneeId: 'm-9',
      assignedBy: 'admin-1',
      assignedAt: t0,
      isManual: true,
    );

    test('equality, hashCode, copyWith', () {
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
      expect(a.copyWith(isManual: false), isNot(a));
      expect(
        a.copyWith(department: Department.itTeam).department,
        Department.itTeam,
      );
      expect(a.copyWith(clearAssigneeId: true).assigneeId, isNull);
    });

    test('round-trips with and without assignee', () {
      expect(Assignment.fromJson(roundTrip(a.toJson())), a);
      final auto = a.copyWith(clearAssigneeId: true, isManual: false);
      expect(Assignment.fromJson(roundTrip(auto.toJson())), auto);
    });
  });
}
