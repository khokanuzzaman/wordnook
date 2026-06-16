/// Status of a single letter after a guess is evaluated.
enum LetterStatus {
  /// Not yet evaluated (empty tile or current row).
  empty,

  /// Right letter in the right position.
  correct,

  /// Right letter in the wrong position.
  present,

  /// Letter not in the word (or no remaining count).
  absent,
}

/// Ordering used when deciding whether to upgrade a keyboard key's color.
/// A key should only move "up" this ladder, never down.
extension LetterStatusRank on LetterStatus {
  int get rank {
    switch (this) {
      case LetterStatus.empty:
        return 0;
      case LetterStatus.absent:
        return 1;
      case LetterStatus.present:
        return 2;
      case LetterStatus.correct:
        return 3;
    }
  }
}
