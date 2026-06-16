import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// Loads word lists and selects words. Answers (the curated, fair list of
/// possible solutions) are kept separate from allowed guesses (a large
/// dictionary the player may type). Allowed should be a superset of answers.
class WordRepository {
  static const int wordLength = 5;

  /// Daily word epoch — day 0. Keep this fixed so the daily index is stable.
  static final DateTime _epoch = DateTime.utc(2025, 1, 1);

  List<String> _answers = const [];
  Set<String> _allowed = const {};
  final Random _rng = Random();

  /// Small built-in fallback so the app runs before real assets are added.
  static const List<String> _fallbackAnswers = [
    'APPLE', 'BRAVE', 'CRANE', 'DRIFT', 'EAGER', 'FLAME', 'GRAPE', 'HOUSE',
    'IVORY', 'JOLLY', 'KNEEL', 'LEMON', 'MANGO', 'NOBLE', 'OCEAN', 'PIANO',
    'QUILT', 'RIVER', 'STONE', 'TIGER', 'ULTRA', 'VIVID', 'WHALE', 'YACHT',
    'ZEBRA', 'CHARM', 'BLOOM', 'SPARK', 'GLIDE', 'PLUMP',
  ];

  /// Loads lists from assets; falls back to the built-in list on failure.
  Future<void> load() async {
    try {
      final answersRaw = await rootBundle.loadString('assets/words/answers.txt');
      final allowedRaw = await rootBundle.loadString('assets/words/allowed.txt');
      _answers = _parse(answersRaw);
      _allowed = _parse(allowedRaw).toSet()..addAll(_answers);
      if (_answers.isEmpty) _useFallback();
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    _answers = _fallbackAnswers;
    _allowed = _fallbackAnswers.toSet();
  }

  List<String> _parse(String raw) => raw
      .split('\n')
      .map((l) => l.trim().toUpperCase())
      .where((l) => l.length == wordLength && _isAlpha(l))
      .toList();

  bool _isAlpha(String s) => RegExp(r'^[A-Z]+$').hasMatch(s);

  /// The deterministic answer for [date] (UTC day index into the answers list).
  /// Everyone gets the same daily word.
  String dailyWord([DateTime? date]) {
    final d = (date ?? DateTime.now()).toUtc();
    final dayIndex = DateTime.utc(d.year, d.month, d.day).difference(_epoch).inDays;
    final i = dayIndex % _answers.length;
    return _answers[i < 0 ? i + _answers.length : i];
  }

  /// A random answer, for Practice mode.
  String randomWord() => _answers[_rng.nextInt(_answers.length)];

  /// Whether [word] is an acceptable guess.
  bool isAllowed(String word) => _allowed.contains(word.toUpperCase());

  bool get isLoaded => _answers.isNotEmpty;
}
