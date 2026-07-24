import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/coin_rules.dart';
import 'package:daily_word_game/logic/game_engine.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

const _words = ['CRANE', 'SLATE', 'BRINE'];

Future<(StorageService, CoinService)> _storage() async {
  final storage = StorageService();
  await storage.init();
  return (storage, CoinService(storage));
}

GameController _controller(StorageService storage, CoinService coins) =>
    GameController(
      words: WordRepository()..debugLoad(_words),
      storage: storage,
      coins: coins,
      ads: _FakeAds(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a purchased hint persists across a controller rebuild + storage reload',
      () async {
    var (storage, coins) = await _storage();
    var c = _controller(storage, coins);
    c.startGame(GameMode.daily);
    await coins.award(CoinRules.hintCost);
    await c.useHint();

    expect(c.revealedHints, isNotEmpty, reason: 'hint should be recorded');
    final revealed = Map<int, String>.from(c.revealedHints);
    // The revealed letter really is the answer's letter at that position.
    revealed.forEach((i, letter) => expect(c.answer[i], letter));

    // Simulate a full relaunch: brand new storage + controller over the same
    // persisted prefs.
    (storage, coins) = await _storage();
    c = _controller(storage, coins);
    c.startGame(GameMode.daily);
    expect(c.revealedHints, revealed,
        reason: 'the bought hint must survive a restart');
  });

  test('reveals clear on a new daily date', () async {
    final (storage, coins) = await _storage();
    final c = _controller(storage, coins);
    c.startGame(GameMode.daily);
    await coins.award(CoinRules.hintCost);
    await c.useHint();
    expect(c.revealedHints, isNotEmpty);

    // Re-save the reveals under yesterday's scope, then restart: today's scope
    // no longer matches, so nothing should load.
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await storage.saveHints('d:${storage.todayKey(yesterday)}', {0: 'Z'});

    final fresh = _controller(storage, coins);
    fresh.startGame(GameMode.daily);
    expect(fresh.revealedHints, isEmpty,
        reason: 'yesterday\'s reveals must not leak into today');
  });

  test('reveals clear on a new journey level and on a retry', () async {
    final (storage, coins) = await _storage();
    final c = _controller(storage, coins);
    c.startGame(GameMode.journey);
    await coins.award(CoinRules.hintCost);
    await c.useHint();
    expect(c.revealedHints, isNotEmpty);

    // A retry swaps in a different word for the same level.
    c.retryJourneyLevel();
    expect(c.revealedHints, isEmpty, reason: 'retry uses a different word');

    // Advancing the level must not carry reveals over either.
    await storage.setJourneyLevel(storage.journeyLevel + 1);
    final next = _controller(storage, coins);
    next.startGame(GameMode.journey);
    expect(next.revealedHints, isEmpty);
  });

  group('hard mode honours revealed hints', () {
    test('engine rejects a guess that omits a revealed letter', () {
      // Answer CRANE, position 0 revealed as 'C'.
      const revealed = {0: 'C'};
      expect(
        GameEngine.hardModeViolation('SLATE', const [], 'CRANE',
            revealed: revealed),
        isNotNull,
        reason: 'guess ignores the revealed 1st letter',
      );
      expect(
        GameEngine.hardModeViolation('CRANE', const [], 'CRANE',
            revealed: revealed),
        isNull,
        reason: 'guess honours the revealed 1st letter',
      );
    });

    test('no reveals means unchanged behaviour', () {
      expect(GameEngine.hardModeViolation('SLATE', const [], 'CRANE'), isNull);
    });

    test('controller blocks the submit when hard mode is on', () async {
      final (storage, coins) = await _storage();
      await storage.setHardMode(true);
      final c = _controller(storage, coins);
      c.startGame(GameMode.daily);
      await coins.award(CoinRules.hintCost);
      await c.useHint();

      final pos = c.revealedHints.keys.first;
      final letter = c.revealedHints[pos]!;
      // Pick an allowed word that does NOT honour the revealed position.
      final bad = _words.firstWhere((w) => w[pos] != letter);
      for (final ch in bad.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);

      expect(c.guesses, isEmpty, reason: 'hard mode should reject the guess');
      expect(c.message, contains('Hard mode'));
    });
  });
}
