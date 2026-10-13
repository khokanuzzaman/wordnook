import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/coin_rules.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

/// Rewarded ad fake whose [earned] result is configurable, so we can prove the
/// app only grants on a real, earned view.
class _FakeAds implements GameAds {
  _FakeAds(this.earned);
  final bool earned;
  int shown = 0;

  @override
  Future<bool> showRewarded() async {
    shown++;
    return earned;
  }

  @override
  void maybeShowJourneyInterstitial() {}
}

Future<GameController> _controller(CoinService coins, GameAds ads,
    {required StorageService storage}) async {
  final words = WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']);
  return GameController(
      words: words, storage: storage, coins: coins, ads: ads);
}

Future<(StorageService, CoinService)> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return (storage, CoinService(storage));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('watch-to-earn grants coins ONLY on a real, earned view', () async {
    // Earned view → coins awarded.
    var (storage, coins) = await _fresh();
    var c = await _controller(coins, _FakeAds(true), storage: storage);
    await c.watchAdForCoins();
    expect(coins.coins, CoinRules.watchAdReward);

    // No ad / not earned → nothing granted.
    (storage, coins) = await _fresh();
    c = await _controller(coins, _FakeAds(false), storage: storage);
    await c.watchAdForCoins();
    expect(coins.coins, 0, reason: 'no earned view => no coins');
  });

  test('hint spends coins, and is refused (no spend) when broke', () async {
    final (storage, coins) = await _fresh();
    final c = await _controller(coins, _FakeAds(true), storage: storage);
    c.startGame(GameMode.daily);

    // Broke: hint must not reveal or go negative.
    await c.useHint();
    expect(coins.coins, 0);

    // With exactly enough, the hint spends them.
    await coins.award(CoinRules.hintCost);
    await c.useHint();
    expect(coins.coins, 0);
  });

  test('"Keep going?" via ad grants a row ONLY on an earned view', () async {
    for (final earned in [false, true]) {
      final (storage, coins) = await _fresh();
      final ads = _FakeAds(earned);
      final c = await _controller(coins, ads, storage: storage);
      c.startGame(GameMode.daily);

      final wrong =
          ['CRANE', 'SLATE', 'BRINE'].firstWhere((w) => w != c.answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        for (final ch in wrong.split('')) {
          c.onKey(ch);
        }
        c.onKey('ENTER');
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.awaitingContinue, isTrue);

      await c.continueWithAd();
      expect(ads.shown, 1);
      expect(c.acceptingInput, earned,
          reason: earned ? 'earned view => row granted' : 'no view => no row');
      expect(c.awaitingContinue, !earned);
    }
  });
}
