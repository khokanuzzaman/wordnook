import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../logic/deterministic_shuffle.dart';
import '../logic/journey_ramp.dart';
import '../models/word_pack.dart';

/// Loads word lists and selects words. Answers (the curated, fair list of
/// possible solutions) are kept separate from allowed guesses (a large
/// dictionary the player may type). Allowed should be a superset of answers.
class WordRepository {
  static const int wordLength = 5;

  /// Daily word epoch — day 0. Keep this fixed so the daily index is stable.
  static final DateTime _epoch = DateTime.utc(2025, 1, 1);

  /// Fixed seed for the Journey play-order shuffle so a given level always maps
  /// to the same word across devices and launches.
  static const int _journeySeed = 0x5EED;

  /// Fixed seed for the DAILY play-order shuffle. Deliberately different from
  /// [_journeySeed] so daily and journey don't walk the same order.
  ///
  /// The answers file is sorted alphabetically, so indexing it directly by day
  /// made consecutive days consecutive words (HEAVY → HEDGE → HEFTY …), letting
  /// anyone who played yesterday guess today's first letters. Daily now draws
  /// from a fixed permutation instead.
  static const int _dailySeed = 0xD4117A11;

  List<String> _answers = const [];
  Set<String> _allowed = const {};
  List<WordPack> _packs = const [];

  /// Difficulty tiers for Journey (subsets of [_answers]); see
  /// assets/words/README.md. Empty until loaded — then every tier falls back
  /// to the full answer list.
  Map<WordTier, List<String>> _tierWords = const {};

  /// Each tier's fixed Journey play order (seeded shuffle of that tier).
  Map<WordTier, List<String>> _tierOrder = const {};

  static const Map<WordTier, String> _tierAssets = {
    WordTier.easy: 'assets/words/answers_easy.txt',
    WordTier.medium: 'assets/words/answers_medium.txt',
    WordTier.hard: 'assets/words/answers_hard.txt',
  };

  static const Map<WordTier, int> _tierSeeds = {
    WordTier.easy: 0x7E1E,
    WordTier.medium: 0x7E2E,
    WordTier.hard: 0x7E3E,
  };

  /// Deterministic permutation of [_answers] that the daily walks in order.
  List<String> _dailyOrder = const [];

  /// Small built-in fallback so the app runs before real assets are added.
  static const List<String> _fallbackAnswers = [
    'APPLE',
    'BRAVE',
    'CRANE',
    'DRIFT',
    'EAGER',
    'FLAME',
    'GRAPE',
    'HOUSE',
    'IVORY',
    'JOLLY',
    'KNEEL',
    'LEMON',
    'MANGO',
    'NOBLE',
    'OCEAN',
    'PIANO',
    'QUILT',
    'RIVER',
    'STONE',
    'TIGER',
    'ULTRA',
    'VIVID',
    'WHALE',
    'YACHT',
    'ZEBRA',
    'CHARM',
    'BLOOM',
    'SPARK',
    'GLIDE',
    'PLUMP',
  ];

  /// Loads lists from assets; falls back to the built-in list on failure.
  Future<void> load() async {
    try {
      final answersRaw =
          await rootBundle.loadString('assets/words/answers.txt');
      final allowedRaw =
          await rootBundle.loadString('assets/words/allowed.txt');
      _answers = _parse(answersRaw);
      _allowed = _parse(allowedRaw).toSet()..addAll(_answers);
      if (_answers.isEmpty) _useFallback();
    } catch (_) {
      _useFallback();
    }
    final tiers = <WordTier, List<String>>{};
    for (final e in _tierAssets.entries) {
      try {
        tiers[e.key] = _parse(await rootBundle.loadString(e.value));
      } catch (_) {
        // Missing tier file: that tier falls back to the full answer list.
      }
    }
    _tierWords = tiers;
    _rebuildOrders();
  }

  void _useFallback() {
    _answers = _fallbackAnswers;
    _allowed = _fallbackAnswers.toSet();
  }

