import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/models/word_pack.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

/// Records calls without touching the AdMob plugin.
class FakeAds implements GameAds {
  int rewardedShown = 0;
  int interstitialCalls = 0;

  @override
  Future<void> showRewarded({required void Function() onReward}) async {
    rewardedShown++;
    onReward();
  }

  @override
  void maybeShowJourneyInterstitial() => interstitialCalls++;
}

Future<StorageService> freshStorage() async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordPack', () {
    const pack = WordPack(
        id: 't', name: 'T', answers: ['CRANE', 'SLATE', 'BRINE']);

    test('wordForLevel is 1-based and wraps', () {
      expect(pack.wordForLevel(1), 'CRANE');
      expect(pack.wordForLevel(3), 'BRINE');
      expect(pack.wordForLevel(4), 'CRANE'); // wraps
    });

    test('is deterministic', () {
      expect(pack.wordForLevel(2), pack.wordForLevel(2));
    });
  });

  group('ad cadence + entitlement gating', () {
    test('interstitial is due every 3rd level', () {
      final ads = AdsService.instance..debugResetCadence();
      final results = [for (var i = 0; i < 6; i++) ads.shouldShowJourneyInterstitial()];
      expect(results, [false, false, true, false, false, true]);
    });

    test('Remove Ads suppresses interstitials entirely', () {
      final ads = AdsService.instance..debugResetCadence();
      ads.removeAds = true;
      final results = [for (var i = 0; i < 6; i++) ads.shouldShowJourneyInterstitial()];
      expect(results.every((r) => r == false), isTrue);
    });
  });

  group('social proof', () {
    test('solved% is stable and within 55..95', () {
      for (final level in [1, 2, 7, 42, 1000]) {
        final a = GameController.solvedPercentForLevel(level);
        final b = GameController.solvedPercentForLevel(level);
        expect(a, b, reason: 'must be stable for a given level');
        expect(a, inInclusiveRange(55, 95));
      }
    });
  });

  group('level progression', () {
    test('starts at the stored level and advances on a win', () async {
      final storage = await freshStorage();
      final words = WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE', 'PLUMP']);
      final ads = FakeAds();
      final c = GameController(words: words, storage: storage, ads: ads);

      c.startGame(GameMode.journey);
      expect(c.journeyLevel, 1);

      // Solve the level by typing its answer.
      final answer = c.answer;
      for (final ch in answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);

      expect(c.won, isTrue);
      expect(c.journeyLevel, 2, reason: 'a solved level advances the counter');
      expect(storage.journeyLevel, 2, reason: 'progress is persisted');
      expect(ads.interstitialCalls, 1, reason: 'cadence is consulted on win');
    });

    test('a loss does not advance the level', () async {
      final storage = await freshStorage();
      final words = WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']);
      final c = GameController(words: words, storage: storage, ads: FakeAds());

      c.startGame(GameMode.journey);
      final answer = c.answer;
      // Pick any allowed word that is not the answer to burn all 6 guesses.
      final wrong = ['CRANE', 'SLATE', 'BRINE'].firstWhere((w) => w != answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        for (final ch in wrong.split('')) {
          c.onKey(ch);
        }
        c.onKey('ENTER');
        await Future<void>.delayed(Duration.zero);
      }

      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);
      expect(c.journeyLevel, 1, reason: 'a loss keeps you on the same level');
      expect(storage.journeyLevel, 1);
    });
  });
}
