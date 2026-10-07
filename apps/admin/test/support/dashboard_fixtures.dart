import 'package:campusfix_core/campusfix_core.dart';

/// A synthetic public view for aggregate tests: only the fields the dashboard
/// reads are parameters; the rest are fixed filler.
PublicComplaintView viewOf({
  required String id,
  ComplaintStatus status = ComplaintStatus.reported,
  Priority priority = Priority.medium,
  ProblemCategory category = ProblemCategory.electrical,
  Department? department,
  required DateTime createdAt,
}) => PublicComplaintView(
  id: id,
  category: category,
  building: 'Block A',
  floor: '1',
  room: '101',
  description: 'Synthetic complaint for a test.',
  effectivePriority: priority,
  status: status,
  assignedDepartment: department,
  createdAt: createdAt,
  updatedAt: createdAt,
);
