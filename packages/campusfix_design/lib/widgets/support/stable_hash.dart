/// A small stable string hash (32-bit FNV-1a over UTF-16 code units).
///
/// `String.hashCode` is not guaranteed to be stable across runs or
/// platforms; the drawn photo placeholders must look the same for the same
/// attachment reference everywhere, so they derive their variation from this.
int stableHash(String text) {
  int hash = 0x811C9DC5;
  for (final int unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
