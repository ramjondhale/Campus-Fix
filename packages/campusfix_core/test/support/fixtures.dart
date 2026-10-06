import 'package:campusfix_core/campusfix_core.dart';

const reporter = ReporterIdentity(
  userId: 'u-100',
  fullName: 'Asha Verma',
  idNumber: 'S2024-0042',
  email: 'asha.verma@campus.edu',
  phone: '+91-98765-43210',
);

final t0 = DateTime.utc(2026, 3, 1, 9);

Attachment before(String id) => Attachment(
  id: id,
  kind: AttachmentKind.beforePhoto,
  ref: 'assets/mock/$id.jpg',
  caption: 'Leaking pipe',
  createdAt: t0,
);

Attachment after(String id) => Attachment(
  id: id,
  kind: AttachmentKind.afterPhoto,
  ref: 'assets/mock/$id.jpg',
  createdAt: t0.add(const Duration(days: 2)),
);

StatusEvent event(String id, ComplaintStatus status, {String? note}) =>
    StatusEvent(
      id: id,
      status: status,
      actorId: 'actor-$id',
      actorRole: UserRole.admin,
      note: note,
      at: t0.add(Duration(hours: status.order)),
    );

/// A minimal complaint (no photos, no timeline, no assignment).
Complaint minimalComplaint() => Complaint(
  id: 'CF-2026-00001',
  category: ProblemCategory.plumbing,
  description: 'Tap is leaking',
  building: 'Block A',
  floor: '2',
  room: '204',
  reporter: reporter,
  priority: Priority.medium,
  status: ComplaintStatus.reported,
  severity: Severity.moderate,
  peopleAffected: PeopleAffected.small,
  createdAt: t0,
  updatedAt: t0,
);

/// A fully populated complaint exercising every field.
Complaint fullComplaint() => Complaint(
  id: 'CF-2026-00042',
  category: ProblemCategory.electrical,
  title: 'Sparking socket',
  description: 'Socket near the whiteboard sparks when used',
  building: 'Science Block',
  floor: '1',
  room: 'Lab 3',
  reporter: reporter,
  beforePhotos: [before('b1'), before('b2')],
  afterPhotos: [after('a1')],
  priority: Priority.high,
  priorityOverride: Priority.critical,
  status: ComplaintStatus.resolved,
  assignment: Assignment(
    department: Department.electrician,
    assigneeId: 'm-7',
    assignedBy: 'admin-1',
    assignedAt: t0.add(const Duration(hours: 2)),
    isManual: true,
  ),
  timeline: [
    event('e1', ComplaintStatus.reported),
    event('e2', ComplaintStatus.reviewed, note: 'Confirmed hazard'),
    event('e3', ComplaintStatus.assigned),
    event('e4', ComplaintStatus.inProgress),
    event('e5', ComplaintStatus.resolved, note: 'Socket replaced'),
  ],
  resolutionNote: 'Socket replaced and tested',
  safetyFlag: true,
  severity: Severity.severe,
  peopleAffected: PeopleAffected.many,
  createdAt: t0,
  updatedAt: t0.add(const Duration(days: 2)),
);
