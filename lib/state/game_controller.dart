import 'package:flutter/foundation.dart';

import '../branding.dart';
import '../data/word_repository.dart';
import '../logic/game_engine.dart';
import '../logic/share_formatter.dart';
import '../models/game_result.dart';
import '../models/letter_status.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';

enum GameMode { daily, journey }

/// Holds all game state. UI listens via ListenableBuilder. No widgets here.
class GameController extends ChangeNotifier {
  GameController({
    required WordRepository words,
    required StorageService storage,
    GameAds? ads,
  })  : _words = words,
        _storage = storage,
        _ads = ads ?? AdsService.instance;

  final WordRepository _words;
  final StorageService _storage;
  final GameAds _ads;

  /// Exposed for the settings screen (reminder prefs, onboarding flag).
  StorageService get storage => _storage;

  static const int maxGuesses = 6;
  int get wordLength => WordRepository.wordLength;

  GameMode _mode = GameMode.daily;
  GameMode get mode => _mode;

  int _journeyLevel = 1;
  int get journeyLevel => _journeyLevel;

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

    if (mode == GameMode.daily) {
      _answer = _words.dailyWord();
      // Restore today's progress if it exists.
      final saved = _storage.loadDailyGuesses();
      for (final g in saved) {
        _applyToKeyboard(g);
      }
      _guesses.addAll(saved);
      if (_storage.isDailyDone()) {
        _gameOver = true;
        _won = saved.isNotEmpty && saved.last == _answer;
      }
    } else {
      _journeyLevel = _storage.journeyLevel;
      _journeyAttempt = 0; // fresh entry to a level starts at its canonical word
      _answer = _journeyWord();
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
    if (_storage.hardMode && _guesses.isNotEmpty) {
      final violation =
          GameEngine.hardModeViolation(_current, _guesses, _answer);
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
        _stats = await _storage.recordDailyResult(
          won: _won,
          guessesUsed: _won ? _guesses.length : null,
        );
        // Celebrate the streak once it's worth bragging about.
        if (_won && _stats.currentStreak >= 2) {
          final milestone = _isStreakMilestone(_stats.currentStreak);
          _message = '${_winMessage(_guesses.length)}  '
              '${milestone ? '🔥🔥' : '🔥'} ${_stats.currentStreak}-day streak'
              '${milestone ? '!' : ''}';
        }
      }
    } else if (_gameOver && _won) {
      // Journey: a solved level counts as completed — advance and (maybe) ad.
      _journeyLevel += 1;
      await _storage.setJourneyLevel(_journeyLevel);
      _ads.maybeShowJourneyInterstitial();
    }

    notifyListeners();
  }

  // --- Rewarded features ---------------------------------------------------

  /// Reveals one not-yet-solved position. Gated behind a rewarded ad.
  void useHint() {
    if (_gameOver) return;
    _ads.showRewarded(onReward: () {
      for (var i = 0; i < wordLength; i++) {
        final solvedHere =
            _guesses.any((g) => g.length > i && g[i] == _answer[i]);
        if (!solvedHere) {
          _flash('Hint: position ${i + 1} is "${_answer[i]}"');
          return;
        }
      }
      _flash("You're very close!");
    });
  }

  /// Grants one extra guess beyond the normal max. Gated behind a rewarded ad.
  void useExtraGuess() {
    if (!_gameOver || _won) return;
    _ads.showRewarded(onReward: () {
      _gameOver = false;
      _flash('Extra guess granted');
      notifyListeners();
    });
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
      _mode == GameMode.daily && _gameOver && _storage.pendingRestoreStreak() > 0;

  /// Restores a broken streak after the user watches a rewarded ad.
  void restoreStreak() {
    if (!canRestoreStreak) return;
    _ads.showRewarded(onReward: () async {
      _stats = await _storage.restoreStreak();
      _flash('Streak restored to ${_stats.currentStreak}!');
      notifyListeners();
    });
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

  /// Milestone streaks get extra fanfare.
  static bool _isStreakMilestone(int streak) =>
      streak == 5 ||
      streak == 10 ||
      streak == 25 ||
      streak == 50 ||
      streak == 100 ||
      (streak > 0 && streak % 100 == 0);

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
