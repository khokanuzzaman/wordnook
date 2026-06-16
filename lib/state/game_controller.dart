import 'package:flutter/foundation.dart';

import '../data/word_repository.dart';
import '../logic/game_engine.dart';
import '../models/game_result.dart';
import '../models/letter_status.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';

enum GameMode { daily, practice }

/// Holds all game state. UI listens via ListenableBuilder. No widgets here.
class GameController extends ChangeNotifier {
  GameController({
    required WordRepository words,
    required StorageService storage,
    AdsService? ads,
  })  : _words = words,
        _storage = storage,
        _ads = ads ?? AdsService.instance;

  final WordRepository _words;
  final StorageService _storage;
  final AdsService _ads;

  static const int maxGuesses = 6;
  int get wordLength => WordRepository.wordLength;

  GameMode _mode = GameMode.daily;
  GameMode get mode => _mode;

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
      _answer = _words.randomWord();
    }
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

    _applyToKeyboard(_current);
    _guesses.add(_current);
    final solved = _current == _answer;
    _current = '';

    if (solved) {
      _won = true;
      _gameOver = true;
    } else if (_guesses.length >= maxGuesses) {
      _gameOver = true;
    }

    if (_mode == GameMode.daily) {
      await _storage.saveDailyProgress(guesses: _guesses, done: _gameOver);
      if (_gameOver) {
        _stats = await _storage.recordDailyResult(
          won: _won,
          guessesUsed: _won ? _guesses.length : null,
        );
      }
    } else if (_gameOver) {
      _ads.maybeShowPracticeInterstitial();
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

  void _flash(String msg) {
    _message = msg;
    notifyListeners();
  }

  void clearMessage() => _message = null;
}
