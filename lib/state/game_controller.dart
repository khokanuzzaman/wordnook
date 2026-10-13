import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../branding.dart';
import '../data/word_repository.dart';
import '../logic/coin_rules.dart';
import '../logic/game_engine.dart';
import '../logic/share_formatter.dart';
import '../logic/tips.dart';
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
  // streak_broken), so a re-entry can never double-fire them.
  bool _dailyResultLogged = false;

  /// Exposed for the settings screen (reminder prefs, onboarding flag).
  StorageService get storage => _storage;

  /// Current coin balance + a listenable so the app bar repaints on change.
  int get coins => _coins.coins;
  Listenable get coinsListenable => _coins;

  /// Exposed so the settings screen can run coin-gated theme unlocks.
  CoinService get coinService => _coins;

  static const int maxGuesses = 6;

  /// How many extra rows a player may buy per puzzle via "Keep going?".
  static const int maxExtraRows = 1;

  /// Warm-up Journey levels a brand-new player plays before the Daily.
  static const int firstStepsLevels = 3;

  /// Journey levels a new player clears before any interstitial can show.
  static const int journeyAdGraceLevels = 8;
  int get wordLength => WordRepository.wordLength;

  GameMode _mode = GameMode.daily;
  GameMode get mode => _mode;

  int _journeyLevel = 1;
  int get journeyLevel => _journeyLevel;

  /// The published 1-based daily puzzle number (presentation only).
  ///
  /// Snapshotted in [startGame] from the SAME instant the daily word is chosen,
  /// so the header number always matches the puzzle on screen — even if the app
  /// is left open across midnight. It advances the next time the daily is
  /// (re)started, in lockstep with the word.
  int get dailyNumber => _dailyNumber;

  /// True when we're on Daily and the local date has advanced past the loaded
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
      _words.journeyWord(_journeyLevel, attempt: _journeyAttempt);

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

  // "Keep going?" — offered on the last miss BEFORE the result is recorded, so
  // an extra row can still save the day (and the streak).
  int _extraRows = 0;
  bool _awaitingContinue = false;
  bool _settlingAbandoned = false;
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

  /// Rows available on this puzzle: the normal six plus any bought extras.
  int get maxRows => maxGuesses + _extraRows;

  /// True while the "Keep going?" offer is open: every normal row is used, the
  /// word is unsolved, and nothing has been recorded yet.
  bool get awaitingContinue => _awaitingContinue;

  /// Whether another extra row can still be bought on this puzzle.
  bool get canContinue => _extraRows < maxExtraRows;

  /// Whether the board takes typing right now.
  bool get acceptingInput => !_gameOver && !_awaitingContinue;

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
    _extraRows = 0;
    _awaitingContinue = false;

    if (mode == GameMode.daily) {
      // Choose the word and its published number from ONE instant, so the
      // header can never show a different day than the puzzle on screen.
      final now = DateTime.now();
      _answer = _words.dailyWord(now);
      _dailyNumber = _words.dailyNumber(now);
      // Settle a previous day's board that was left at "Keep going?".
      final abandoned = _storage.abandonedBoardDate(maxGuesses, now);
      if (abandoned != null && !_settlingAbandoned) {
        unawaited(_recordAbandoned(abandoned));
      }
      // Restore today's progress if it exists.
      final saved = _storage.loadDailyGuesses();
      for (final g in saved) {
        _applyToKeyboard(g);
      }
      _guesses.addAll(saved);
      // Rows bought earlier today survive a restart (stored, or implied by a
      // 7th guess on the board).
      _extraRows = math
          .max(_storage.loadDailyExtraRows(now), saved.length - maxGuesses)
          .clamp(0, maxExtraRows);
      if (_storage.isDailyDone()) {
        _gameOver = true;
        // Read the stored outcome rather than inferring it from the guesses —
        // inference reports a loss whenever the board isn't available.
        _won = _storage.isDailyWon();
      } else if (saved.length >= maxRows &&
          !saved.contains(_answer)) {
        // The app closed while "Keep going?" was open: reopen the offer
        // rather than leaving a full, unrecorded board.
        _awaitingContinue = true;
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

  /// Records the loss for an earlier day's board that was abandoned at the
  /// "Keep going?" offer, so it still reaches games played / win %.
  Future<void> _recordAbandoned(DateTime day) async {
    _settlingAbandoned = true; // a quick second startGame must not re-record
    try {
      _stats = await _storage.recordDailyResult(won: false, now: day);
      await _storage.closeAbandonedBoard(day);
    } finally {
      _settlingAbandoned = false;
    }
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
    _extraRows = 0;
    _awaitingContinue = false;
    // A retry is a different word, so previously revealed positions no longer
    // apply. (The stored copy is scoped to the old attempt and simply won't
    // load again.)
    _revealed.clear();
    _answer = _journeyWord();
    notifyListeners();
  }

  // --- Input ---------------------------------------------------------------

  void onKey(String key) {
    if (!acceptingInput) return;
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

    final keyStatusBefore = Map<String, LetterStatus>.of(_keyStatus);
    final guess = _current;
    _applyToKeyboard(_current);
    _guesses.add(_current);
    final solved = _current == _answer;
    _current = '';

    if (solved) {
      _won = true;
      _gameOver = true;
      _message = _winMessage(_guesses.length);
    } else if (_guesses.length >= maxRows) {
      if (canContinue) {
        // Hold the result: offer "Keep going?" first. Nothing is recorded
        // until the player buys a row or gives up.
        _awaitingContinue = true;
        if (_mode == GameMode.daily) {
          await _storage.saveDailyProgress(guesses: _guesses, done: false);
        }
        _analytics.logEvent(AnalyticsEvents.continueOffered,
            {AnalyticsParams.mode: _mode.name});
        notifyListeners();
        return;
      }
      _gameOver = true;
      _message = _lossMessage;
    }

    if (!_gameOver) {
      _maybeTipAfterGuess(guess, keyStatusBefore);
    } else {
      await _storage.incrementGamesFinished();
    }
    await _settle();
    notifyListeners();
  }

  // --- One-time tips -------------------------------------------------------

  Set<Tip> get _tipsSeen => {
        for (final id in _storage.tipsSeen)
          if (TipRules.fromId(id) case final t?) t,
      };

  void _maybeTipAfterGuess(String guess, Map<String, LetterStatus> before) {
    final pick = TipRules.afterGuess(
      guess: guess,
      statuses: GameEngine.evaluateGuess(guess, _answer),
      keyStatusBefore: before,
      seen: _tipsSeen,
      gamesFinished: _storage.gamesFinished,
    );
    if (pick == null) return;
    _showTip(pick.$1, pick.$2);
  }

  void _showTip(Tip tip, [String? letter]) {
    _message = TipRules.text(tip, letter);
    unawaited(_storage.markTipSeen(TipRules.id(tip)));
    _analytics.logEvent(
        AnalyticsEvents.tipShown, {AnalyticsParams.tip: TipRules.id(tip)});
  }

  /// Whether the idle "try STARE" tip could show right now (empty board, a
  /// new player's first games, not seen yet). The screen runs the timer.
  bool get idleTipEligible =>
      acceptingInput &&
      _guesses.isEmpty &&
      _current.isEmpty &&
      TipRules.idleEligible(
          seen: _tipsSeen, gamesFinished: _storage.gamesFinished);

  /// Shows the idle tip if it is still relevant (called by the screen's timer).
  void showIdleTip() {
    if (!idleTipEligible) return;
    _showTip(Tip.idleStart);
    notifyListeners();
  }

  String get _lossMessage => 'Out of guesses — the word was $_answer';

  /// Persists and rewards the state after a guess (and, at game end, records
  /// the result). Shared by a normal guess and by declining "Keep going?".
  Future<void> _settle() async {
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
        // Fire completion analytics at most once per entry (defensive: the
        // recording itself is idempotent per date).
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
        if (_won && alreadyRecorded) {
          // Defensive: today's result was already final, so neither the
          // streak nor the coins move.
          _message = '${_winMessage(_guesses.length)}  '
              "Today's result was already recorded.";
        } else if (_won) {
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
          if (_stats.currentStreak >= 2) {
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
      // The interstitial is NOT shown here — that would cover the win moment.
      // It is consulted when the player taps "Next level" ([nextJourneyLevel]).
    }
  }

  // --- First Steps ---------------------------------------------------------

  /// Whether this player is still in the First Steps warm-up.
  bool get inFirstSteps => _storage.firstStepsActive;

  /// The warm-up number (1–[firstStepsLevels]) while a new player is on those
  /// Journey levels, else null.
  int? get warmUpStep => inFirstSteps &&
          _mode == GameMode.journey &&
          _journeyLevel <= firstStepsLevels
      ? _journeyLevel
      : null;

  /// True right after the last warm-up level is solved — time to point the
  /// player at today's Daily.
  bool get firstStepsJustCompleted =>
      inFirstSteps &&
      _mode == GameMode.journey &&
      _gameOver &&
      _won &&
      _journeyLevel > firstStepsLevels;

  /// Ends First Steps (idempotent). [reason] is an [AnalyticsFirstStepsEnd].
  Future<void> endFirstSteps(String reason) async {
    if (!inFirstSteps) return;
    await _storage.setFirstStepsActive(false);
    _analytics.logEvent(AnalyticsEvents.firstStepsCompleted,
        {AnalyticsParams.reason: reason});
    notifyListeners();
  }

  /// Moves on from a solved Journey level. This tap — not the win itself — is
  /// where a (frequency-capped) interstitial may show, and never during a new
  /// player's first [journeyAdGraceLevels] levels.
  void nextJourneyLevel() {
    if (_mode != GameMode.journey) return;
    final completedLevel = _journeyLevel - 1; // advanced when it was solved
    if (_won && completedLevel >= journeyAdGraceLevels) {
      _ads.maybeShowJourneyInterstitial();
    }
    startGame(GameMode.journey);
  }

  // --- Keep going? ---------------------------------------------------------

  /// Buys one extra row with coins. Nudges toward the ad option when broke.
  Future<void> continueWithCoins() async {
    if (!_awaitingContinue || !canContinue) return;
    // The puzzle may change while we await (e.g. a midnight rollover on
    // resume); if it did, the spend is refunded and no row is granted.
    final puzzle = _answer;
    if (!await _coins.trySpend(CoinRules.extraGuessCost)) {
      _flash('Need ${CoinRules.extraGuessCost} coins — or watch a short ad');
      return;
    }
    if (!_awaitingContinue || _answer != puzzle) {
      await _coins.award(CoinRules.extraGuessCost); // refund
      return;
    }
    _analytics.logEvent(AnalyticsEvents.coinsSpent, {
      AnalyticsParams.amount: CoinRules.extraGuessCost,
      AnalyticsParams.sink: AnalyticsSinks.extraGuess,
    });
    _grantExtraRow(AnalyticsContinueVia.coins);
  }

  /// Earns one extra row by watching a rewarded ad (only on a real view).
  Future<void> continueWithAd() async {
    if (!_awaitingContinue || !canContinue) return;
    final puzzle = _answer;
    if (!await _ads.showRewarded()) {
      _flash('No ad available — try again in a moment');
      return;
    }
    // The ad may have been open across a midnight rollover.
    if (!_awaitingContinue || _answer != puzzle) return;
    _grantExtraRow(AnalyticsContinueVia.rewardedAd);
  }

  void _grantExtraRow(String via) {
    _extraRows += 1;
    _awaitingContinue = false;
    if (_mode == GameMode.daily) {
      unawaited(_storage.saveDailyExtraRows(_extraRows));
    }
    _analytics.logEvent(AnalyticsEvents.continueAccepted, {
      AnalyticsParams.mode: _mode.name,
      AnalyticsParams.via: via,
    });
    _flash('Extra guess granted');
  }

  /// Gives up at the "Keep going?" offer: the loss is final and recorded.
  Future<void> declineContinue() async {
    if (!_awaitingContinue) return;
    _awaitingContinue = false;
    _gameOver = true;
    await _storage.incrementGamesFinished();
    _message = _lossMessage;
    _analytics.logEvent(AnalyticsEvents.continueDeclined,
        {AnalyticsParams.mode: _mode.name});
    await _settle();
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
  bool get canUseHint => acceptingInput && _nextHintPosition != null;

  /// Reveals one not-yet-known position. Costs coins; if the player can't
  /// afford it, they're nudged to the watch-to-earn action.
  Future<void> useHint() async {
    if (!acceptingInput) return;
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
      dayNumber: _mode == GameMode.daily ? _dailyNumber : null,
      guesses: _guesses,
      answer: _answer,
      won: _won,
      maxGuesses: maxGuesses,
      streak: _mode == GameMode.daily ? _stats.currentStreak : null,
      link: Branding.playStoreUrl,
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
