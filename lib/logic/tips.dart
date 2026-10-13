import '../models/letter_status.dart';

/// One-time teaching tips for a new player's first real games. Pure (no
/// Flutter imports) so the "which tip, if any" rules are unit-tested.
enum Tip { noMatches, firstAmber, reusedGrey, idleStart }

class TipRules {
  const TipRules._();

  /// Tips are only offered while a player has finished fewer than this many
  /// games (Daily + Journey combined).
  static const int eligibleGames = 5;

  /// The "stuck on an empty board" tip only appears in the first 2 games.
  static const int idleEligibleGames = 2;

  /// How long an untouched board waits before the idle tip.
  static const Duration idleDelay = Duration(seconds: 12);

  /// Storage / analytics id of a tip.
  static String id(Tip t) => switch (t) {
        Tip.noMatches => 'no_matches',
        Tip.firstAmber => 'first_amber',
        Tip.reusedGrey => 'reused_grey',
        Tip.idleStart => 'idle_start',
      };

  static Tip? fromId(String s) {
    for (final t in Tip.values) {
      if (id(t) == s) return t;
    }
    return null;
  }

  static const String noMatchesText =
      "No matches — that's useful! Those letters are out.";
  static const String firstAmberText =
      'Amber = right letter, wrong spot. Try moving it.';
  static const String _reusedGreyPrefix = 'You already ruled out ';
  static const String idleStartText =
      'Not sure? Try a word with common letters, like STARE.';

  static String reusedGreyText(String letter) => '$_reusedGreyPrefix$letter.';

  /// True when a toast message is one of these tips (styles it as a tip).
  static bool isTip(String message) =>
      message == noMatchesText ||
      message == firstAmberText ||
      message == idleStartText ||
      message.startsWith(_reusedGreyPrefix);

  /// The tip (if any) to show right after a guess, and the letter for
  /// [Tip.reusedGrey].
  ///
  /// [keyStatusBefore] is the keyboard state BEFORE this guess was scored, so
  /// a letter is "re-used grey" only if an EARLIER guess ruled it out. Only one
  /// tip per guess, most useful first: re-used grey, then no matches, then the
  /// first amber.
  static (Tip, String?)? afterGuess({
    required String guess,
    required List<LetterStatus> statuses,
    required Map<String, LetterStatus> keyStatusBefore,
    required Set<Tip> seen,
    required int gamesFinished,
  }) {
    if (gamesFinished >= eligibleGames) return null;

    if (!seen.contains(Tip.reusedGrey)) {
      for (var i = 0; i < guess.length; i++) {
        if (keyStatusBefore[guess[i]] == LetterStatus.absent) {
          return (Tip.reusedGrey, guess[i]);
        }
      }
    }
    if (!seen.contains(Tip.noMatches) &&
        statuses.isNotEmpty &&
        statuses.every((s) => s == LetterStatus.absent)) {
      return (Tip.noMatches, null);
    }
    if (!seen.contains(Tip.firstAmber) &&
        statuses.contains(LetterStatus.present)) {
      return (Tip.firstAmber, null);
    }
    return null;
  }

  /// Whether the idle "try STARE" tip may show.
  static bool idleEligible({required Set<Tip> seen, required int gamesFinished}) =>
      gamesFinished < idleEligibleGames && !seen.contains(Tip.idleStart);

  /// The message for a tip.
  static String text(Tip t, [String? letter]) => switch (t) {
        Tip.noMatches => noMatchesText,
        Tip.firstAmber => firstAmberText,
        Tip.reusedGrey => reusedGreyText(letter ?? ''),
        Tip.idleStart => idleStartText,
      };
}
