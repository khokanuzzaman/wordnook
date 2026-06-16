import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_result.dart';

/// Persists stats, streaks, and today's daily progress via shared_preferences.
///
/// Streak rule: winning on consecutive calendar days increments the streak.
/// Missing a day (gap > 1) resets it. Losing also resets the current streak.
class StorageService {
  static const _kStats = 'stats_v1';
  static const _kLastWonDate = 'last_won_date'; // yyyy-mm-dd (UTC)
  static const _kDailyDate = 'daily_date'; // yyyy-mm-dd of saved board
  static const _kDailyGuesses = 'daily_guesses'; // csv of guesses
  static const _kDailyDone = 'daily_done'; // bool

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Stats ---------------------------------------------------------------

  GameStats loadStats() {
    final raw = _prefs.getString(_kStats);
    if (raw == null) return const GameStats();
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GameStats();
    }
  }

  Future<void> _saveStats(GameStats s) async {
    await _prefs.setString(_kStats, jsonEncode(s.toJson()));
  }

  /// Records a finished DAILY game and updates streak + distribution.
  /// [guessesUsed] is 1..maxGuesses on a win, or null on a loss.
  Future<GameStats> recordDailyResult({
    required bool won,
    int? guessesUsed,
    DateTime? now,
  }) async {
    final today = _dayKey(now ?? DateTime.now());
    var s = loadStats();

    final dist = List<int>.from(s.guessDistribution);
    if (won && guessesUsed != null && guessesUsed < dist.length) {
      dist[guessesUsed] += 1;
    }

    int newStreak;
    if (won) {
      final last = _prefs.getString(_kLastWonDate);
      newStreak = _isYesterday(last, today) ? s.currentStreak + 1 : 1;
      await _prefs.setString(_kLastWonDate, today);
    } else {
      newStreak = 0;
    }

    s = s.copyWith(
      gamesPlayed: s.gamesPlayed + 1,
      gamesWon: s.gamesWon + (won ? 1 : 0),
      currentStreak: newStreak,
      bestStreak: newStreak > s.bestStreak ? newStreak : s.bestStreak,
      guessDistribution: dist,
    );
    await _saveStats(s);
    return s;
  }

  /// Allows "restore streak" via a rewarded ad after a missed day / loss.
  Future<GameStats> restoreStreak(int toValue) async {
    final s = loadStats();
    final restored = s.copyWith(
      currentStreak: toValue,
      bestStreak: toValue > s.bestStreak ? toValue : s.bestStreak,
    );
    await _saveStats(restored);
    return restored;
  }

  // --- Daily board persistence --------------------------------------------

  bool isDailyDone([DateTime? now]) {
    final today = _dayKey(now ?? DateTime.now());
    return _prefs.getString(_kDailyDate) == today &&
        (_prefs.getBool(_kDailyDone) ?? false);
  }

  /// Restores today's submitted guesses if the saved board is from today.
  List<String> loadDailyGuesses([DateTime? now]) {
    final today = _dayKey(now ?? DateTime.now());
    if (_prefs.getString(_kDailyDate) != today) return [];
    final csv = _prefs.getString(_kDailyGuesses) ?? '';
    return csv.isEmpty ? [] : csv.split(',');
  }

  Future<void> saveDailyProgress({
    required List<String> guesses,
    required bool done,
    DateTime? now,
  }) async {
    final today = _dayKey(now ?? DateTime.now());
    await _prefs.setString(_kDailyDate, today);
    await _prefs.setString(_kDailyGuesses, guesses.join(','));
    await _prefs.setBool(_kDailyDone, done);
  }

  // --- helpers -------------------------------------------------------------

  String _dayKey(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  bool _isYesterday(String? prev, String today) {
    if (prev == null) return false;
    final p = DateTime.tryParse(prev);
    final t = DateTime.tryParse(today);
    if (p == null || t == null) return false;
    return t.difference(p).inDays == 1;
  }
}
