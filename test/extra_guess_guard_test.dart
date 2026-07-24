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

String _todayKey() {
  final d = DateTime.now().toUtc();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an extra guess on an empty finished board deducts 0 coins', () async {
    // A finished daily whose board carries no guesses (what a migrated
    // pre-remap install looks like).
    SharedPreferences.setMockInitialValues({
      'flutter.daily_date': _todayKey(),
      'flutter.daily_done': true,
      'flutter.daily_won': false,
      'flutter.coins': 500,
    });

    final storage = StorageService();
    await storage.init();
    final coins = CoinService(storage);
    final c = GameController(
      words: WordRepository()..debugLoad(_words),
      storage: storage,
      coins: coins,
      ads: _FakeAds(),
    );
    c.startGame(GameMode.daily);

    expect(c.gameOver, isTrue);
    expect(c.won, isFalse);
    expect(c.guesses, isEmpty);

    final before = coins.coins;
    await c.useExtraGuess();

    expect(coins.coins, before, reason: 'nothing to extend — charge nothing');
    expect(c.gameOver, isTrue, reason: 'the board must stay closed');
  });

  test('an extra guess still works on a board that has guesses', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final coins = CoinService(storage);
    final c = GameController(
      words: WordRepository()..debugLoad(_words),
      storage: storage,
      coins: coins,
      ads: _FakeAds(),
    );
    c.startGame(GameMode.daily);

    // Lose properly, so there ARE guesses to extend.
    final wrong = _words.firstWhere((w) => w != c.answer);
    for (var i = 0; i < GameController.maxGuesses; i++) {
      for (final ch in wrong.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.gameOver, isTrue);
    expect(c.guesses, isNotEmpty);

    await coins.award(CoinRules.extraGuessCost);
    await c.useExtraGuess();

    expect(c.gameOver, isFalse, reason: 'the guard must not block the real case');
    expect(coins.coins, 0);
  });
}
