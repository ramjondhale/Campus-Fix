import 'package:meta/meta.dart';

import '../enums/complaint_status.dart';
import '../enums/user_role.dart';
import '../src/json_utils.dart';

/// One entry in a complaint's append-only timeline (R9/R10).
///
/// Display rule: the actor's identity ([actorId]) is shown in admin views
/// only; public/maintenance timelines show role + timestamp + note.
@immutable
class StatusEvent {
  const StatusEvent({
    required this.id,
    required this.status,
    required this.actorId,
    required this.actorRole,
    required this.at,
    this.note,
  });

  factory StatusEvent.fromJson(Map<String, Object?> json) {
    return StatusEvent(
      id: jsonRequired<String>(json, 'id'),
      status: jsonEnum(ComplaintStatus.values, json, 'status'),
      actorId: jsonRequired<String>(json, 'actorId'),
      actorRole: jsonEnum(UserRole.values, json, 'actorRole'),
      note: jsonOptional<String>(json, 'note'),
      at: jsonDate(json, 'at'),
    );
  }

  final String id;

  /// The status entered by this event.
  final ComplaintStatus status;
  final String actorId;
  final UserRole actorRole;
  final String? note;
  final DateTime at;

  /// Returns a copy with the given fields replaced. Pass `clearNote: true` to
  /// set [note] to `null`.
  StatusEvent copyWith({
    String? id,
    ComplaintStatus? status,
    String? actorId,
    UserRole? actorRole,
    String? note,
    bool clearNote = false,
    DateTime? at,
  }) {
    return StatusEvent(
      id: id ?? this.id,
      status: status ?? this.status,
      actorId: actorId ?? this.actorId,
      actorRole: actorRole ?? this.actorRole,
      note: clearNote ? null : (note ?? this.note),
      at: at ?? this.at,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status.name,
    'actorId': actorId,
    'actorRole': actorRole.name,
    'note': note,
    'at': at.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusEvent &&
          other.id == id &&
          other.status == status &&
          other.actorId == actorId &&
          other.actorRole == actorRole &&
          other.note == note &&
          other.at == at;

  @override
  int get hashCode => Object.hash(id, status, actorId, actorRole, note, at);

  @override
  String toString() =>
      'StatusEvent(id: $id, status: ${status.name}, role: ${actorRole.name})';
}
