/// Internal helpers for `fromJson` decoding. Not exported from the package.
library;

/// Coerces [value] to a `Map<String, Object?>` (accepts any `Map`).
Map<String, Object?> asJsonMap(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('Expected a JSON object for $what.');
}

/// Reads a required value of type [T] at [key].
T jsonRequired<T extends Object>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException(
    'Expected $T for "$key" but found '
    '${value == null ? 'null/missing' : value.runtimeType}.',
  );
}

/// Reads an optional value of type [T] at [key]; absent or `null` -> `null`.
T? jsonOptional<T extends Object>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is T) return value;
  throw FormatException(
    'Expected $T for "$key" but found ${value.runtimeType}.',
  );
}

/// Reads a required ISO-8601 date string at [key].
DateTime jsonDate(Map<String, Object?> json, String key) {
  final raw = jsonRequired<String>(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('"$key" is not a valid ISO-8601 date.');
  }
  return parsed;
}

/// Reads a required enum value (stored as its `name`) at [key].
E jsonEnum<E extends Enum>(
  List<E> values,
  Map<String, Object?> json,
  String key,
) {
  final name = jsonRequired<String>(json, key);
  return _byName(values, name, key);
}

/// Reads an optional enum value (stored as its `name`) at [key].
E? jsonEnumOptional<E extends Enum>(
  List<E> values,
  Map<String, Object?> json,
  String key,
) {
  final name = jsonOptional<String>(json, key);
  return name == null ? null : _byName(values, name, key);
}

E _byName<E extends Enum>(List<E> values, String name, String key) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('Unknown value "$name" for "$key".');
}

/// Reads a list of JSON objects at [key], decoding each with [decode].
/// A missing or `null` list decodes to an empty list.
List<T> jsonList<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?> json) decode,
) {
  final raw = json[key];
  if (raw == null) return <T>[];
  if (raw is! List) {
    throw FormatException('Expected a list for "$key".');
  }
  return [for (final item in raw) decode(asJsonMap(item, '"$key" item'))];
}
