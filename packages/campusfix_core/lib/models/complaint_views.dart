import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../enums/people_affected.dart';
import '../enums/priority.dart';
import '../enums/problem_category.dart';
import '../enums/severity.dart';
import '../enums/user_role.dart';
import '../src/json_utils.dart';
import 'assignment.dart';
import 'attachment.dart';
import 'reporter_identity.dart';
import 'status_event.dart';

const ListEquality<Attachment> _attachmentsEq = ListEquality<Attachment>();
const ListEquality<PublicStatusEvent> _publicTimelineEq =
    ListEquality<PublicStatusEvent>();
const ListEquality<StatusEvent> _adminTimelineEq = ListEquality<StatusEvent>();

/// A timeline entry **without actor identity** (data-model §3.1).
///
/// A projection of `StatusEvent` that drops `id` and `actorId`: public,
/// maintenance and verifier timelines show only the status entered, the
/// actor's *role*, an optional note and the time. There is deliberately no
/// field that could carry a name or id, so leaking one is impossible by
/// construction.
@immutable
class PublicStatusEvent {
  const PublicStatusEvent({
    required this.status,
    required this.actorRole,
    required this.at,
    this.note,
  });

  factory PublicStatusEvent.fromJson(Map<String, Object?> json) {
    return PublicStatusEvent(
      status: jsonEnum(ComplaintStatus.values, json, 'status'),
      actorRole: jsonEnum(UserRole.values, json, 'actorRole'),
      note: jsonOptional<String>(json, 'note'),
      at: jsonDate(json, 'at'),
    );
  }

  /// The status entered by this event.
  final ComplaintStatus status;

  /// Role (never name/id) of whoever performed the transition.
  final UserRole actorRole;

  /// Optional free-text note (P3 residual; shown to everyone who can open the
  /// complaint's timeline).
  final String? note;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'actorRole': actorRole.name,
    'note': note,
    'at': at.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicStatusEvent &&
          other.status == status &&
          other.actorRole == actorRole &&
          other.note == note &&
          other.at == at;

  @override
  int get hashCode => Object.hash(status, actorRole, note, at);

  @override
  String toString() =>
      'PublicStatusEvent(status: ${status.name}, role: ${actorRole.name})';
}

