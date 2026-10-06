import 'package:campusfix_core/campusfix_core.dart';

/// Realistic, PII-free sample data for the [WidgetGalleryScreen] and for
/// tests: [PublicComplaintView]s with no reporter, assignee or actor
/// identity. Times are relative to [now], so the gallery looks the same on
/// every run.
abstract final class GalleryFixtures {
  /// The fixed "current time" of the gallery.
  static final DateTime now = DateTime(2026, 10, 6, 14, 30);

  /// The role that files complaints. Looked up by name so this PII-free
  /// package never names the reporter-side members of the domain model.
  static final UserRole filerRole = UserRole.values.byName('reporter');

  static Attachment _photo(
    String id,
    AttachmentKind kind,
    String ref,
    DateTime at,
  ) => Attachment(id: id, kind: kind, ref: ref, createdAt: at);

  static PublicStatusEvent _event(
    ComplaintStatus status,
    UserRole role,
    DateTime at, [
    String? note,
  ]) => PublicStatusEvent(status: status, actorRole: role, at: at, note: note);

  static DateTime _ago(Duration d) => now.subtract(d);

  /// CF-2026-00042: Electrical, Critical, In Progress (the lead example).
  static final PublicComplaintView electricalCritical = PublicComplaintView(
    id: 'CF-2026-00042',
    category: ProblemCategory.electrical,
    building: 'Academic Block A',
    floor: '2',
    room: 'Electronics Lab 204',
    description:
        'Ceiling lights flicker all day and the socket next to the projector '
        'sparks when a plug is inserted. Students are avoiding that bench.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00042-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/electrical_01_before.jpg',
        _ago(const Duration(hours: 5, minutes: 20)),
      ),
    ],
    effectivePriority: Priority.critical,
    status: ComplaintStatus.inProgress,
    safetyFlag: true,
    assignedDepartment: Department.electrician,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(hours: 5, minutes: 20)),
      ),
      _event(
        ComplaintStatus.reviewed,
        UserRole.admin,
        _ago(const Duration(hours: 5)),
      ),
      _event(
        ComplaintStatus.assigned,
        UserRole.admin,
        _ago(const Duration(hours: 4, minutes: 40)),
        'Routed to the electrician team.',
      ),
      _event(
        ComplaintStatus.inProgress,
        UserRole.maintenance,
        _ago(const Duration(hours: 2)),
        'Isolated the circuit; checking the wiring.',
      ),
    ],
    createdAt: _ago(const Duration(hours: 5, minutes: 20)),
    updatedAt: _ago(const Duration(hours: 2)),
  );

  /// CF-2026-00038: Plumbing, High, Assigned (older than 24 h).
  static final PublicComplaintView plumbingHigh = PublicComplaintView(
    id: 'CF-2026-00038',
    category: ProblemCategory.plumbing,
    building: 'Hostel Block A',
    floor: '1',
    room: 'Washroom (near stairs)',
    description:
        'The tap in the second basin does not shut off and water runs all '
        'night. The floor outside is wet.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00038-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/plumbing_02_before.jpg',
        _ago(const Duration(days: 2, hours: 3)),
      ),
      _photo(
        'att-00038-b2',
        AttachmentKind.beforePhoto,
        'assets/seed/plumbing_02_before_2.jpg',
        _ago(const Duration(days: 2, hours: 3)),
      ),
    ],
    effectivePriority: Priority.high,
    status: ComplaintStatus.assigned,
    assignedDepartment: Department.plumber,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(days: 2, hours: 3)),
      ),
      _event(
        ComplaintStatus.reviewed,
        UserRole.admin,
        _ago(const Duration(days: 2, hours: 1)),
      ),
      _event(
        ComplaintStatus.assigned,
        UserRole.admin,
        _ago(const Duration(days: 2)),
      ),
    ],
    createdAt: _ago(const Duration(days: 2, hours: 3)),
    updatedAt: _ago(const Duration(days: 2)),
  );

  /// CF-2026-00045: Cleanliness, Medium, Reported 40 minutes ago.
  static final PublicComplaintView cleanlinessMedium = PublicComplaintView(
    id: 'CF-2026-00045',
    category: ProblemCategory.cleanliness,
    building: 'Cafeteria',
    floor: 'Ground',
    room: 'Dining hall',
    description:
        'Tables were not wiped after lunch and the bins near the exit are '
        'overflowing.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00045-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/cleanliness_03_before.jpg',
        _ago(const Duration(minutes: 40)),
      ),
    ],
    effectivePriority: Priority.medium,
    status: ComplaintStatus.reported,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(minutes: 40)),
      ),
    ],
    createdAt: _ago(const Duration(minutes: 40)),
    updatedAt: _ago(const Duration(minutes: 40)),
  );

  /// CF-2026-00031: IT, Low, Resolved with before and after photos
  /// (verification queue).
  static final PublicComplaintView itResolved = PublicComplaintView(
    id: 'CF-2026-00031',
    category: ProblemCategory.it,
    building: 'Science & Computer Block',
    floor: '1',
    room: 'Computer Lab 2',
    description:
        'The ceiling projector shows a green tint and turns off after ten '
        'minutes.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00031-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/it_01_before.jpg',
        _ago(const Duration(days: 3)),
      ),
    ],
    afterPhotos: <Attachment>[
      _photo(
        'att-00031-a1',
        AttachmentKind.afterPhoto,
        'assets/seed/it_01_after.jpg',
        _ago(const Duration(hours: 3, minutes: 15)),
      ),
      _photo(
        'att-00031-a2',
        AttachmentKind.afterPhoto,
        'assets/seed/it_01_after_2.jpg',
        _ago(const Duration(hours: 3, minutes: 10)),
      ),
    ],
    effectivePriority: Priority.low,
    status: ComplaintStatus.resolved,
    assignedDepartment: Department.itTeam,
    resolutionNote: 'Replaced the HDMI cable and cleaned the lamp filter.',
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(days: 3)),
      ),
      _event(
        ComplaintStatus.reviewed,
        UserRole.admin,
        _ago(const Duration(days: 2, hours: 20)),
      ),
      _event(
        ComplaintStatus.assigned,
        UserRole.admin,
        _ago(const Duration(days: 2, hours: 19)),
      ),
      _event(
        ComplaintStatus.inProgress,
        UserRole.maintenance,
        _ago(const Duration(hours: 6)),
      ),
      _event(
        ComplaintStatus.resolved,
        UserRole.maintenance,
        _ago(const Duration(hours: 3)),
        'Replaced the HDMI cable and cleaned the lamp filter.',
      ),
    ],
    createdAt: _ago(const Duration(days: 3)),
    updatedAt: _ago(const Duration(hours: 3)),
  );

  /// CF-2026-00019: Civil, High, In Progress after a rework (T7).
  static final PublicComplaintView civilRework = PublicComplaintView(
    id: 'CF-2026-00019',
    category: ProblemCategory.civil,
    building: 'Academic Block B',
    floor: '2',
    room: 'Classroom B201',
    description:
        'A crack above the whiteboard has widened and plaster falls when the '
        'door is slammed.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00019-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/civil_01_before.jpg',
        _ago(const Duration(days: 6)),
      ),
    ],
    afterPhotos: <Attachment>[
      _photo(
        'att-00019-a1',
        AttachmentKind.afterPhoto,
        'assets/seed/civil_01_after.jpg',
        _ago(const Duration(days: 1, hours: 2)),
      ),
    ],
    effectivePriority: Priority.high,
    status: ComplaintStatus.inProgress,
    assignedDepartment: Department.civilMaintenance,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(days: 6)),
      ),
      _event(
        ComplaintStatus.reviewed,
        UserRole.admin,
        _ago(const Duration(days: 5, hours: 22)),
      ),
      _event(
        ComplaintStatus.assigned,
        UserRole.admin,
        _ago(const Duration(days: 5, hours: 21)),
      ),
      _event(
        ComplaintStatus.inProgress,
        UserRole.maintenance,
        _ago(const Duration(days: 3)),
      ),
      _event(
        ComplaintStatus.resolved,
        UserRole.maintenance,
        _ago(const Duration(days: 1, hours: 2)),
        'Filled and repainted the crack.',
      ),
      _event(
        ComplaintStatus.inProgress,
        UserRole.verifier,
        _ago(const Duration(hours: 20)),
        'The crack is still visible above the frame. Please seal it fully.',
      ),
    ],
    createdAt: _ago(const Duration(days: 6)),
    updatedAt: _ago(const Duration(hours: 20)),
  );

  /// CF-2026-00040: Safety, Critical, Reviewed (awaiting manual triage).
  static final PublicComplaintView safetyCritical = PublicComplaintView(
    id: 'CF-2026-00040',
    category: ProblemCategory.safety,
    building: 'Sports Complex',
    floor: 'Ground',
    room: 'Gym',
    description:
        'A ceiling panel above the weights area has come loose and hangs by '
        'one corner.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00040-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/safety_01_before.jpg',
        _ago(const Duration(hours: 9)),
      ),
    ],
    effectivePriority: Priority.critical,
    status: ComplaintStatus.reviewed,
    safetyFlag: true,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(hours: 9)),
      ),
      _event(
        ComplaintStatus.reviewed,
        UserRole.admin,
        _ago(const Duration(hours: 8, minutes: 30)),
      ),
    ],
    createdAt: _ago(const Duration(hours: 9)),
    updatedAt: _ago(const Duration(hours: 8, minutes: 30)),
  );

  /// CF-2026-00027: Furniture, Medium, Closed.
  static final PublicComplaintView furnitureClosed = PublicComplaintView(
    id: 'CF-2026-00027',
    category: ProblemCategory.furniture,
    building: 'Central Library',
    floor: 'Ground',
    room: 'Reading Hall',
    description: 'Two reading-hall chairs have broken legs.',
    beforePhotos: <Attachment>[
      _photo(
        'att-00027-b1',
        AttachmentKind.beforePhoto,
        'assets/seed/furniture_02_before.jpg',
        _ago(const Duration(days: 9)),
      ),
    ],
    afterPhotos: <Attachment>[
      _photo(
        'att-00027-a1',
        AttachmentKind.afterPhoto,
        'assets/seed/furniture_02_after.jpg',
        _ago(const Duration(days: 7)),
      ),
    ],
    effectivePriority: Priority.medium,
    status: ComplaintStatus.closed,
    assignedDepartment: Department.carpenter,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(days: 9)),
      ),
      _event(
        ComplaintStatus.closed,
        UserRole.admin,
        _ago(const Duration(days: 6)),
      ),
    ],
    createdAt: _ago(const Duration(days: 9)),
    updatedAt: _ago(const Duration(days: 6)),
  );

  /// CF-2026-00022: Other, Low, Verified.
  static final PublicComplaintView otherVerified = PublicComplaintView(
    id: 'CF-2026-00022',
    category: ProblemCategory.other,
    building: 'Campus Grounds',
    floor: 'Outdoor / N.A.',
    room: 'Main gate',
    description: 'The notice board glass is cracked at the corner.',
    effectivePriority: Priority.low,
    status: ComplaintStatus.verified,
    assignedDepartment: Department.civilMaintenance,
    timeline: <PublicStatusEvent>[
      _event(
        ComplaintStatus.reported,
        filerRole,
        _ago(const Duration(days: 5)),
      ),
      _event(
        ComplaintStatus.verified,
        UserRole.verifier,
        _ago(const Duration(days: 1)),
      ),
    ],
    createdAt: _ago(const Duration(days: 5)),
    updatedAt: _ago(const Duration(days: 1)),
  );

  /// The complaints used by the table and lists, most urgent first.
  static final List<PublicComplaintView> complaints = <PublicComplaintView>[
    electricalCritical,
    safetyCritical,
    plumbingHigh,
    civilRework,
    cleanlinessMedium,
    itResolved,
    otherVerified,
    furnitureClosed,
  ];
}
