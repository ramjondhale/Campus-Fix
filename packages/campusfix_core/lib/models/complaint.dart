import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../enums/complaint_status.dart';
import '../enums/people_affected.dart';
import '../enums/priority.dart';
import '../enums/problem_category.dart';
import '../enums/severity.dart';
import '../src/json_utils.dart';
import 'assignment.dart';
import 'attachment.dart';
import 'reporter_identity.dart';
import 'status_event.dart';

const ListEquality<Attachment> _attachmentsEq = ListEquality<Attachment>();
const ListEquality<StatusEvent> _timelineEq = ListEquality<StatusEvent>();

/// A reported campus problem - the aggregate root.
///
/// Holds reporter PII ([reporter]); UI layers must consume the privacy-gated
/// view projections rather than this type directly.
///
/// The list fields are exposed as unmodifiable lists (the public constructor
/// takes a defensive copy), so a `Complaint` stays immutable and its
/// `==`/`hashCode` stay stable. To append to the timeline use
/// `copyWith(timeline: [...c.timeline, event])`.
@immutable
class Complaint {
  /// Creates a complaint. [beforePhotos], [afterPhotos] and [timeline] are
  /// copied into unmodifiable lists.
  factory Complaint({
    required String id,
    required ProblemCategory category,
    String? title,
    required String description,
    required String building,
    required String floor,
    required String room,
    required ReporterIdentity reporter,
    List<Attachment> beforePhotos = const [],
    List<Attachment> afterPhotos = const [],
    required Priority priority,
    Priority? priorityOverride,
    required ComplaintStatus status,
    Assignment? assignment,
    List<StatusEvent> timeline = const [],
    String? resolutionNote,
    bool safetyFlag = false,
    required Severity severity,
    required PeopleAffected peopleAffected,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Complaint._(
      id: id,
      category: category,
      title: title,
      description: description,
      building: building,
      floor: floor,
      room: room,
      reporter: reporter,
      beforePhotos: List<Attachment>.unmodifiable(beforePhotos),
      afterPhotos: List<Attachment>.unmodifiable(afterPhotos),
      priority: priority,
      priorityOverride: priorityOverride,
      status: status,
      assignment: assignment,
      timeline: List<StatusEvent>.unmodifiable(timeline),
      resolutionNote: resolutionNote,
      safetyFlag: safetyFlag,
      severity: severity,
      peopleAffected: peopleAffected,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  const Complaint._({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.building,
    required this.floor,
    required this.room,
    required this.reporter,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.priority,
    required this.priorityOverride,
    required this.status,
    required this.assignment,
    required this.timeline,
    required this.resolutionNote,
    required this.safetyFlag,
    required this.severity,
    required this.peopleAffected,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, Object?> json) {
    final assignmentJson = json['assignment'];
    return Complaint(
      id: jsonRequired<String>(json, 'id'),
      category: jsonEnum(ProblemCategory.values, json, 'category'),
      title: jsonOptional<String>(json, 'title'),
      description: jsonRequired<String>(json, 'description'),
      building: jsonRequired<String>(json, 'building'),
      floor: jsonRequired<String>(json, 'floor'),
      room: jsonRequired<String>(json, 'room'),
      reporter: ReporterIdentity.fromJson(
        asJsonMap(json['reporter'], '"reporter"'),
      ),
      beforePhotos: jsonList(json, 'beforePhotos', Attachment.fromJson),
      afterPhotos: jsonList(json, 'afterPhotos', Attachment.fromJson),
      priority: jsonEnum(Priority.values, json, 'priority'),
      priorityOverride: jsonEnumOptional(
        Priority.values,
        json,
        'priorityOverride',
      ),
      status: jsonEnum(ComplaintStatus.values, json, 'status'),
      assignment: assignmentJson == null
          ? null
          : Assignment.fromJson(asJsonMap(assignmentJson, '"assignment"')),
      timeline: jsonList(json, 'timeline', StatusEvent.fromJson),
      resolutionNote: jsonOptional<String>(json, 'resolutionNote'),
      safetyFlag: jsonOptional<bool>(json, 'safetyFlag') ?? false,
      severity: jsonEnum(Severity.values, json, 'severity'),
      peopleAffected: jsonEnum(PeopleAffected.values, json, 'peopleAffected'),
      createdAt: jsonDate(json, 'createdAt'),
      updatedAt: jsonDate(json, 'updatedAt'),
    );
  }

  /// Complaint ID, format `CF-YYYY-NNNNN` (see `nextComplaintId`).
  final String id;
  final ProblemCategory category;

  /// Optional short title; when absent the UI derives one from [category].
  final String? title;
  final String description;
  final String building;
  final String floor;

  /// Room / location detail.
  final String room;

  /// Reporter PII - gated; never exposed in a public view.
  final ReporterIdentity reporter;

  /// Reporter-uploaded photos (unmodifiable).
  final List<Attachment> beforePhotos;

  /// Maintenance-uploaded photos taken after the repair (R10) (unmodifiable).
  final List<Attachment> afterPhotos;

  /// Computed priority; see [priorityOverride] and [effectivePriority].
  final Priority priority;

  /// Admin manual override. When set it wins over [priority].
  final Priority? priorityOverride;

  /// Current lifecycle status.
  final ComplaintStatus status;

  /// `null` until the complaint is assigned.
  final Assignment? assignment;

  /// Append-only status history (unmodifiable).
  final List<StatusEvent> timeline;

  /// Maintenance note recorded at resolution (R10).
  final String? resolutionNote;

  /// Reporter/triage safety flag; forces a priority override in the engine.
  final bool safetyFlag;

  /// Reporter-rated severity.
  final Severity severity;

  /// Reporter-rated number of people affected.
  final PeopleAffected peopleAffected;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The priority actually in force: `priorityOverride ?? priority`.
  Priority get effectivePriority => priorityOverride ?? priority;

  /// How long the complaint has been waiting as of [now] (`now - createdAt`).
  /// Never negative: if [now] precedes [createdAt] (clock skew) this is
  /// [Duration.zero].
  Duration waitingTime(DateTime now) {
    final waited = now.difference(createdAt);
    return waited.isNegative ? Duration.zero : waited;
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields ([title], [priorityOverride], [assignment],
  /// [resolutionNote]) cannot be cleared by passing `null` (that means "keep
  /// current"); use the matching `clear...: true` flag instead.
  Complaint copyWith({
    String? id,
    ProblemCategory? category,
    String? title,
    bool clearTitle = false,
    String? description,
    String? building,
    String? floor,
    String? room,
    ReporterIdentity? reporter,
    List<Attachment>? beforePhotos,
    List<Attachment>? afterPhotos,
    Priority? priority,
    Priority? priorityOverride,
    bool clearPriorityOverride = false,
    ComplaintStatus? status,
    Assignment? assignment,
    bool clearAssignment = false,
    List<StatusEvent>? timeline,
    String? resolutionNote,
    bool clearResolutionNote = false,
    bool? safetyFlag,
    Severity? severity,
    PeopleAffected? peopleAffected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      category: category ?? this.category,
      title: clearTitle ? null : (title ?? this.title),
      description: description ?? this.description,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      room: room ?? this.room,
      reporter: reporter ?? this.reporter,
      beforePhotos: beforePhotos ?? this.beforePhotos,
      afterPhotos: afterPhotos ?? this.afterPhotos,
      priority: priority ?? this.priority,
      priorityOverride: clearPriorityOverride
          ? null
          : (priorityOverride ?? this.priorityOverride),
      status: status ?? this.status,
      assignment: clearAssignment ? null : (assignment ?? this.assignment),
      timeline: timeline ?? this.timeline,
      resolutionNote: clearResolutionNote
          ? null
          : (resolutionNote ?? this.resolutionNote),
      safetyFlag: safetyFlag ?? this.safetyFlag,
      severity: severity ?? this.severity,
      peopleAffected: peopleAffected ?? this.peopleAffected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Full serialization, **including reporter PII**. Not for public views.
  Map<String, Object?> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'description': description,
    'building': building,
    'floor': floor,
    'room': room,
    'reporter': reporter.toJson(),
    'beforePhotos': [for (final a in beforePhotos) a.toJson()],
    'afterPhotos': [for (final a in afterPhotos) a.toJson()],
    'priority': priority.name,
    'priorityOverride': priorityOverride?.name,
    'status': status.name,
    'assignment': assignment?.toJson(),
    'timeline': [for (final e in timeline) e.toJson()],
    'resolutionNote': resolutionNote,
    'safetyFlag': safetyFlag,
    'severity': severity.name,
    'peopleAffected': peopleAffected.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complaint &&
          other.id == id &&
          other.category == category &&
          other.title == title &&
          other.description == description &&
          other.building == building &&
          other.floor == floor &&
          other.room == room &&
          other.reporter == reporter &&
          _attachmentsEq.equals(other.beforePhotos, beforePhotos) &&
          _attachmentsEq.equals(other.afterPhotos, afterPhotos) &&
          other.priority == priority &&
          other.priorityOverride == priorityOverride &&
          other.status == status &&
          other.assignment == assignment &&
          _timelineEq.equals(other.timeline, timeline) &&
          other.resolutionNote == resolutionNote &&
          other.safetyFlag == safetyFlag &&
          other.severity == severity &&
          other.peopleAffected == peopleAffected &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    category,
    title,
    description,
    building,
    floor,
    room,
    reporter,
    _attachmentsEq.hash(beforePhotos),
    _attachmentsEq.hash(afterPhotos),
    priority,
    priorityOverride,
    status,
    assignment,
    _timelineEq.hash(timeline),
    resolutionNote,
    safetyFlag,
    severity,
    peopleAffected,
    createdAt,
    updatedAt,
  ]);

  /// Concise and PII-free.
  @override
  String toString() =>
      'Complaint(id: $id, category: ${category.name}, status: ${status.name})';
}
