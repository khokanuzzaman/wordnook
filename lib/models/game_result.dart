/// Aggregate player stats, persisted via StorageService.
class GameStats {
  final int gamesPlayed;
  final int gamesWon;
  final int currentStreak;
  final int bestStreak;

  /// Index = number of guesses used to win (1..maxGuesses). Value = count.
  /// Index 0 is unused so the list reads naturally (distribution[3] = wins in 3).
  final List<int> guessDistribution;

  const GameStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.guessDistribution = const [0, 0, 0, 0, 0, 0, 0],
  });

  double get winRate => gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed;

  GameStats copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? currentStreak,
    int? bestStreak,
    List<int>? guessDistribution,
  }) {
    return GameStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      guessDistribution: guessDistribution ?? this.guessDistribution,
    );
  }

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'guessDistribution': guessDistribution,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) {
    final dist = (json['guessDistribution'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [0, 0, 0, 0, 0, 0, 0];
    return GameStats(
      gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (json['gamesWon'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      guessDistribution: dist,
    );
  }
}
