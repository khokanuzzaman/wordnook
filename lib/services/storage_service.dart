import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_result.dart';

/// Persists stats, streaks, and today's daily progress via shared_preferences.
///
/// Streak rule: winning on consecutive calendar days increments the streak.
/// Missing a day (gap > 1) resets it. Losing also resets the current streak.
class StorageService {
  static const _kStats = 'stats_v1';
  static const _kLastWonDate = 'last_won_date'; // yyyy-mm-dd (local day)
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
      'daily_map_version'; // int; storage schema version (see _schemaVersion)
  static const _kHintScope = 'hint_scope'; // which puzzle the reveals belong to
  static const _kHintReveals = 'hint_reveals'; // csv of "index:letter"
  static const _kLastRecordedDate =
      'last_recorded_date'; // yyyy-mm-dd of the last recorded daily result
  static const _kDailyWon = 'daily_won'; // bool: outcome of the saved board
  static const _kWelcomeCoins = 'welcome_coins_granted'; // bool, one-time
  static const _kDailyExtraRows =
      'daily_extra_rows'; // int: rows bought for the board at [_kDailyDate]

  /// Storage schema version. Bumped whenever persisted state needs a one-time
  /// fix-up on upgrade.
  ///   v1 — implicit default for existing installs
  ///   v2 — daily word mapping changed (alphabetical → shuffled permutation)
  ///   v3 — backfill [_kLastRecordedDate] for the idempotency guard
  ///   v4 — backfill [_kDailyWon] so the outcome is stored, not inferred
  ///   v5 — backfill [_kOnboardingSeen] for existing players (new tutorial)
  ///   v6 — day keys switch from UTC to the device's local date
  ///   v7 — Journey words now follow difficulty tiers; drop stale journey hints
  static const int _schemaVersion = 7;

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrate();
  }

  /// Runs the one-time upgrade steps, in order, for whatever version this
  /// install is on. Deliberately narrow — no step may touch stats, streak,
  /// coins, themes, journey level or any setting.
  Future<void> _migrate() async {
    final from = _prefs.getInt(_kDailyMapVersion) ?? 1;
    if (from >= _schemaVersion) return;
    if (from < 2) await _migrateToV2();
    if (from < 3) await _migrateToV3();
    if (from < 4) await _migrateToV4();
    if (from < 5) await _migrateToV5();
    if (from < 6) await _migrateToV6();
    if (from < 7) await _migrateToV7();
    await _prefs.setInt(_kDailyMapVersion, _schemaVersion);
  }

  /// v2 — the daily remap (alphabetical → shuffled).
  ///
  /// A board saved before the remap was played against a DIFFERENT word, so
  /// restoring its guesses would render nonsense feedback.
  Future<void> _migrateToV2() async {
    final wasDone = _prefs.getBool(_kDailyDone) ?? false;
    // Guesses were played against the old word — always drop them.
    await _prefs.remove(_kDailyGuesses);
    if (!wasDone) {
      // In-progress board: clear it so today restarts cleanly on the new word.
      await _prefs.remove(_kDailyDate);
      await _prefs.remove(_kDailyDone);
    }
    // A FINISHED daily keeps its date + done flag, so today stays locked.
  }

  /// v3 — backfill [_kLastRecordedDate].
  ///
  /// The idempotency guard in [recordDailyResult] is new, so nobody upgrading
  /// has the key. Without this, someone who already completed today's daily on
  /// an older build could still double-record today. A finished board means the
  /// result for that date was already written, so the date is derivable — no
  /// guessing and nothing destructive.
  Future<void> _migrateToV3() async {
    if (_prefs.getString(_kLastRecordedDate) != null) return;
    final done = _prefs.getBool(_kDailyDone) ?? false;
    final date = _prefs.getString(_kDailyDate);
    if (done && date != null) {
      await _prefs.setString(_kLastRecordedDate, date);
    }
  }

  /// v4 — backfill [_kDailyWon].
  ///
  /// The outcome used to be inferred from the guess list, which is why clearing
  /// a stale board in v2 produced a "you lost" screen for a day that was won.
  /// For a finished board, the day was a win exactly when [_kLastWonDate] is
  /// that same day — the only signal older data carries, and an accurate one.
  Future<void> _migrateToV4() async {
    if (_prefs.containsKey(_kDailyWon)) return;
    if (!(_prefs.getBool(_kDailyDone) ?? false)) return;
    final date = _prefs.getString(_kDailyDate);
    if (date == null) return;
    await _prefs.setBool(_kDailyWon, _prefs.getString(_kLastWonDate) == date);
  }

  /// v5 — backfill [_kOnboardingSeen] for existing players.
  ///
  /// The interactive tutorial is new. An upgrading player already knows the
  /// game and must never be dropped into it. If the device carries ANY prior
  /// gameplay state but no onboarding flag, mark onboarding as seen. A genuinely
  /// fresh install (no state, no flag) is left untouched so it still gets the
  /// tutorial.
  ///
  /// Only gameplay-produced signals count — [_kDailyMapVersion] is written by
  /// the migration itself and is deliberately NOT treated as prior state.
  Future<void> _migrateToV5() async {
    if (_prefs.getBool(_kOnboardingSeen) ?? false) return;
    if (_hasPriorGameState()) {
      await _prefs.setBool(_kOnboardingSeen, true);
    }
  }

  /// v6 — day keys move from the UTC date to the device's LOCAL date.
  ///
  /// West of UTC (the US), a result recorded in the evening was keyed to the
  /// NEXT UTC day, so after this switch that key can sit one day in the
  /// future. Left alone, "yesterday" would never match and the next win would
  /// reset a real streak. So: clamp any future-dated streak key to today, and
  /// drop a future-dated board (otherwise it would resurface tomorrow as "done"
  /// and block that day's play, breaking the streak a day later).
  /// [now] is a test seam.
  Future<void> _migrateToV6([DateTime? now]) async {
    final today = _dayKey(now ?? DateTime.now());
    for (final key in [_kLastWonDate, _kLastRecordedDate]) {
      final v = _prefs.getString(key);
      if (v != null && v.compareTo(today) > 0) {
        await _prefs.setString(key, today);
      }
    }
    final board = _prefs.getString(_kDailyDate);
    if (board != null && board.compareTo(today) > 0) {
      await _prefs.remove(_kDailyDate);
      await _prefs.remove(_kDailyGuesses);
      await _prefs.remove(_kDailyDone);
      await _prefs.remove(_kDailyWon);
      await _prefs.remove(_kDailyExtraRows);
    }
  }

  /// v7 — Journey levels now draw from difficulty tiers, so the word for an
  /// in-progress level may have changed. A hint bought for the OLD word would
  /// show a wrong letter on the new one, so drop journey-scoped reveals. Daily
  /// reveals ("d:" scopes) are untouched — the daily word did not change.
  Future<void> _migrateToV7() async {
    final scope = _prefs.getString(_kHintScope);
    if (scope != null && scope.startsWith('j:')) {
      await _prefs.remove(_kHintScope);
      await _prefs.remove(_kHintReveals);
    }
  }

  /// Test seam for the v6 clamp with an injected clock.
  @visibleForTesting
  Future<void> debugMigrateToV6(DateTime now) => _migrateToV6(now);

  /// True if the device shows any sign of prior play (used only by the v5
  /// onboarding backfill).
  bool _hasPriorGameState() {
    final s = loadStats();
    if (s.gamesPlayed > 0 || s.currentStreak > 0 || s.bestStreak > 0) {
      return true;
    }
    if (_prefs.getString(_kLastWonDate) != null) return true; // won a daily
    if (_prefs.getString(_kDailyDate) != null) return true; // played a daily
    if (_prefs.getString(_kLastRecordedDate) != null) return true;
    if ((_prefs.getInt(_kJourneyLevel) ?? 1) > 1) return true; // journey progress
    if ((_prefs.getInt(_kCoins) ?? 0) > 0) return true; // earned coins
    if ((_prefs.getString(_kUnlockedThemes) ?? '').isNotEmpty) return true;
    if (_prefs.getString(_kSelectedTheme) != null) return true; // picked a theme
    return false;
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
  ///
  /// IDEMPOTENT PER (LOCAL) DATE: a date's result is recorded exactly once, and the
  /// first result for a date is final. Any later call for the same date is a
  /// complete no-op — stats, streak, [_kLastWonDate] and [_kBrokenStreak] are
  /// all left alone.
  ///
  /// Without this, a second call for the same day (a rewarded extra guess
  /// re-completing a finished daily) silently corrupted the streak: with
  /// [_kLastWonDate] already set to today, the "consecutive day" test fails, so
  /// the streak collapses to 1 and a bogus broken-streak is reported. Streak and
  /// stats are the one thing a player cannot restore themselves, so this is
  /// enforced at the write, not at the call sites.
  Future<GameStats> recordDailyResult({
    required bool won,
    int? guessesUsed,
    DateTime? now,
  }) async {
    final today = _dayKey(now ?? DateTime.now());
    if (_prefs.getString(_kLastRecordedDate) == today) return loadStats();

    var s = loadStats();
    final prevStreak = s.currentStreak;

    final dist = List<int>.from(s.guessDistribution);
    if (won && guessesUsed != null && guessesUsed > 0 && dist.isNotEmpty) {
      // A win on a bought extra row (7th guess) counts in the last bucket
      // ("6+"), so the bars always add up to games won.
      final i = guessesUsed < dist.length ? guessesUsed : dist.length - 1;
      dist[i] += 1;
    }

    int newStreak;
    int brokenStreak = 0; // > 0 => a non-trivial streak just ended; restorable.
    final lastWon = _prefs.getString(_kLastWonDate);
    if (lastWon == today) {
      // Today's streak day is ALREADY earned before any daily was recorded —
      // only the first-run tutorial does this ([beginStreakFromOnboarding]).
      // Playing today's real daily must neither re-count nor "break" it:
      // treating it as a gap used to offer a brand-new player a
      // "Restore streak (watch ad)" on day one.
      newStreak = prevStreak > 0 ? prevStreak : (won ? 1 : 0);
    } else if (won) {
      final last = lastWon;
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
    // Claim this date so no later call can rewrite it.
    await _prefs.setString(_kLastRecordedDate, today);
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
    // Stamp the day whose result broke the streak — not the clock's day. If
    // the sheet sat open past midnight, stamping "today" would pre-credit the
    // new day, so its real daily could no longer break the streak.
    await _prefs.setString(
        _kLastWonDate, _prefs.getString(_kLastRecordedDate) ?? today);
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

  /// Whether today's finished board was a win.
  ///
  /// Stored explicitly rather than inferred from the guess list: inference
  /// breaks whenever the guesses aren't available (e.g. after a migration
  /// clears a stale board), which silently rendered a won day as a loss.
  bool isDailyWon([DateTime? now]) {
    final today = _dayKey(now ?? DateTime.now());
    return _prefs.getString(_kDailyDate) == today &&
        (_prefs.getBool(_kDailyWon) ?? false);
  }

  /// Records the outcome of today's finished board.
  Future<void> saveDailyOutcome({required bool won, DateTime? now}) async {
    await _prefs.setString(_kDailyDate, _dayKey(now ?? DateTime.now()));
    await _prefs.setBool(_kDailyWon, won);
  }

  /// Whether a result has already been counted for today (see
  /// [recordDailyResult]). Lets the UI explain that a later win on a reopened
  /// board won't change the recorded result.
  bool isDailyRecorded([DateTime? now]) =>
      _prefs.getString(_kLastRecordedDate) == _dayKey(now ?? DateTime.now());

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
    if (_prefs.getString(_kDailyDate) != today) {
      await _prefs.remove(_kDailyExtraRows); // a new day starts with none
    }
    await _prefs.setString(_kDailyDate, today);
    await _prefs.setString(_kDailyGuesses, guesses.join(','));
    await _prefs.setBool(_kDailyDone, done);
  }

  /// Rows bought ("Keep going?") for TODAY's board; 0 for any other day.
  int loadDailyExtraRows([DateTime? now]) {
    if (_prefs.getString(_kDailyDate) != _dayKey(now ?? DateTime.now())) {
      return 0;
    }
    return _prefs.getInt(_kDailyExtraRows) ?? 0;
  }

  /// Persists the rows bought for today's board, so a restart between buying
  /// and guessing can't make the player pay twice.
  Future<void> saveDailyExtraRows(int rows, {DateTime? now}) async {
    await _prefs.setString(_kDailyDate, _dayKey(now ?? DateTime.now()));
    await _prefs.setInt(_kDailyExtraRows, rows);
  }

  /// A board from an EARLIER day that was left full but unfinished — the app
  /// closed while "Keep going?" was open and the player never came back that
  /// day. Returns that day (as a date) so its loss can still be recorded, or
  /// null when there is nothing to settle. [fullAt] is the normal row count.
  DateTime? abandonedBoardDate(int fullAt, [DateTime? now]) {
    final date = _prefs.getString(_kDailyDate);
    // Strictly earlier days only (a clock moved backwards must not record a
    // "future" loss).
    if (date == null || date.compareTo(_dayKey(now ?? DateTime.now())) >= 0) {
      return null;
    }
    if (_prefs.getBool(_kDailyDone) ?? false) return null;
    final rows = (_prefs.getString(_kDailyGuesses) ?? '')
        .split(',')
        .where((g) => g.isNotEmpty)
        .length;
    if (rows < fullAt) return null;
    if ((_prefs.getString(_kLastRecordedDate) ?? '').compareTo(date) >= 0) {
      return null; // that day (or a later one) is already recorded
    }
    final d = _parseDayKey(date);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day, 12);
  }

  /// Marks the board at [day] finished as a loss (after it was recorded).
  Future<void> closeAbandonedBoard(DateTime day) async {
    // Only if that old board is still the saved one — never overwrite a board
    // saved for today in the meantime.
    if (_prefs.getString(_kDailyDate) != _dayKey(day)) return;
    await _prefs.setBool(_kDailyDone, true);
    await _prefs.setBool(_kDailyWon, false);
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

  /// Local day key (yyyy-mm-dd), used to scope per-day state such as hints.
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

  /// Seeds the real streak from a WON tutorial: the tutorial counts as today's
  /// streak-day, so the win screen's "1" is truthful and tomorrow's daily win
  /// makes it two.
  ///
  /// Sets currentStreak/bestStreak and marks [_kLastWonDate] = today. Does NOT
  /// touch gamesPlayed/gamesWon/distribution, [_kLastRecordedDate], the daily
  /// board, or coins — so today's real daily is still fully playable and still
  /// counts. No-op if a streak already exists (defensive; onboarding runs once).
  Future<GameStats> beginStreakFromOnboarding({DateTime? now}) async {
    final today = _dayKey(now ?? DateTime.now());
    var s = loadStats();
    if (s.currentStreak < 1) {
      s = s.copyWith(
        currentStreak: 1,
        bestStreak: s.bestStreak < 1 ? 1 : s.bestStreak,
      );
      await _saveStats(s);
    }
    await _prefs.setString(_kLastWonDate, today);
    return s;
  }

  // --- Journey progression -------------------------------------------------

  /// Current 1-based Journey level (defaults to level 1).
  int get journeyLevel => _prefs.getInt(_kJourneyLevel) ?? 1;
  Future<void> setJourneyLevel(int level) =>
      _prefs.setInt(_kJourneyLevel, level < 1 ? 1 : level);

  // --- Coins ---------------------------------------------------------------

  int get coins => _prefs.getInt(_kCoins) ?? 0;

  /// Adds the one-time welcome balance. Returns false (and adds nothing) if it
  /// was already granted on this install.
  Future<bool> grantWelcomeCoins(int amount) async {
    if (_prefs.getBool(_kWelcomeCoins) ?? false) return false;
    await _prefs.setBool(_kWelcomeCoins, true);
    await setCoins(coins + amount);
    return true;
  }
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

  /// Calendar-day key (yyyy-mm-dd) for [dt], read from [dt]'s OWN calendar
  /// fields with no time-zone conversion. In the app every caller passes
  /// `DateTime.now()` (device-local), so the daily rolls over at the player's
  /// local midnight. Tests may pass a UTC instant to pin an exact date.
  String _dayKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  bool _isYesterday(String? prev, String today) {
    final p = _parseDayKey(prev);
    final t = _parseDayKey(today);
    if (p == null || t == null) return false;
    return t.difference(p).inDays == 1;
  }

  /// Parses a yyyy-mm-dd key as a UTC date. UTC (not local) so a day-length
  /// change at a DST switch (23h / 25h) can never make "yesterday" look like
  /// 0 or 2 days ago and silently break a streak.
  static DateTime? _parseDayKey(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }
}
