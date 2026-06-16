import '../models/letter_status.dart';

/// Pure game logic. Intentionally free of any Flutter/UI imports so it can be
/// unit-tested in isolation. Do not add UI dependencies here.
class GameEngine {
  const GameEngine();

  /// Evaluates [guess] against [answer], returning a status per position.
  ///
  /// Handles duplicate letters correctly using a count-based two-pass approach:
  /// exact matches are claimed first, then remaining letters are matched as
  /// "present" only while unclaimed instances of that letter remain.
  ///
  /// [guess] and [answer] must be the same length and uppercase.
  static List<LetterStatus> evaluateGuess(String guess, String answer) {
    assert(guess.length == answer.length, 'guess/answer length mismatch');

    final result = List<LetterStatus>.filled(guess.length, LetterStatus.absent);
    final remaining = <String, int>{};
    for (final c in answer.split('')) {
      remaining[c] = (remaining[c] ?? 0) + 1;
    }

    // Pass 1: exact position matches.
    for (var i = 0; i < guess.length; i++) {
      if (guess[i] == answer[i]) {
        result[i] = LetterStatus.correct;
        remaining[guess[i]] = remaining[guess[i]]! - 1;
      }
    }

    // Pass 2: present-but-misplaced, only while a count remains.
    for (var i = 0; i < guess.length; i++) {
      if (result[i] == LetterStatus.correct) continue;
      final c = guess[i];
      if ((remaining[c] ?? 0) > 0) {
        result[i] = LetterStatus.present;
        remaining[c] = remaining[c]! - 1;
      }
    }

    return result;
  }

  /// Returns true if every position is correct.
  static bool isWinning(List<LetterStatus> statuses) =>
      statuses.every((s) => s == LetterStatus.correct);
}
