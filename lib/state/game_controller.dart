import 'package:flutter/foundation.dart';

import '../branding.dart';
import '../data/word_repository.dart';
import '../logic/coin_rules.dart';
import '../logic/game_engine.dart';
import '../logic/share_formatter.dart';
import '../models/game_result.dart';
import '../models/letter_status.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/coin_service.dart';
import '../services/storage_service.dart';

enum GameMode { daily, journey }

/// Holds all game state. UI listens via ListenableBuilder. No widgets here.
class GameController extends ChangeNotifier {
  GameController({
    required WordRepository words,
    required StorageService storage,
    required CoinService coins,
    GameAds? ads,
    Analytics? analytics,
  })  : _words = words,
        _storage = storage,
        _coins = coins,
        _ads = ads ?? AdsService.instance,
        _analyticsOverride = analytics;

  final WordRepository _words;
  final StorageService _storage;
  final CoinService _coins;
  final GameAds _ads;

  // Read the live global unless a test injected an override, so events still
  // flow once async analytics init finishes after this controller is built.
  final Analytics? _analyticsOverride;
  Analytics get _analytics => _analyticsOverride ?? AnalyticsService.instance;

  // Guards the once-per-entry completion analytics (daily_completed /
  // streak_broken), so the rewarded extra-guess re-entry can't double-fire.
  bool _dailyResultLogged = false;

  /// Exposed for the settings screen (reminder prefs, onboarding flag).
  StorageService get storage => _storage;

  /// Current coin balance + a listenable so the app bar repaints on change.
  int get coins => _coins.coins;
  Listenable get coinsListenable => _coins;

  /// Exposed so the settings screen can run coin-gated theme unlocks.
  CoinService get coinService => _coins;

  static const int maxGuesses = 6;
  int get wordLength => WordRepository.wordLength;

  GameMode _mode = GameMode.daily;
  GameMode get mode => _mode;

  int _journeyLevel = 1;
  int get journeyLevel => _journeyLevel;

  /// The published 1-based daily puzzle number (presentation only).
  ///
  /// Snapshotted in [startGame] from the SAME instant the daily word is chosen,
  /// so the header number always matches the puzzle on screen — even if the app
  /// is left open across UTC midnight. It advances the next time the daily is
  /// (re)started, in lockstep with the word.
  int get dailyNumber => _dailyNumber;

  /// True when we're on Daily and the UTC date has advanced past the loaded
  /// puzzle — i.e. the app was open across midnight and the daily is now stale.
  /// The UI uses this on resume to roll the puzzle over live.
  bool get dailyNeedsRefresh =>
      _mode == GameMode.daily && _words.dailyNumber() != _dailyNumber;

  /// Journey chapter for the current level: 10 levels per chapter (1–10 → 1,
  /// 11–20 → 2, …). Presentation only — no persisted chapter model.
  int get journeyChapter => ((_journeyLevel - 1) ~/ 10) + 1;

  // Within-session retry counter for the current Journey level. Each retry
  // after a loss shows a different word (but the level number is unchanged).
  int _journeyAttempt = 0;
  String _journeyWord() =>
      _words.wordForLevel(_journeyLevel + _journeyAttempt * 7919);

  /// Social-proof stat for the current Journey level.
  int get journeySolvedPercent => solvedPercentForLevel(_journeyLevel);

  /// PLACEHOLDER social proof: a stable pseudo-random percentage (55–95)
  /// seeded by the level number, so every player sees the same number for a
  /// given level. Swap for a real server-backed "% solved" metric later.
  static int solvedPercentForLevel(int level) {
    var h = level * 2654435761;
    h ^= h >> 13;
    return 55 + (h.abs() % 41); // 55..95 inclusive
  }

  String _answer = '';
  int _dailyNumber = 0; // snapshot of the loaded daily's puzzle number
  final List<String> _guesses = [];
  String _current = '';
  bool _gameOver = false;
  bool _won = false;
  String? _message;

  late GameStats _stats = _storage.loadStats();

  // Public read-only views.
  List<String> get guesses => List.unmodifiable(_guesses);
  String get current => _current;
  bool get gameOver => _gameOver;
  bool get won => _won;
  String? get message => _message;
  String get answer => _answer;
  GameStats get stats => _stats;

  final Map<String, LetterStatus> _keyStatus = {};
  Map<String, LetterStatus> get keyStatus => Map.unmodifiable(_keyStatus);