/// A complaint as seen by every non-admin surface (board, My Complaints,
/// maintenance, verifier, notifications, admin list/dashboard) - **no PII**
/// (data-model §3.2).
///
/// Privacy by construction: this type has no field that can hold reporter
/// identity or any actor/assignee identity, and raw `priority` /
/// `priorityOverride` are not exposed (only [effectivePriority]). Build it
/// with `toPublicView` (the single choke point); the lists are exposed as
/// unmodifiable.
@immutable
class PublicComplaintView {
  /// Creates a view. [beforePhotos], [afterPhotos] and [timeline] are copied
  /// into unmodifiable lists.
  factory PublicComplaintView({
    required String id,
    required ProblemCategory category,
    String? title,
    required String building,
    required String floor,
    required String room,
    required String description,
    List<Attachment> beforePhotos = const [],
    List<Attachment> afterPhotos = const [],
    required Priority effectivePriority,
    required ComplaintStatus status,
    bool safetyFlag = false,
    Department? assignedDepartment,
    String? resolutionNote,
    List<PublicStatusEvent> timeline = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return PublicComplaintView._(
      id: id,
      category: category,
      title: title,
      building: building,
      floor: floor,
      room: room,
      description: description,
      beforePhotos: List<Attachment>.unmodifiable(beforePhotos),
      afterPhotos: List<Attachment>.unmodifiable(afterPhotos),
      effectivePriority: effectivePriority,
      status: status,
      safetyFlag: safetyFlag,
      assignedDepartment: assignedDepartment,
      resolutionNote: resolutionNote,
      timeline: List<PublicStatusEvent>.unmodifiable(timeline),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  const PublicComplaintView._({
    required this.id,
    required this.category,
    required this.title,
    required this.building,
    required this.floor,
    required this.room,
    required this.description,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.effectivePriority,
    required this.status,
    required this.safetyFlag,
    required this.assignedDepartment,
    required this.resolutionNote,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PublicComplaintView.fromJson(Map<String, Object?> json) {
    return PublicComplaintView(
      id: jsonRequired<String>(json, 'id'),
      category: jsonEnum(ProblemCategory.values, json, 'category'),
      title: jsonOptional<String>(json, 'title'),
      building: jsonRequired<String>(json, 'building'),
      floor: jsonRequired<String>(json, 'floor'),
      room: jsonRequired<String>(json, 'room'),
      description: jsonRequired<String>(json, 'description'),
      beforePhotos: jsonList(json, 'beforePhotos', Attachment.fromJson),
      afterPhotos: jsonList(json, 'afterPhotos', Attachment.fromJson),
      effectivePriority: jsonEnum(Priority.values, json, 'effectivePriority'),
      status: jsonEnum(ComplaintStatus.values, json, 'status'),
      safetyFlag: jsonOptional<bool>(json, 'safetyFlag') ?? false,
      assignedDepartment: jsonEnumOptional(
        Department.values,
        json,
        'assignedDepartment',
      ),
      resolutionNote: jsonOptional<String>(json, 'resolutionNote'),
      timeline: jsonList(json, 'timeline', PublicStatusEvent.fromJson),
      createdAt: jsonDate(json, 'createdAt'),
      updatedAt: jsonDate(json, 'updatedAt'),
    );
  }

  /// Complaint ID, format `CF-YYYY-NNNNN`.
  final String id;
  final ProblemCategory category;

  /// Optional short title; when absent the UI derives one from [category].
  final String? title;
  final String building;
  final String floor;
  final String room;
  final String description;

  /// Reporter-uploaded photos (unmodifiable).
  final List<Attachment> beforePhotos;

  /// Maintenance-uploaded photos taken after the repair (unmodifiable).
  final List<Attachment> afterPhotos;

  /// `priorityOverride ?? priority`. The raw computed priority and the
  /// override are not exposed.
  final Priority effectivePriority;
  final ComplaintStatus status;
  final bool safetyFlag;

  /// Department label only - never the assignee or who assigned it.
  final Department? assignedDepartment;

  /// Maintenance note recorded at resolution (needed by verifier/owner).
  final String? resolutionNote;

  /// Status history with roles, notes and times - no actor identity
  /// (unmodifiable).
  final List<PublicStatusEvent> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Serializable form. This - never `Complaint.toJson()` - is what UI,
  /// state and export code may serialize (privacy-spec LK-4).
  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'building': building,
    'floor': floor,
    'room': room,
    'description': description,
    'beforePhotos': [for (final a in beforePhotos) a.toJson()],
    'afterPhotos': [for (final a in afterPhotos) a.toJson()],
    'effectivePriority': effectivePriority.name,
    'status': status.name,
    'safetyFlag': safetyFlag,
    'assignedDepartment': assignedDepartment?.name,
    'resolutionNote': resolutionNote,
    'timeline': [for (final e in timeline) e.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicComplaintView &&
          other.id == id &&
          other.category == category &&
          other.title == title &&
          other.building == building &&
          other.floor == floor &&
          other.room == room &&
          other.description == description &&
          _attachmentsEq.equals(other.beforePhotos, beforePhotos) &&
          _attachmentsEq.equals(other.afterPhotos, afterPhotos) &&
          other.effectivePriority == effectivePriority &&
          other.status == status &&
          other.safetyFlag == safetyFlag &&
          other.assignedDepartment == assignedDepartment &&
          other.resolutionNote == resolutionNote &&
          _publicTimelineEq.equals(other.timeline, timeline) &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    category,
    title,
    building,
    floor,
    room,
    description,
    _attachmentsEq.hash(beforePhotos),
    _attachmentsEq.hash(afterPhotos),
    effectivePriority,
    status,
    safetyFlag,
    assignedDepartment,
    resolutionNote,
    _publicTimelineEq.hash(timeline),
    createdAt,
    updatedAt,
  ]);

  /// Concise and PII-free.
  @override
  String toString() =>
      'PublicComplaintView(id: $id, category: ${category.name}, '
      'status: ${status.name})';
}

/// The full, **admin-only** view of a complaint (data-model §3.3).
///
/// Carries everything in [PublicComplaintView] plus reporter PII, the
/// priority inputs, the full assignment and the actor-bearing timeline. It
/// only materializes via `toAdminView` when the requester's role is
/// `admin`; only the admin complaint-detail feature may import this type
/// (privacy-spec §5.1).
///
/// Intentionally not a subtype of [PublicComplaintView] (its [timeline] is a
/// `List<StatusEvent>`), so it can never be passed where a public view is
/// expected by accident.
@immutable
class AdminComplaintView {
  /// Creates a view. The list fields are copied into unmodifiable lists.
  factory AdminComplaintView({
    required String id,
    required ProblemCategory category,
    String? title,
    required String building,
    required String floor,
    required String room,
    required String description,
    List<Attachment> beforePhotos = const [],
    List<Attachment> afterPhotos = const [],
    required Priority priority,
    Priority? priorityOverride,
    required ComplaintStatus status,
    bool safetyFlag = false,
    Assignment? assignment,
    String? resolutionNote,
    List<StatusEvent> timeline = const [],
    required ReporterIdentity reporter,
    required Severity severity,
    required PeopleAffected peopleAffected,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return AdminComplaintView._(
      id: id,
      category: category,
      title: title,
      building: building,
      floor: floor,
      room: room,
      description: description,
      beforePhotos: List<Attachment>.unmodifiable(beforePhotos),
      afterPhotos: List<Attachment>.unmodifiable(afterPhotos),
      priority: priority,
      priorityOverride: priorityOverride,
      status: status,
      safetyFlag: safetyFlag,
      assignment: assignment,
      resolutionNote: resolutionNote,
      timeline: List<StatusEvent>.unmodifiable(timeline),
      reporter: reporter,
      severity: severity,
      peopleAffected: peopleAffected,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  const AdminComplaintView._({
    required this.id,
    required this.category,
    required this.title,
    required this.building,
    required this.floor,
    required this.room,
    required this.description,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.priority,
    required this.priorityOverride,
    required this.status,
    required this.safetyFlag,
    required this.assignment,
    required this.resolutionNote,
    required this.timeline,
    required this.reporter,
    required this.severity,
    required this.peopleAffected,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ProblemCategory category;
  final String? title;
  final String building;
  final String floor;
  final String room;
  final String description;

  /// Reporter-uploaded photos (unmodifiable).
  final List<Attachment> beforePhotos;

  /// Maintenance-uploaded photos (unmodifiable).
  final List<Attachment> afterPhotos;

  /// Raw computed priority (the admin sees the inputs behind a priority).
  final Priority priority;

  /// Admin manual override; when set it wins over [priority].
  final Priority? priorityOverride;
  final ComplaintStatus status;
  final bool safetyFlag;

  /// Full assignment incl. `assigneeId` / `assignedBy` (P2 staff identity).
  final Assignment? assignment;
  final String? resolutionNote;

  /// Full timeline **with** actor ids (P2; unmodifiable).
  final List<StatusEvent> timeline;

  /// Reporter PII (P0/P1) - the reason this view is admin-gated.
  final ReporterIdentity reporter;
  final Severity severity;
  final PeopleAffected peopleAffected;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `priorityOverride ?? priority`.
  Priority get effectivePriority => priorityOverride ?? priority;

  /// Department of the current [assignment], if any.
  Department? get assignedDepartment => assignment?.department;

  /// Full serialization **including reporter PII and actor ids**. Admin
  /// detail only; never for lists, boards or exports.
  ///
  /// Contains every key of `PublicComplaintView.toJson()` (with an equal
  /// value, except `timeline`, which is the actor-bearing form) plus
  /// `reporter`, `priority`, `priorityOverride`, `assignment`, `severity`
  /// and `peopleAffected`.
  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'building': building,
    'floor': floor,
    'room': room,
    'description': description,
    'beforePhotos': [for (final a in beforePhotos) a.toJson()],
    'afterPhotos': [for (final a in afterPhotos) a.toJson()],
    'effectivePriority': effectivePriority.name,
    'status': status.name,
    'safetyFlag': safetyFlag,
    'assignedDepartment': assignedDepartment?.name,
    'resolutionNote': resolutionNote,
    'timeline': [for (final e in timeline) e.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reporter': reporter.toJson(),
    'severity': severity.name,
    'peopleAffected': peopleAffected.name,
    'priority': priority.name,
    'priorityOverride': priorityOverride?.name,
    'assignment': assignment?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminComplaintView &&
          other.id == id &&
          other.category == category &&
          other.title == title &&
          other.building == building &&
          other.floor == floor &&
          other.room == room &&
          other.description == description &&
          _attachmentsEq.equals(other.beforePhotos, beforePhotos) &&
          _attachmentsEq.equals(other.afterPhotos, afterPhotos) &&
          other.priority == priority &&
          other.priorityOverride == priorityOverride &&
          other.status == status &&
          other.safetyFlag == safetyFlag &&
          other.assignment == assignment &&
          other.resolutionNote == resolutionNote &&
          _adminTimelineEq.equals(other.timeline, timeline) &&
          other.reporter == reporter &&
          other.severity == severity &&
          other.peopleAffected == peopleAffected &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    category,
    title,
    building,
    floor,
    room,
    description,
    _attachmentsEq.hash(beforePhotos),
    _attachmentsEq.hash(afterPhotos),
    priority,
    priorityOverride,
    status,
    safetyFlag,
    assignment,
    resolutionNote,
    _adminTimelineEq.hash(timeline),
    reporter,
    severity,
    peopleAffected,
    createdAt,
    updatedAt,
  ]);

  /// Concise and PII-free (never prints the reporter or actor ids).
  @override
  String toString() =>
      'AdminComplaintView(id: $id, category: ${category.name}, '
      'status: ${status.name}, <redacted>)';
}
