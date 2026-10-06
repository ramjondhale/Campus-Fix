import '../enums/department.dart';
import '../enums/user_role.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../src/mock_support.dart';
import 'seed_data.dart';

/// In-memory, read-only [UserRepository] for the prototype.
class MockUserRepository implements UserRepository {
  /// Creates a directory of [users]. [latency] simulates a network delay on
  /// every call.
  ///
  /// Throws an [ArgumentError] if [users] contains a duplicate id.
  MockUserRepository(Iterable<AppUser> users, {this.latency = Duration.zero}) {
    for (final u in users) {
      if (_byId.containsKey(u.id)) {
        throw ArgumentError('Duplicate user id ${u.id}.');
      }
      _byId[u.id] = u;
    }
  }

  /// A directory of the users of [seed] (default: `SeedData.build()`).
  factory MockUserRepository.seeded({
    SeedData? seed,
    Duration latency = Duration.zero,
  }) => MockUserRepository((seed ?? SeedData.build()).users, latency: latency);

  /// Simulated delay applied to every call.
  final Duration latency;

  final Map<String, AppUser> _byId = {};

  @override
  Future<List<AppUser>> all() async {
    await simulateLatency(latency);
    return _byId.values.toList();
  }

  @override
  Future<AppUser?> byId(String id) async {
    await simulateLatency(latency);
    return _byId[id];
  }

  @override
  Future<List<AppUser>> maintenanceByDepartment(Department department) async {
    await simulateLatency(latency);
    return [
      for (final u in _byId.values)
        if (u.role == UserRole.maintenance && u.department == department) u,
    ];
  }
}
