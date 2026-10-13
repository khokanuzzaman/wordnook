import 'game_engine.dart';
import '../models/letter_status.dart';

/// Builds the shareable result text. Pure (no Flutter imports) so it can be
/// unit-tested. Uses OUR OWN emoji style — circles, not square tiles — so the
/// share grid is visually distinct from other word games' trade dress.
class ShareFormatter {
  // Our palette in emoji form: teal-ish / amber-ish / slate-ish circles.
  static const String correct = '🔵'; // right letter, right spot
  static const String present = '🟠'; // right letter, wrong spot
  static const String absent = '⚪'; // not in word

  static String emojiFor(LetterStatus s) {
    switch (s) {
      case LetterStatus.correct:
        return correct;
      case LetterStatus.present:
        return present;
      case LetterStatus.absent:
      case LetterStatus.empty:
        return absent;
    }
  }

  /// [dayNumber] is the 1-based daily puzzle number, or null for Journey mode.
  /// [won] with the guess count produces an "X/6" score line.
  static String build({
    required String appName,
    required int? dayNumber,
    required List<String> guesses,
    required String answer,
    required bool won,
    required int maxGuesses,
  }) {
    final label = dayNumber != null ? '#$dayNumber' : 'Journey';
    // A win on a bought extra row reads "6+1/6" — honest, never "7/6".
    final score = !won
        ? 'X/$maxGuesses'
        : guesses.length > maxGuesses
            ? '$maxGuesses+${guesses.length - maxGuesses}/$maxGuesses'
            : '${guesses.length}/$maxGuesses';

    final rows = guesses.map((g) {
      final statuses = GameEngine.evaluateGuess(g, answer);
      return statuses.map(emojiFor).join();
    }).join('\n');

    return '$appName $label $score\n\n$rows';
  }
}
