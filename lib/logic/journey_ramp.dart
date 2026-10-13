/// Journey difficulty ramp. Pure (no Flutter imports) so it can be unit-tested.
///
/// New players meet everyday words first; obscure words only appear once a
/// player has dozens of levels behind them.
enum WordTier { easy, medium, hard }

class JourneyRamp {
  const JourneyRamp._();

  /// The tier a 1-based Journey [level] draws its word from:
  ///   1–10   easy only
  ///   11–30  mostly easy, every 4th level medium
  ///   31–60  mostly medium, every 4th level hard
  ///   61+    all tiers in rotation
  static WordTier tierFor(int level) {
    final l = level < 1 ? 1 : level;
    if (l <= 10) return WordTier.easy;
    if (l <= 30) return l % 4 == 0 ? WordTier.medium : WordTier.easy;
    if (l <= 60) return l % 4 == 0 ? WordTier.hard : WordTier.medium;
    switch (l % 3) {
      case 0:
        return WordTier.hard;
      case 1:
        return WordTier.easy;
      default:
        return WordTier.medium;
    }
  }

  /// How many levels BEFORE [level] drew from the same tier. Each tier is
  /// walked in its own fixed order, so this is the word's index in that order:
  /// levels never repeat a word until their tier is exhausted.
  static int occurrenceIndex(int level) {
    final l = level < 1 ? 1 : level;
    final tier = tierFor(l);
    var count = 0;
    for (var i = 1; i < l; i++) {
      if (tierFor(i) == tier) count++;
    }
    return count;
  }

  /// Index into a tier's play order of [length] words for [level] and retry
  /// [attempt]. Attempt 0 is the level's canonical word; each retry jumps to a
  /// different word in the same tier (never the same one, when the tier has
  /// more than one word).
  static int indexFor(int level, int length, {int attempt = 0}) {
    if (length <= 0) return 0;
    final base = occurrenceIndex(level) % length;
    if (attempt <= 0 || length == 1) return base;
    var i = (base + attempt * 7919) % length;
    if (i == base) i = (i + 1) % length;
    return i;
  }
}
