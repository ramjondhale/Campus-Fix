import 'package:meta/meta.dart';

import '../enums/department.dart';
import '../src/json_utils.dart';

/// Routing of a complaint to a department (and optionally a person) (R8).
@immutable
class Assignment {
  const Assignment({
    required this.department,
    required this.assignedBy,
    required this.assignedAt,
    required this.isManual,
    this.assigneeId,
  });

  factory Assignment.fromJson(Map<String, Object?> json) {
    return Assignment(
      department: jsonEnum(Department.values, json, 'department'),
      assigneeId: jsonOptional<String>(json, 'assigneeId'),
      assignedBy: jsonRequired<String>(json, 'assignedBy'),
      assignedAt: jsonDate(json, 'assignedAt'),
      isManual: jsonRequired<bool>(json, 'isManual'),
    );
  }

  final Department department;

  /// Specific staff member, or `null` when only routed to the department.
  final String? assigneeId;

  /// Id of the user (or system actor) that made the assignment.
  final String assignedBy;
  final DateTime assignedAt;

  /// True when an admin chose the department/assignee by hand; false when it
  /// was auto-routed from the category.
  final bool isManual;

  /// Returns a copy with the given fields replaced. Pass `clearAssigneeId:
  /// true` to set [assigneeId] to `null`.
  Assignment copyWith({
    Department? department,
    String? assigneeId,
    bool clearAssigneeId = false,
    String? assignedBy,
    DateTime? assignedAt,
    bool? isManual,
  }) {
    return Assignment(
      department: department ?? this.department,
      assigneeId: clearAssigneeId ? null : (assigneeId ?? this.assigneeId),
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      isManual: isManual ?? this.isManual,
    );
  }

  Map<String, Object?> toJson() => {
    'department': department.name,
    'assigneeId': assigneeId,
    'assignedBy': assignedBy,
    'assignedAt': assignedAt.toIso8601String(),
    'isManual': isManual,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Assignment &&
          other.department == department &&
          other.assigneeId == assigneeId &&
          other.assignedBy == assignedBy &&
          other.assignedAt == assignedAt &&
          other.isManual == isManual;

  @override
  int get hashCode =>
      Object.hash(department, assigneeId, assignedBy, assignedAt, isManual);

  @override
  String toString() =>
      'Assignment(department: ${department.name}, manual: $isManual)';
}
