/// A deterministic shuffle pinned by OUR source, not the Dart SDK.
///
/// `List.shuffle(Random(seed))` depends on the SDK's `Random` implementation,
/// which Dart does not contractually guarantee to be stable across versions. If
/// it ever changed, every player's daily history and journey progression would
/// silently remap. So the PRNG lives here, in code we control.
///
/// Free of Flutter imports so it can be unit-tested in isolation.
class DeterministicShuffle {
  const DeterministicShuffle._();

  /// Returns a new list containing [items] permuted deterministically for
  /// [seed]. The same (items, seed) pair always yields the same order, on every
  /// platform and SDK version.
  static List<T> shuffled<T>(List<T> items, int seed) {
    final out = List<T>.of(items);
    final rng = _XorShift32(seed);
    // Fisher-Yates, descending.
    for (var i = out.length - 1; i > 0; i--) {
      final j = rng.next() % (i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }
}

/// 32-bit xorshift. Tiny, fast, and fully specified here so the sequence can
/// never drift. (Modulo bias in `next() % n` is irrelevant for our purpose —
/// we need a stable permutation, not a statistically perfect one.)
class _XorShift32 {
  _XorShift32(int seed) : _s = (seed & 0xFFFFFFFF) == 0 ? 1 : seed & 0xFFFFFFFF;

  int _s;

  int next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }
}