  /// Positions revealed by a purchased hint, as position → letter. Persisted so
  /// a bought hint survives a restart instead of vanishing with its snackbar.
  final Map<int, String> _revealed = {};
  Map<int, String> get revealedHints => Map.unmodifiable(_revealed);

  /// Identifies the puzzle the reveals belong to, so they clear on a new daily
  /// date, a new journey level, AND a journey retry (which swaps in a different
  /// word for the same level).
  String get _hintScope => _mode == GameMode.daily
      ? 'd:${_storage.todayKey()}'
      : 'j:$_journeyLevel:$_journeyAttempt';

  /// Evaluated statuses for a submitted guess row.
  List<LetterStatus> statusesFor(String guess) =>
      GameEngine.evaluateGuess(guess, _answer);

  // --- Lifecycle -----------------------------------------------------------

  void startGame(GameMode mode) {
    _mode = mode;
    _guesses.clear();
    _current = '';
    _gameOver = false;
    _won = false;
    _message = null;
    _keyStatus.clear();
    _dailyResultLogged = false;

    if (mode == GameMode.daily) {
      // Choose the word and its published number from ONE instant, so the
      // header can never show a different day than the puzzle on screen.
      final now = DateTime.now();
      _answer = _words.dailyWord(now);
      _dailyNumber = _words.dailyNumber(now);
      // Restore today's progress if it exists.
      final saved = _storage.loadDailyGuesses();
      for (final g in saved) {
        _applyToKeyboard(g);
      }
      _guesses.addAll(saved);
      if (_storage.isDailyDone()) {
        _gameOver = true;
        // Read the stored outcome rather than inferring it from the guesses —
        // inference reports a loss whenever the board isn't available.
        _won = _storage.isDailyWon();
      }
      _analytics.logEvent(AnalyticsEvents.dailyStarted);
    } else {
      _journeyLevel = _storage.journeyLevel;
      _journeyAttempt =
          0; // fresh entry to a level starts at its canonical word
      _answer = _journeyWord();
      _analytics.logEvent(AnalyticsEvents.journeyLevelStarted,
          {AnalyticsParams.level: _journeyLevel});
    }

    // Restore hints bought for THIS puzzle (scope-checked, so a new date or
    // level yields nothing).
    _revealed
      ..clear()
      ..addAll(_storage.loadHints(_hintScope));

    notifyListeners();
  }

  /// Retries the current Journey level after a loss with a DIFFERENT word, so
  /// players don't just re-enter the word they already learned. The level
  /// number (and its "% solved" stat) stays the same.
  void retryJourneyLevel() {
    if (_mode != GameMode.journey) return;
    _journeyAttempt += 1;
    _guesses.clear();
    _current = '';
    _gameOver = false;
    _won = false;
    _message = null;
    _keyStatus.clear();
    // A retry is a different word, so previously revealed positions no longer
    // apply. (The stored copy is scoped to the old attempt and simply won't
    // load again.)
    _revealed.clear();
    _answer = _journeyWord();
    notifyListeners();
  }

  // --- Input ---------------------------------------------------------------

  void onKey(String key) {
    if (_gameOver) return;
    if (key == 'ENTER') {
      _submit();
    } else if (key == 'DEL') {
      if (_current.isNotEmpty) {
        _current = _current.substring(0, _current.length - 1);
        notifyListeners();
      }
    } else if (_current.length < wordLength) {
      _current += key;
      notifyListeners();
    }
  }

