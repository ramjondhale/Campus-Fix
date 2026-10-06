import '../tokens/semantic_tokens.dart';

/// Builds an enum-keyed style map from name-keyed [tokens] (contract 10.2).
///
/// Throws a [StateError] naming the missing key when [tokens] lacks any value
/// of [values], so a token that drifts from its Dart enum fails loudly.
Map<E, SemanticStyle> stylesFromTokens<E extends Enum>({
  required String group,
  required Iterable<E> values,
  required Map<String, SemanticStyle> tokens,
}) {
  return Map<E, SemanticStyle>.unmodifiable(<E, SemanticStyle>{
    for (final E value in values)
      value:
          tokens[value.name] ??
          (throw StateError('Missing $group colour token "${value.name}"')),
  });
}

/// Interpolates two complete enum-keyed style maps.
Map<E, SemanticStyle> lerpStyles<E extends Enum>(
  Map<E, SemanticStyle> a,
  Map<E, SemanticStyle> b,
  double t,
) {
  return Map<E, SemanticStyle>.unmodifiable(<E, SemanticStyle>{
    for (final MapEntry<E, SemanticStyle> entry in a.entries)
      entry.key: SemanticStyle.lerp(
        entry.value,
        b[entry.key] ?? entry.value,
        t,
      ),
  });
}

/// Merges [overrides] over [base]; entries in [overrides] win.
Map<E, SemanticStyle> mergeStyles<E extends Enum>(
  Map<E, SemanticStyle> base,
  Map<E, SemanticStyle>? overrides,
) {
  if (overrides == null) return base;
  return Map<E, SemanticStyle>.unmodifiable(<E, SemanticStyle>{
    ...base,
    ...overrides,
  });
}

/// Asserts that [styles] covers every value of [values]; used by palette
/// constructors in debug builds.
bool coversAll<E extends Enum>(
  Map<E, SemanticStyle> styles,
  Iterable<E> values,
) => values.every(styles.containsKey);
