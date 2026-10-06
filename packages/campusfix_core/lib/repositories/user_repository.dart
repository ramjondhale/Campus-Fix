import '../enums/department.dart';
import '../models/app_user.dart';

/// Read-only directory of users, used to resolve an `actorId` / `assigneeId` /
/// `assignedBy` to a person (admin views only) and to list assignable staff.
abstract class UserRepository {
  /// Every user.
  Future<List<AppUser>> all();

  /// The user with [id], or `null` if none exists.
  Future<AppUser?> byId(String id);

  /// The `maintenance` users whose department is [department].
  Future<List<AppUser>> maintenanceByDepartment(Department department);
}