  Future<void> _submit() async {
    if (_current.length != wordLength) {
      _flash('Not enough letters');
      return;
    }
    if (!_words.isAllowed(_current)) {
      _flash('Not in word list');
      return;
    }
    if (_storage.hardMode && (_guesses.isNotEmpty || _revealed.isNotEmpty)) {
      final violation = GameEngine.hardModeViolation(
          _current, _guesses, _answer,
          revealed: _revealed);
      if (violation != null) {
        _flash('Hard mode: $violation');
        return;
      }
    }

    _applyToKeyboard(_current);
    _guesses.add(_current);
    final solved = _current == _answer;
    _current = '';

    if (solved) {
      _won = true;
      _gameOver = true;
      _message = _winMessage(_guesses.length);
    } else if (_guesses.length >= maxGuesses) {
      _gameOver = true;
      _message = 'Out of guesses — the word was $_answer';
    }

    if (_mode == GameMode.daily) {
      await _storage.saveDailyProgress(guesses: _guesses, done: _gameOver);
      if (_gameOver) {
        await _storage.saveDailyOutcome(won: _won);
        // Captured before recording, because recordDailyResult claims the date.
        final alreadyRecorded = _storage.isDailyRecorded();
        final prevStreak = _stats.currentStreak; // before recording
        _stats = await _storage.recordDailyResult(
          won: _won,
          guessesUsed: _won ? _guesses.length : null,
        );
        // Fire completion analytics at most once per entry (a rewarded extra
        // guess can re-run this block).
        if (!_dailyResultLogged) {
          _dailyResultLogged = true;
          _analytics.logEvent(AnalyticsEvents.dailyCompleted, {
            AnalyticsParams.solved: _won,
            AnalyticsParams.guessCount: _guesses.length,
            AnalyticsParams.streakAfter: _stats.currentStreak,
          });
          // streak_broken hooks into the SAME broken-streak value the restore
          // flow uses (recomputed once per completed daily). reason=loss when
          // the daily was lost, missed_day when a gap broke it but they still
          // returned and won today.
          if (_storage.pendingRestoreStreak() > 0 && prevStreak > 0) {
            _analytics.logEvent(AnalyticsEvents.streakBroken, {
              AnalyticsParams.previousStreak: prevStreak,
              AnalyticsParams.reason:
                  _won ? AnalyticsReasons.missedDay : AnalyticsReasons.loss,
            });
          }
          _analytics.syncStreak(_stats.currentStreak);
          _analytics.syncPlayed(_stats.gamesPlayed);
        }
        if (_won) {
          final reward = CoinRules.dailyWinReward(
            guessesUsed: _guesses.length,
            maxGuesses: maxGuesses,
            streak: _stats.currentStreak,
          );
          await _coins.award(reward);
          _analytics.logEvent(AnalyticsEvents.coinsEarned, {
            AnalyticsParams.amount: reward,
            AnalyticsParams.source: AnalyticsSources.dailyWin,
          });
          if (alreadyRecorded) {
            // Won on a reopened board (rewarded extra guess). The day's result
            // is already final, so don't imply the streak moved.
            _message = '${_winMessage(_guesses.length)}  '
                "Today's result was already recorded.";
          } else if (_stats.currentStreak >= 2) {
            // Celebrate the streak once it's worth bragging about.
            final milestone = CoinRules.isStreakMilestone(_stats.currentStreak);
            _message = '${_winMessage(_guesses.length)}  '
                '${milestone ? '🔥🔥' : '🔥'} ${_stats.currentStreak}-day streak'
                '${milestone ? '!' : ''}';
          }
        }
      }
    } else if (_gameOver && _won) {
      // Journey: a solved level counts as completed — advance, reward, (maybe) ad.
      final completedLevel = _journeyLevel;
      _journeyLevel += 1;
      await _storage.setJourneyLevel(_journeyLevel);
      final reward = CoinRules.journeyLevelReward(
        guessesUsed: _guesses.length,
        maxGuesses: maxGuesses,
      );
      await _coins.award(reward);
      _analytics.logEvent(AnalyticsEvents.journeyLevelCompleted, {
        AnalyticsParams.level: completedLevel,
        AnalyticsParams.guessCount: _guesses.length,
      });
      _analytics.logEvent(AnalyticsEvents.coinsEarned, {
        AnalyticsParams.amount: reward,
        AnalyticsParams.source: AnalyticsSources.journeyLevel,
      });
      _analytics.syncJourney(_journeyLevel);
      _ads.maybeShowJourneyInterstitial();
    }

    notifyListeners();
  }

  // --- Rewarded features ---------------------------------------------------

  /// The position a hint would reveal next: the first one not already solved by
  /// a guess AND not already revealed by an earlier hint. Null when there is
  /// nothing left to reveal — buying another hint would teach the player
  /// nothing, so it must not be sold.
  int? get _nextHintPosition {
    for (var i = 0; i < wordLength; i++) {
      if (_revealed.containsKey(i)) continue;
      final solvedHere =
          _guesses.any((g) => g.length > i && g[i] == _answer[i]);
      if (!solvedHere) return i;
    }
    return null;
  }

  /// Whether buying a hint would actually reveal something new. Drives the
  /// hint button's enabled state.
  ///
  /// Intentionally NOT gated on affordability: a player who can't pay should
  /// still be able to tap and get nudged toward watch-to-earn.
  bool get canUseHint => !_gameOver && _nextHintPosition != null;

