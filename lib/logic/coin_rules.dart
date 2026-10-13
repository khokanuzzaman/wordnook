/// Pure coin-economy configuration and earn/spend math. Free of Flutter imports
/// so it can be unit-tested in isolation. Tune all amounts here.
class CoinRules {
  const CoinRules._();

  // --- Earning -------------------------------------------------------------
  /// Base coins for solving the Daily.
  static const int dailyWinBase = 20;

  /// Base coins for clearing a Journey level.
  static const int journeyLevelBase = 10;

  /// Coins granted for an opt-in "watch ad → earn" (only on a real view).
  static const int watchAdReward = 25;

  /// Extra coins per guess saved (faster solve ⇒ bigger reward).
  static const int speedBonusPerGuessSaved = 5;

  /// One-time starter balance when the first-run tutorial ends (won or
  /// skipped), so a new player's first tough word has a hint within reach
  /// without being pushed straight to an ad.
  static const int welcomeCoins = 50;

  /// Extra coins on a streak-milestone Daily win.
  static const int streakMilestoneBonus = 50;

  // --- Spending ------------------------------------------------------------
  /// Reveal one correct letter (a.k.a. hint).
  static const int hintCost = 15;

  /// One extra guess beyond the normal limit.
  static const int extraGuessCost = 30;

  /// Coins awarded for a Daily win: base + speed bonus + milestone bonus.
  static int dailyWinReward({
    required int guessesUsed,
    required int maxGuesses,
    required int streak,
  }) {
    var coins = dailyWinBase + _speedBonus(guessesUsed, maxGuesses);
    if (isStreakMilestone(streak)) coins += streakMilestoneBonus;
    return coins;
  }

  /// Coins awarded for completing a Journey level: base + speed bonus.
  static int journeyLevelReward({
    required int guessesUsed,
    required int maxGuesses,
  }) =>
      journeyLevelBase + _speedBonus(guessesUsed, maxGuesses);

  static int _speedBonus(int guessesUsed, int maxGuesses) {
    final saved = (maxGuesses - guessesUsed).clamp(0, maxGuesses);
    return saved * speedBonusPerGuessSaved;
  }

  /// Whether [streak] is a celebrated milestone (also drives bonus coins).
  static bool isStreakMilestone(int streak) =>
      streak == 5 ||
      streak == 10 ||
      streak == 25 ||
      streak == 50 ||
      (streak > 0 && streak % 100 == 0);
}
