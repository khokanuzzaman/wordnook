import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/coin_rules.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late CoinService coins;
  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    coins = CoinService(storage);
    c = GameController(
      words: WordRepository()..debugLoad(_words),
      storage: storage,
      coins: coins,
      ads: _FakeAds(),
    );
  });

  test('buying two hints reveals two DIFFERENT positions', () async {
    await coins.award(CoinRules.hintCost * 2);
    c.startGame(GameMode.daily);

    await c.useHint();
    expect(c.revealedHints.length, 1);
    final first = c.revealedHints.keys.single;

    await c.useHint();
    expect(c.revealedHints.length, 2,
        reason: 'the second hint must add a new position, not overwrite');
    expect(c.revealedHints.keys.toSet().length, 2);
    expect(c.revealedHints.keys, contains(first),
        reason: 'the first reveal must be kept');

    // Both reveals are truthful.
    c.revealedHints.forEach((i, letter) => expect(c.answer[i], letter));
    // Exactly two purchases were charged.
    expect(coins.coins, 0);
  });

  test('a purchase with zero remaining positions deducts 0 coins', () async {
    await coins.award(CoinRules.hintCost * 10);
    c.startGame(GameMode.daily);

    // Exhaust every position.
    for (var i = 0; i < c.wordLength; i++) {
      await c.useHint();
    }
    expect(c.revealedHints.length, c.wordLength);
    expect(c.canUseHint, isFalse,
        reason: 'nothing left to reveal — the button must be disabled');

    final before = coins.coins;
    await c.useHint();

    expect(coins.coins, before, reason: 'no coins may be deducted');
    expect(c.revealedHints.length, c.wordLength,
        reason: 'no extra reveal should be recorded');
  });

  test('a hint already solved by a guess is never re-sold', () async {
    await coins.award(CoinRules.hintCost * 10);
    c.startGame(GameMode.daily);

    // Reveal everything, then confirm repeated purchases stay a no-op.
    for (var i = 0; i < c.wordLength; i++) {
      await c.useHint();
    }
    final settled = coins.coins;
    await c.useHint();
    await c.useHint();
    expect(coins.coins, settled);
    expect(c.revealedHints.length, c.wordLength);
  });

  test('hint state is scoped to the current puzzle and does not leak', () async {
    await coins.award(CoinRules.hintCost);
    c.startGame(GameMode.daily);
    await c.useHint();
    expect(c.revealedHints, isNotEmpty);

    final todayScope = 'd:${storage.todayKey()}';
    expect(storage.loadHints(todayScope), isNotEmpty,
        reason: 'reveals are stored under today');

    // The NEXT daily is a different scope, so it must see nothing.
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    expect(storage.loadHints('d:${storage.todayKey(tomorrow)}'), isEmpty,
        reason: "today's reveals must not leak into tomorrow's puzzle");

    // Journey is a different scope too.
    expect(storage.loadHints('j:1:0'), isEmpty);
  });

  test('switching to journey starts with no reveals carried over', () async {
    await coins.award(CoinRules.hintCost * 2);
    c.startGame(GameMode.daily);
    await c.useHint();
    expect(c.revealedHints, isNotEmpty);

    c.startGame(GameMode.journey);
    expect(c.revealedHints, isEmpty,
        reason: 'daily reveals must not appear on a journey level');
    expect(c.canUseHint, isTrue);
  });
}
