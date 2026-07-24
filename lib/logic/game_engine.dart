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

  /// Hard-mode check: every hint revealed by [previousGuesses] — and every
  /// position revealed by a purchased hint in [revealed] — must be reused in
  /// [guess]. Returns a human-readable reason if the guess violates the rule, or
  /// null if it's acceptable. Pure (no UI), so it can be unit-tested.
  ///
  /// Rules (standard "hard mode"):
  ///  - a letter found in the correct spot must stay in that spot;
  ///  - a letter known to be present must appear somewhere in the guess;
  ///  - a position revealed by a hint must hold that letter.
  static String? hardModeViolation(
    String guess,
    List<String> previousGuesses,
    String answer, {
    Map<int, String> revealed = const {},
  }) {
    // A purchased reveal is the strongest clue the player has, so check it
    // first and report it plainly.
    for (final entry in revealed.entries) {
      if (entry.key < guess.length && guess[entry.key] != entry.value) {
        return '${_ordinal(entry.key + 1)} letter must be ${entry.value}';
      }
    }
    for (final prev in previousGuesses) {
      final statuses = evaluateGuess(prev, answer);
      // Correct letters must be kept in place.
      for (var i = 0; i < prev.length; i++) {
        if (statuses[i] == LetterStatus.correct && guess[i] != prev[i]) {
          return '${_ordinal(i + 1)} letter must be ${prev[i]}';
        }
      }
      // Present letters must be included somewhere.
      for (var i = 0; i < prev.length; i++) {
        if (statuses[i] == LetterStatus.present && !guess.contains(prev[i])) {
          return 'Guess must contain ${prev[i]}';
        }
      }
    }
    return null;
  }

  static String _ordinal(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }
}
