import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Minimal fakes proving the abstract interfaces have exactly the spec
/// signatures and can be implemented from outside the package.
class _FakeComplaintRepository implements ComplaintRepository {
  final Map<String, Complaint> _store = {};
  final StreamController<List<Complaint>> _controller =
      StreamController<List<Complaint>>.broadcast();

  @override
  Future<List<Complaint>> all() async => _store.values.toList();

  @override
  Future<Complaint?> byId(String id) async => _store[id];

  @override
  Future<List<Complaint>> byReporter(String userId) async => [
    for (final c in _store.values)
      if (c.reporter.userId == userId) c,
  ];

  @override
  Future<List<Complaint>> byDepartment(Department department) async => [
    for (final c in _store.values)
      if (c.assignment?.department == department) c,
  ];

  @override
  Future<List<Complaint>> byStatus(ComplaintStatus status) async => [
    for (final c in _store.values)
      if (c.status == status) c,
  ];

  @override
  Future<Complaint> submit(Complaint draft) async {
    _store[draft.id] = draft;
    _controller.add(_store.values.toList());
    return draft;
  }

  @override
  Future<Complaint> update(Complaint c) async {
    _store[c.id] = c;
    _controller.add(_store.values.toList());
    return c;
  }

  @override
  Stream<List<Complaint>> watchAll() => _controller.stream;
}

class _FakeAuthRepository implements AuthRepository {
  AppUser? _current;

  static const _user = AppUser(
    id: 'u-1',
    idNumber: 'S1',
    displayName: 'Test',
    role: UserRole.reporter,
    email: 't@campus.edu',
  );

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> signIn(String idNumber, String password) async {
    if (idNumber == 'S1' && password == 'pw') return _current = _user;
    return null;
  }

  @override
  Future<void> signOut() async => _current = null;
}

void main() {
  group('ComplaintRepository interface', () {
    test('can be implemented with the spec signatures', () async {
      final ComplaintRepository repo = _FakeComplaintRepository();
      expect(await repo.all(), isEmpty);
      expect(await repo.byId('CF-2026-00001'), isNull);

      final emitted = expectLater(
        repo.watchAll(),
        emits(predicate<List<Complaint>>((l) => l.length == 1)),
      );
      final stored = await repo.submit(minimalComplaint());
      await emitted;

      expect(await repo.byId(stored.id), stored);
      final updated = await repo.update(
        stored.copyWith(status: ComplaintStatus.reviewed),
      );
      expect((await repo.byId(stored.id))!.status, updated.status);
      expect(await repo.all(), [updated]);
    });
  });

  group('AuthRepository interface', () {
    test('can be implemented with the spec signatures', () async {
      final AuthRepository auth = _FakeAuthRepository();
      expect(auth.currentUser, isNull);
      expect(await auth.signIn('S1', 'wrong'), isNull);
      expect(auth.currentUser, isNull);
      final user = await auth.signIn('S1', 'pw');
      expect(user, isNotNull);
      expect(auth.currentUser, user);
      await auth.signOut();
      expect(auth.currentUser, isNull);
    });
  });
}
