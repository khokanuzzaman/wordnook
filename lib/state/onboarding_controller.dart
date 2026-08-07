import 'package:flutter/foundation.dart';

import '../logic/game_engine.dart';
import '../models/letter_status.dart';

/// Which moment of the tutorial the player is in.
enum OnboardingStep { invite, reveal, solve, win }

/// One row of the "Your row, decoded" legend: a real letter from the player's
/// first guess and the colour it earned.
@immutable
class LegendChip {
  final String letter;
  final LetterStatus status;
  const LegendChip(this.letter, this.status);
}

/// Fully self-contained state for the first-run tutorial.
///
/// CRITICAL: this touches NO real game state. It holds the board in memory,
/// scores with the pure [GameEngine], and never references StorageService,
/// CoinService, WordRepository, or GameController. Nothing typed here can reach
/// daily/journey/streak/coin storage. The only persistence happens later, in
/// the onboarding screen, when the tutorial finishes.
class OnboardingController extends ChangeNotifier {
  /// The tutorial answer — fixed, never drawn from answers.txt.
  static const String answer = 'BREAD';

  /// The word we suggest as a first guess (any valid word also works).
  static const String suggestedGuess = 'CRANE';

  static const int wordLength = 5;
  static const int maxRows = 6;

  final List<String> _guesses = [];
  String _current = '';
  final Map<String, LetterStatus> _keyStatus = {};

  // Stall tracking: the set of positions already locked green, and how many
  // consecutive guesses have added no new green.
  final Set<int> _greenPositions = {};
  int _stalledStreak = 0;
  bool _stallDismissed = false;

  List<String> get guesses => List.unmodifiable(_guesses);
  String get current => _current;
  Map<String, LetterStatus> get keyStatus => Map.unmodifiable(_keyStatus);
  bool get solved => _guesses.isNotEmpty && _guesses.last == answer;

  OnboardingStep get step {
    if (solved) return OnboardingStep.win;
    if (_guesses.isEmpty) return OnboardingStep.invite;
    if (_guesses.length == 1) return OnboardingStep.reveal;
    return OnboardingStep.solve;
  }

  List<LetterStatus> statusesFor(String guess) =>
      GameEngine.evaluateGuess(guess, answer);

  // --- Input ---------------------------------------------------------------

  void onKey(String key) {
    if (solved) return;
    if (key == 'ENTER') {
      _submit();
    } else if (key == 'DEL') {
      if (_current.isNotEmpty) {
        _current = _current.substring(0, _current.length - 1);
        notifyListeners();
      }
    } else if (_current.length < wordLength &&
        RegExp(r'^[A-Za-z]$').hasMatch(key)) {
      _current += key.toUpperCase();
      notifyListeners();
    }
  }

  void _submit() {
    // Any 5-letter word is accepted — the tutorial is a teaching space, not a
    // dictionary check, and it stays fully isolated from the real word lists.
    if (_current.length != wordLength) return;

    final guess = _current;
    final statuses = statusesFor(guess);
    _applyToKeyboard(guess, statuses);
    _guesses.add(guess);
    _current = '';

    // Stall detection: did this guess lock in any NEW green?
    final newGreens = <int>[];
    for (var i = 0; i < statuses.length; i++) {
      if (statuses[i] == LetterStatus.correct && _greenPositions.add(i)) {
        newGreens.add(i);
      }
    }
    if (solved) {
      _stalledStreak = 0;
    } else if (newGreens.isEmpty) {
      _stalledStreak++;
    } else {
      _stalledStreak = 0;
      _stallDismissed = false; // progress re-arms the nudge
    }

    notifyListeners();
  }

  void _applyToKeyboard(String guess, List<LetterStatus> statuses) {
    for (var i = 0; i < guess.length; i++) {
      final c = guess[i];
      final prev = _keyStatus[c];
      if (prev == null || statuses[i].rank > prev.rank) {
        _keyStatus[c] = statuses[i];
      }
    }
  }

  // --- Reveal legend -------------------------------------------------------

  /// The chips for the reveal legend, built from the player's ACTUAL first
  /// guess: a green, an amber, and a grey example — each an honest letter from
  /// their row. Only concepts that actually occurred are included.
  List<LegendChip> revealLegend() {
    if (_guesses.isEmpty) return const [];
    final g = _guesses.first;
    final st = statusesFor(g);

    String? pick(LetterStatus want, {bool avoidDuplicateColour = false}) {
      for (var i = 0; i < g.length; i++) {
        if (st[i] != want) continue;
        if (avoidDuplicateColour) {
          // Skip a letter that ALSO shows up green/amber elsewhere in the row,
          // so the "not in the word" example is never a letter the board is
          // simultaneously colouring in — the classic onboarding confusion.
          final letter = g[i];
          final coloredElsewhere = [
            for (var j = 0; j < g.length; j++)
              if (g[j] == letter && st[j] != LetterStatus.absent) j
          ].isNotEmpty;
          if (coloredElsewhere) continue;
        }
        return g[i];
      }
      return null;
    }

    final chips = <LegendChip>[];
    final green = pick(LetterStatus.correct);
    if (green != null) chips.add(LegendChip(green, LetterStatus.correct));
    final amber = pick(LetterStatus.present);
    if (amber != null) chips.add(LegendChip(amber, LetterStatus.present));
    final grey = pick(LetterStatus.absent, avoidDuplicateColour: true) ??
        pick(LetterStatus.absent);
    if (grey != null) chips.add(LegendChip(grey, LetterStatus.absent));
    return chips;
  }

  // --- Stall nudge ---------------------------------------------------------

  /// Whether to show the cozy stall nudge now: the player has stalled (2+
  /// guesses with no new green), hasn't solved, and hasn't dismissed it since
  /// their last bit of progress.
  bool get showStallNudge =>
      !solved && _stalledStreak >= 2 && !_stallDismissed;

  void dismissStallNudge() {
    _stallDismissed = true;
    notifyListeners();
  }

  /// Copy for the nudge. Escalates gently so a solve is always within reach —
  /// on the final row it names the word outright, guaranteeing the win for
  /// anyone still trying (Skip remains available regardless).
  String stallHint() {
    final lockedLetter =
        _greenPositions.isEmpty ? null : answer[_greenPositions.reduce(min)];
    if (_guesses.length >= maxRows - 1) {
      return 'One to go — the word is $answer. Give it a try.';
    }
    if (_guesses.length >= 3) {
      // Reveal one more true position in copy only (no tile recolour).
      final next = _firstUnsolvedPosition();
      if (next != null) {
        return 'No rush. The ${_ordinal(next + 1)} letter is '
            '"${answer[next]}" — weave it in.';
      }
    }
    if (lockedLetter != null) {
      return "No rush. You've locked $lockedLetter in place — "
          'try a cozy word that keeps it up front.';
    }
    return 'No rush. Try a common word and watch what lights up.';
  }

  int? _firstUnsolvedPosition() {
    for (var i = 0; i < wordLength; i++) {
      if (!_greenPositions.contains(i)) return i;
    }
    return null;
  }

  static int min(int a, int b) => a < b ? a : b;

  static String _ordinal(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }
}
