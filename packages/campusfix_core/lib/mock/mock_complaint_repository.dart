import 'dart:async';

import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../models/complaint.dart';
import '../repositories/complaint_repository.dart';
import '../src/mock_support.dart';
import 'seed_data.dart';

/// In-memory [ComplaintRepository] for the prototype.
///
/// Complaints are kept in insertion order. [submit] stores the prepared draft
/// **as-is** - it neither generates a Complaint ID nor computes a priority
/// (that is `ComplaintService`'s job). [update] replaces a stored complaint
/// without checking the status machine; transition rules are enforced by the
/// service layer above.
class MockComplaintRepository implements ComplaintRepository {
  /// Creates a repository holding [initial] (insertion order preserved).
  /// [latency] simulates a network delay on every call (screens-spec G-3).
  ///
  /// Throws an [ArgumentError] if [initial] contains a duplicate id.
  MockComplaintRepository({
    Iterable<Complaint> initial = const [],
    this.latency = Duration.zero,
  }) {
    for (final c in initial) {
      if (_store.containsKey(c.id)) {
        throw ArgumentError('Duplicate complaint id ${c.id}.');
      }
      _store[c.id] = c;
    }
  }

  /// A repository pre-loaded with the complaints of [seed] (default:
  /// `SeedData.build()`).
  factory MockComplaintRepository.seeded({
    SeedData? seed,
    Duration latency = Duration.zero,
  }) => MockComplaintRepository(
    initial: (seed ?? SeedData.build()).complaints,
    latency: latency,
  );

  /// Simulated delay applied to every call.
  final Duration latency;

  final Map<String, Complaint> _store = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  List<Complaint> _snapshot() => _store.values.toList();

  List<Complaint> _where(bool Function(Complaint c) test) => [
    for (final c in _store.values)
      if (test(c)) c,
  ];

  @override
  Future<List<Complaint>> all() async {
    await simulateLatency(latency);
    return _snapshot();
  }

  @override
  Future<Complaint?> byId(String id) async {
    await simulateLatency(latency);
    return _store[id];
  }

  @override
  Future<List<Complaint>> byReporter(String userId) async {
    await simulateLatency(latency);
    return _where((c) => c.reporter.userId == userId);
  }

  @override
  Future<List<Complaint>> byDepartment(Department department) async {
    await simulateLatency(latency);
    return _where((c) => c.assignment?.department == department);
  }

  @override
  Future<List<Complaint>> byStatus(ComplaintStatus status) async {
    await simulateLatency(latency);
    return _where((c) => c.status == status);
  }

  /// Stores [draft] as-is. Throws a [StateError] if a complaint with the same
  /// id already exists.
  @override
  Future<Complaint> submit(Complaint draft) async {
    await simulateLatency(latency);
    if (_store.containsKey(draft.id)) {
      throw StateError('Complaint ${draft.id} already exists.');
    }
    _store[draft.id] = draft;
    _changes.add(null);
    return draft;
  }

  /// Replaces the stored complaint with the same id. Throws a [StateError] if
  /// there is none.
  @override
  Future<Complaint> update(Complaint c) async {
    await simulateLatency(latency);
    if (!_store.containsKey(c.id)) {
      throw StateError('Complaint ${c.id} does not exist.');
    }
    _store[c.id] = c;
    _changes.add(null);
    return c;
  }

  @override
  Stream<List<Complaint>> watchAll() =>
      snapshotStream(_changes.stream, _snapshot);
}
