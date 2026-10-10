import 'package:cloud_firestore/cloud_firestore.dart';

/// Keys whose values are dates. Firestore stores them as `Timestamp`; core's
/// `fromJson` / `toJson` use ISO-8601 strings. **Keep equal to `DATE_KEYS` in
/// `backend/seed/seed.mjs`** (which writes them as Timestamps).
const Set<String> kFirestoreDateKeys = <String>{
  'createdAt',
  'updatedAt',
  'at',
  'assignedAt',
};

/// Converts Firestore data into plain JSON that core's `fromJson` accepts:
/// every `Timestamp` becomes a UTC ISO-8601 string, nested maps and lists are
/// converted recursively.
Object? firestoreToJson(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        e.key as String: firestoreToJson(e.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final Object? v in value) firestoreToJson(v)];
  }
  return value;
}

/// A document's data as JSON for core's `fromJson`, with `id` set to the
/// document id when [id] is given (core models carry their id as a field; the
/// `users/{uid}` profile and notification documents may not).
Map<String, Object?> documentToJson(Map<String, dynamic>? data, {String? id}) {
  final Map<String, Object?> json = <String, Object?>{
    ...?(firestoreToJson(data) as Map<String, Object?>?),
  };
  if (id != null) json['id'] = id;
  return json;
}

/// The inverse of [firestoreToJson] for writes: ISO-8601 strings stored under
/// a key in [kFirestoreDateKeys] become `Timestamp`s; everything else is
/// copied. Pass a core model's `toJson()` output.
Object? jsonToFirestore(Object? value, [String key = '']) {
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> e in value.entries)
        e.key as String: jsonToFirestore(e.value, e.key as String),
    };
  }
  if (value is List) {
    return <Object?>[for (final Object? v in value) jsonToFirestore(v, key)];
  }
  if (value is String && kFirestoreDateKeys.contains(key)) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return Timestamp.fromDate(parsed);
  }
  return value;
}
