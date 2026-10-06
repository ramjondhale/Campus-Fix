import 'package:meta/meta.dart';

import '../enums/attachment_kind.dart';
import '../src/json_utils.dart';

/// A photo/file attached to a complaint.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.kind,
    required this.ref,
    required this.createdAt,
    this.caption,
  });

  factory Attachment.fromJson(Map<String, Object?> json) {
    return Attachment(
      id: jsonRequired<String>(json, 'id'),
      kind: jsonEnum(AttachmentKind.values, json, 'kind'),
      ref: jsonRequired<String>(json, 'ref'),
      caption: jsonOptional<String>(json, 'caption'),
      createdAt: jsonDate(json, 'createdAt'),
    );
  }

  final String id;
  final AttachmentKind kind;

  /// Asset path or (mock) URL of the file.
  final String ref;
  final String? caption;
  final DateTime createdAt;

  /// Returns a copy with the given fields replaced. Pass `clearCaption: true`
  /// to set [caption] to `null`.
  Attachment copyWith({
    String? id,
    AttachmentKind? kind,
    String? ref,
    String? caption,
    bool clearCaption = false,
    DateTime? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      ref: ref ?? this.ref,
      caption: clearCaption ? null : (caption ?? this.caption),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'ref': ref,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment &&
          other.id == id &&
          other.kind == kind &&
          other.ref == ref &&
          other.caption == caption &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, kind, ref, caption, createdAt);

  @override
  String toString() => 'Attachment(id: $id, kind: ${kind.name})';
}
