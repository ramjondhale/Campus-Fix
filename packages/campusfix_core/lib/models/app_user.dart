import 'package:meta/meta.dart';

import '../enums/department.dart';
import '../enums/user_role.dart';
import '../src/json_utils.dart';

/// An authenticated user of the app.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.idNumber,
    required this.displayName,
    required this.role,
    required this.email,
    this.department,
  });

  factory AppUser.fromJson(Map<String, Object?> json) {
    return AppUser(
      id: jsonRequired<String>(json, 'id'),
      idNumber: jsonRequired<String>(json, 'idNumber'),
      displayName: jsonRequired<String>(json, 'displayName'),
      role: jsonEnum(UserRole.values, json, 'role'),
      email: jsonRequired<String>(json, 'email'),
      department: jsonEnumOptional(Department.values, json, 'department'),
    );
  }

  final String id;

  /// Student / staff ID number used to sign in.
  final String idNumber;
  final String displayName;
  final UserRole role;
  final String email;

  /// Set for `maintenance` staff; `null` otherwise.
  final Department? department;

  /// Returns a copy with the given fields replaced. Pass `clearDepartment:
  /// true` to set [department] to `null`.
  AppUser copyWith({
    String? id,
    String? idNumber,
    String? displayName,
    UserRole? role,
    String? email,
    Department? department,
    bool clearDepartment = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      idNumber: idNumber ?? this.idNumber,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      email: email ?? this.email,
      department: clearDepartment ? null : (department ?? this.department),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'idNumber': idNumber,
    'displayName': displayName,
    'role': role.name,
    'email': email,
    'department': department?.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.idNumber == idNumber &&
          other.displayName == displayName &&
          other.role == role &&
          other.email == email &&
          other.department == department;

  @override
  int get hashCode =>
      Object.hash(id, idNumber, displayName, role, email, department);

  @override
  String toString() => 'AppUser(id: $id, role: ${role.name})';
}
