import 'package:campusfix_core/campusfix_core.dart';

/// A synthetic public view for the list's filter, sort and page tests: every
/// field the list reads is a parameter, the rest is fixed filler.
PublicComplaintView listView({
  required String id,
  ComplaintStatus status = ComplaintStatus.reported,
  Priority priority = Priority.medium,
  ProblemCategory category = ProblemCategory.electrical,
  Department? department,
  String building = 'Block A',
  String floor = '1',
  String room = '101',
  String description = 'Synthetic complaint for a test.',
  required DateTime createdAt,
  DateTime? updatedAt,
}) => PublicComplaintView(
  id: id,
  category: category,
  building: building,
  floor: floor,
  room: room,
  description: description,
  effectivePriority: priority,
  status: status,
  assignedDepartment: department,
  createdAt: createdAt,
  updatedAt: updatedAt ?? createdAt,
);

/// [count] unresolved views `CF-T-001`.. created an hour apart (the first is
/// the oldest), for the pagination tests.
List<PublicComplaintView> manyViews(int count, {DateTime? from}) {
  final DateTime start = from ?? DateTime.utc(2026, 9, 1);
  return <PublicComplaintView>[
    for (int i = 0; i < count; i++)
      listView(
        id: 'CF-T-${(i + 1).toString().padLeft(3, '0')}',
        createdAt: start.add(Duration(hours: i)),
      ),
  ];
}