  /// Reveals one not-yet-known position. Costs coins; if the player can't
  /// afford it, they're nudged to the watch-to-earn action.
  Future<void> useHint() async {
    if (_gameOver) return;
    // Resolve the target BEFORE spending — otherwise a hint with nothing left
    // to reveal would charge for no information.
    final position = _nextHintPosition;
    if (position == null) {
      _flash('Every letter is already revealed');
      return;
    }
    if (!await _coins.trySpend(CoinRules.hintCost)) {
      _flash('Need ${CoinRules.hintCost} coins — tap the coin to watch & earn');
      return;
    }
    _analytics.logEvent(AnalyticsEvents.coinsSpent, {
      AnalyticsParams.amount: CoinRules.hintCost,
      AnalyticsParams.sink: AnalyticsSinks.hint,
    });
    _analytics.logEvent(
        AnalyticsEvents.hintUsed, {AnalyticsParams.mode: _mode.name});
    await _revealAt(position);
  }

  /// Records and persists the reveal at [i], then confirms it with a flash.
  Future<void> _revealAt(int i) async {
    _revealed[i] = _answer[i];
    await _storage.saveHints(_hintScope, _revealed);
    _flash('Hint: position ${i + 1} is "${_answer[i]}"');
  }

  /// Grants one extra guess beyond the normal max. Costs coins.
  Future<void> useExtraGuess() async {
    if (!_gameOver || _won) return;
    // An "extra" guess on a board with no guesses is meaningless — there is
    // nothing to extend. Reachable when a finished board has no guesses to
    // restore, and never worth charging for.
    if (_guesses.isEmpty) return;
    if (!await _coins.trySpend(CoinRules.extraGuessCost)) {
      _flash(
          'Need ${CoinRules.extraGuessCost} coins — tap the coin to watch & earn');
      return;
    }
    _analytics.logEvent(AnalyticsEvents.coinsSpent, {
      AnalyticsParams.amount: CoinRules.extraGuessCost,
      AnalyticsParams.sink: AnalyticsSinks.extraGuess,
    });
    _gameOver = false;
    _flash('Extra guess granted');
    notifyListeners();
  }

  /// Opt-in "watch ad → earn coins". Only awards on a real, earned view.
  Future<void> watchAdForCoins() async {
    if (!await _ads.showRewarded()) {
      _flash('No ad available — try again in a moment');
      return;
    }
    await _coins.award(CoinRules.watchAdReward);
    _analytics.logEvent(AnalyticsEvents.coinsEarned, {
      AnalyticsParams.amount: CoinRules.watchAdReward,
      AnalyticsParams.source: AnalyticsSources.watchAd,
    });
    _flash('+${CoinRules.watchAdReward} coins!');
  }

  /// Builds the shareable result text (our own emoji style). Returns null when
  /// there's nothing to share yet (no guesses submitted).
  String? get shareText {
    if (_guesses.isEmpty) return null;
    return ShareFormatter.build(
      appName: Branding.appName,
      dayNumber: _mode == GameMode.daily ? _words.dailyNumber() : null,
      guesses: _guesses,
      answer: _answer,
      won: _won,
      maxGuesses: maxGuesses,
    );
  }

  /// True when the just-finished daily broke a streak that a rewarded ad could
  /// bring back. Drives the "Restore streak" offer in the stats sheet.
  bool get canRestoreStreak =>
      _mode == GameMode.daily &&
      _gameOver &&
      _storage.pendingRestoreStreak() > 0;

  /// Restores a broken streak after the user watches a rewarded ad (only on a
  /// real view).
  Future<void> restoreStreak() async {
    if (!canRestoreStreak) return;
    if (!await _ads.showRewarded()) {
      _flash('No ad available — try again in a moment');
      return;
    }
    _stats = await _storage.restoreStreak();
    _flash('Streak restored to ${_stats.currentStreak}!');
    notifyListeners();
  }

  // --- helpers -------------------------------------------------------------

  void _applyToKeyboard(String guess) {
    final statuses = GameEngine.evaluateGuess(guess, _answer);
    for (var i = 0; i < guess.length; i++) {
      final c = guess[i];
      final s = statuses[i];
      final prev = _keyStatus[c];
      if (prev == null || s.rank > prev.rank) {
        _keyStatus[c] = s;
      }
    }
  }

  /// Praise scaled to how few guesses it took.
  String _winMessage(int guesses) {
    const praise = [
      'Genius!', // 1
      'Magnificent!', // 2
      'Impressive!', // 3
      'Splendid!', // 4
      'Great!', // 5
      'Phew!', // 6
    ];
    final i = (guesses - 1).clamp(0, praise.length - 1);
    return praise[i];
  }

  void _flash(String msg) {
    _message = msg;
    notifyListeners();
  }

  void clearMessage() => _message = null;
}