  /// Test seam: load word lists directly, bypassing asset I/O.
  @visibleForTesting
  void debugLoad(
    List<String> answers, {
    Set<String>? allowed,
    Map<WordTier, List<String>>? tiers,
  }) {
    _answers = answers.map((w) => w.toUpperCase()).toList();
    _allowed = (allowed?.map((w) => w.toUpperCase()).toSet() ?? <String>{})
      ..addAll(_answers);
    _tierWords = {
      for (final e in (tiers ?? const <WordTier, List<String>>{}).entries)
        e.key: e.value.map((w) => w.toUpperCase()).toList(),
    };
    _rebuildOrders();
  }

  /// Rebuilds both deterministic play orders from [_answers].
  ///
  /// Daily and Journey each walk their own fixed permutation (different seeds),
  /// produced by our own PRNG so the mapping can't drift with an SDK update.
  void _rebuildOrders() {
    _dailyOrder = DeterministicShuffle.shuffled(_answers, _dailySeed);
    _buildPacks();
    _buildTierOrders();
  }

  /// Each tier's Journey play order. A tier word that isn't an answer is
  /// dropped; an empty or missing tier falls back to all answers, so Journey
  /// always has words even before tier files exist.
  void _buildTierOrders() {
    final answerSet = _answers.toSet();
    _tierOrder = {
      for (final t in WordTier.values)
        t: DeterministicShuffle.shuffled(
          () {
            final words = (_tierWords[t] ?? const <String>[])
                .where(answerSet.contains)
                .toList();
            return words.isEmpty ? _answers : words;
          }(),
          _tierSeeds[t]!,
        ),
    };
  }

  /// Builds the Journey packs. For now there is a single default "Everyday"
  /// pack whose play order is a deterministic shuffle of the answers, so levels
  /// don't march alphabetically. Additional themed packs can be added here.
  void _buildPacks() {
    _packs = [
      WordPack(
        id: 'everyday',
        name: 'Everyday',
        answers: DeterministicShuffle.shuffled(_answers, _journeySeed),
      ),
    ];
  }

  List<String> _parse(String raw) => raw
      .split('\n')
      .map((l) => l.trim().toUpperCase())
      .where((l) => l.length == wordLength && _isAlpha(l))
      .toList();

  bool _isAlpha(String s) => RegExp(r'^[A-Z]+$').hasMatch(s);

  /// The deterministic answer for [date]. Everyone gets the same daily word.
  ///
  /// Walks [_dailyOrder] (a fixed permutation), NOT the alphabetically sorted
  /// answers list, so consecutive days are unrelated words.
  String dailyWord([DateTime? date]) {
    final dayIndex = _dayIndex(date ?? DateTime.now());
    final i = dayIndex % _dailyOrder.length;
    return _dailyOrder[i < 0 ? i + _dailyOrder.length : i];
  }

  /// The 1-based daily puzzle number for [date] (day 1 = the epoch).
  int dailyNumber([DateTime? date]) => _dayIndex(date ?? DateTime.now()) + 1;

  /// Days since the epoch for [d]'s OWN calendar date — no time-zone
  /// conversion. The app passes `DateTime.now()` (device-local), so the daily
  /// rolls over at the player's local midnight, like other daily word games.
  /// Built from date fields as a UTC date so DST can't skew the day count.
  static int _dayIndex(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).difference(_epoch).inDays;

  // --- Journey packs -------------------------------------------------------

  List<WordPack> get packs => List.unmodifiable(_packs);

  /// The default pack used by Journey until pack selection ships.
  WordPack get defaultPack => _packs.isNotEmpty
      ? _packs.first
      : WordPack(id: 'everyday', name: 'Everyday', answers: _answers);

  /// The Journey answer for a 1-based [level]. The level's difficulty tier
  /// comes from [JourneyRamp]; [attempt] > 0 (a retry after a loss) picks a
  /// different word from the same tier. Same level + attempt = same word on
  /// every device.
  String journeyWord(int level, {int attempt = 0}) {
    final order = _tierOrder[JourneyRamp.tierFor(level)] ?? const <String>[];
    if (order.isEmpty) return defaultPack.wordForLevel(level);
    return order[JourneyRamp.indexFor(level, order.length, attempt: attempt)];
  }

  /// The canonical Journey answer for a 1-based [level].
  String wordForLevel(int level) => journeyWord(level);

  /// Whether [word] is an acceptable guess.
  bool isAllowed(String word) => _allowed.contains(word.toUpperCase());

  bool get isLoaded => _answers.isNotEmpty;
}
