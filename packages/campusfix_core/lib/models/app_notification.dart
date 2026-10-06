import 'package:meta/meta.dart';

import '../enums/notification_type.dart';
import '../src/json_utils.dart';

/// An in-app notification addressed to one user (R11).
///
/// [title] and [body] are PII-free by contract (privacy-spec LK-1): they use
/// only the complaint ID, category / department / status labels, location and
/// (for rework) the rejection note - never a reporter or staff name.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.complaintId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, Object?> json) {
    return AppNotification(
      id: jsonRequired<String>(json, 'id'),
      recipientId: jsonRequired<String>(json, 'recipientId'),
      complaintId: jsonRequired<String>(json, 'complaintId'),
      type: jsonEnum(NotificationType.values, json, 'type'),
      title: jsonRequired<String>(json, 'title'),
      body: jsonRequired<String>(json, 'body'),
      createdAt: jsonDate(json, 'createdAt'),
      read: jsonOptional<bool>(json, 'read') ?? false,
    );
  }

  final String id;

  /// `AppUser.id` of the user this notification is for.
  final String recipientId;

  /// The complaint the notification is about (deep link target).
  final String complaintId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Whether the recipient has seen it.
  final bool read;

  /// Returns a copy with the given fields replaced.
  AppNotification copyWith({
    String? id,
    String? recipientId,
    String? complaintId,
    NotificationType? type,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      complaintId: complaintId ?? this.complaintId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'recipientId': recipientId,
    'complaintId': complaintId,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          other.id == id &&
          other.recipientId == recipientId &&
          other.complaintId == complaintId &&
          other.type == type &&
          other.title == title &&
          other.body == body &&
          other.createdAt == createdAt &&
          other.read == read;

  @override
  int get hashCode => Object.hash(
    id,
    recipientId,
    complaintId,
    type,
    title,
    body,
    createdAt,
    read,
  );

  @override
  String toString() =>
      'AppNotification(id: $id, type: ${type.name}, complaint: $complaintId, '
      'read: $read)';
}
