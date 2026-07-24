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
  static const _kBrokenStreak =
      'broken_streak'; // streak value a rewarded ad can restore
  static const _kReminderEnabled = 'reminder_enabled'; // bool
  static const _kReminderHour = 'reminder_hour'; // int 0..23
  static const _kReminderMinute = 'reminder_minute'; // int 0..59
  static const _kOnboardingSeen = 'onboarding_seen'; // bool
  static const _kJourneyLevel = 'journey_level'; // int, 1-based current level
  static const _kCoins = 'coins'; // int, soft currency balance
  static const _kHardMode = 'hard_mode'; // bool: revealed hints must be reused
  static const _kSelectedTheme = 'selected_theme'; // string theme id
  static const _kUnlockedThemes = 'unlocked_themes'; // csv of unlocked ids
  static const _kDailyMapVersion =
      'daily_map_version'; // int; which daily word-mapping produced the board
  static const _kHintScope = 'hint_scope'; // which puzzle the reveals belong to
  static const _kHintReveals = 'hint_reveals'; // csv of "index:letter"

  /// Bumped whenever the daily word→date mapping changes, so boards saved under
  /// an older mapping can be invalidated. v2 = shuffled permutation (v1, the
  /// implicit default for existing installs, walked the alphabetical list).
  static const int _dailyMappingVersion = 2;

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateDailyMapping();
  }

  /// One-time migration for the daily remap (alphabetical → shuffled).
  ///
  /// A board saved before the remap was played against a DIFFERENT word, so
  /// restoring its guesses would render nonsense feedback. Detection: the
  /// absence of [_kDailyMapVersion] means "written under the old mapping"
  /// (fresh installs have no board either way, so this is a no-op for them).
  ///
  /// Deliberately narrow — stats, streak, broken-streak, coins, themes, journey
  /// level and every setting are left untouched.
  Future<void> _migrateDailyMapping() async {
    if ((_prefs.getInt(_kDailyMapVersion) ?? 1) >= _dailyMappingVersion) return;

    final wasDone = _prefs.getBool(_kDailyDone) ?? false;
    // Guesses were played against the old word — always drop them.
    await _prefs.remove(_kDailyGuesses);
    if (!wasDone) {
      // In-progress board: clear it so today restarts cleanly on the new word.
      await _prefs.remove(_kDailyDate);
      await _prefs.remove(_kDailyDone);
    }
    // A FINISHED daily keeps its date + done flag, so today stays locked. If we
    // cleared them the player could replay today, and recordDailyResult would
    // run a second time for the same date — which resets the streak to 1 and
    // reports a bogus "missed day" break.
    await _prefs.setInt(_kDailyMapVersion, _dailyMappingVersion);
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
    final prevStreak = s.currentStreak;

    final dist = List<int>.from(s.guessDistribution);
    if (won && guessesUsed != null && guessesUsed < dist.length) {
      dist[guessesUsed] += 1;
    }

    int newStreak;
    int brokenStreak = 0; // > 0 => a non-trivial streak just ended; restorable.
    if (won) {
      final last = _prefs.getString(_kLastWonDate);
      if (_isYesterday(last, today)) {
        newStreak = prevStreak + 1; // consecutive day: keep building.
      } else {
        // First win, or a gap since the last win. A real streak was broken.
        newStreak = 1;
        if (prevStreak > 0) {
          brokenStreak = prevStreak + 1; // bridge the gap + today.
        }
      }
      await _prefs.setString(_kLastWonDate, today);
    } else {
      newStreak = 0;
      if (prevStreak > 0) brokenStreak = prevStreak; // a loss ended the streak.
    }

    await _prefs.setInt(_kBrokenStreak, brokenStreak);

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

  /// The streak value a rewarded "restore streak" can bring back after the most
  /// recent finished daily, or 0 if there is nothing to restore.
  int pendingRestoreStreak() => _prefs.getInt(_kBrokenStreak) ?? 0;

  /// Restores a broken streak (called after the user watches a rewarded ad).
  /// Marks today as won so tomorrow's win continues the run, and clears the
  /// pending restore so it can only be redeemed once. Returns updated stats.
  Future<GameStats> restoreStreak({DateTime? now}) async {
    final pending = pendingRestoreStreak();
    if (pending <= 0) return loadStats();
    final today = _dayKey(now ?? DateTime.now());
    final s = loadStats();
    final restored = s.copyWith(
      currentStreak: pending,
      bestStreak: pending > s.bestStreak ? pending : s.bestStreak,
    );
    await _prefs.setString(_kLastWonDate, today);
    await _prefs.setInt(_kBrokenStreak, 0);
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

  // --- Revealed hints ------------------------------------------------------

  /// Positions revealed by a purchased hint for [scope], as position → letter.
  ///
  /// Reveals are scoped to a single puzzle (a daily date, or a journey
  /// level+attempt). If the stored scope doesn't match, they belong to a
  /// different puzzle and are ignored — which is how they "expire".
  Map<int, String> loadHints(String scope) {
    if (_prefs.getString(_kHintScope) != scope) return const {};
    final csv = _prefs.getString(_kHintReveals) ?? '';
    if (csv.isEmpty) return const {};
    final out = <int, String>{};
    for (final part in csv.split(',')) {
      final bits = part.split(':');
      if (bits.length != 2) continue;
      final i = int.tryParse(bits[0]);
      if (i == null || bits[1].isEmpty) continue;
      out[i] = bits[1];
    }
    return out;
  }

  Future<void> saveHints(String scope, Map<int, String> reveals) async {
    await _prefs.setString(_kHintScope, scope);
    final keys = reveals.keys.toList()..sort();
    await _prefs.setString(
      _kHintReveals,
      keys.map((i) => '$i:${reveals[i]}').join(','),
    );
  }

  Future<void> clearHints() async {
    await _prefs.remove(_kHintScope);
    await _prefs.remove(_kHintReveals);
  }

  /// UTC day key (yyyy-mm-dd), used to scope per-day state such as hints.
  String todayKey([DateTime? now]) => _dayKey(now ?? DateTime.now());

  // --- Daily reminder settings --------------------------------------------

  bool get reminderEnabled => _prefs.getBool(_kReminderEnabled) ?? true;
  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 9;
  int get reminderMinute => _prefs.getInt(_kReminderMinute) ?? 0;

  Future<void> setReminderEnabled(bool value) =>
      _prefs.setBool(_kReminderEnabled, value);

  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt(_kReminderHour, hour);
    await _prefs.setInt(_kReminderMinute, minute);
  }

  // --- Onboarding ----------------------------------------------------------

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;
  Future<void> setOnboardingSeen() => _prefs.setBool(_kOnboardingSeen, true);

  // --- Journey progression -------------------------------------------------

  /// Current 1-based Journey level (defaults to level 1).
  int get journeyLevel => _prefs.getInt(_kJourneyLevel) ?? 1;
  Future<void> setJourneyLevel(int level) =>
      _prefs.setInt(_kJourneyLevel, level < 1 ? 1 : level);

  // --- Coins ---------------------------------------------------------------

  int get coins => _prefs.getInt(_kCoins) ?? 0;
  Future<void> setCoins(int value) =>
      _prefs.setInt(_kCoins, value < 0 ? 0 : value);

  // --- Difficulty ----------------------------------------------------------

  bool get hardMode => _prefs.getBool(_kHardMode) ?? false;
  Future<void> setHardMode(bool value) => _prefs.setBool(_kHardMode, value);

  // --- Themes --------------------------------------------------------------

  /// Selected board theme id (defaults to the free 'cozy' theme).
  String get selectedThemeId => _prefs.getString(_kSelectedTheme) ?? 'cozy';
  Future<void> setSelectedThemeId(String id) =>
      _prefs.setString(_kSelectedTheme, id);

  /// Ids of paid themes the player has unlocked (free themes aren't stored).
  Set<String> get unlockedThemes {
    final csv = _prefs.getString(_kUnlockedThemes) ?? '';
    return csv.isEmpty ? <String>{} : csv.split(',').toSet();
  }

  Future<void> addUnlockedTheme(String id) async {
    final set = unlockedThemes..add(id);
    await _prefs.setString(_kUnlockedThemes, set.join(','));
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
