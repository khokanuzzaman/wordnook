import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/logic/coin_rules.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoinRules earn math', () {
    test('daily win = base + speed bonus + milestone bonus', () {
      // Solved in 1/6 on a milestone streak: full speed bonus + milestone.
      expect(
        CoinRules.dailyWinReward(guessesUsed: 1, maxGuesses: 6, streak: 5),
        CoinRules.dailyWinBase +
            5 * CoinRules.speedBonusPerGuessSaved +
            CoinRules.streakMilestoneBonus,
      );
      // Solved on the last guess, non-milestone streak: just the base.
      expect(
        CoinRules.dailyWinReward(guessesUsed: 6, maxGuesses: 6, streak: 3),
        CoinRules.dailyWinBase,
      );
    });

    test('journey level = base + speed bonus', () {
      expect(
        CoinRules.journeyLevelReward(guessesUsed: 4, maxGuesses: 6),
        CoinRules.journeyLevelBase + 2 * CoinRules.speedBonusPerGuessSaved,
      );
    });

    test('milestone detection', () {
      expect(CoinRules.isStreakMilestone(5), isTrue);
      expect(CoinRules.isStreakMilestone(100), isTrue);
      expect(CoinRules.isStreakMilestone(200), isTrue);
      expect(CoinRules.isStreakMilestone(3), isFalse);
      expect(CoinRules.isStreakMilestone(0), isFalse);
    });
  });

  group('CoinService earn/spend', () {
    late StorageService storage;
    late CoinService coins;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      coins = CoinService(storage);
    });

    test('award adds and persists', () async {
      expect(coins.coins, 0);
      await coins.award(30);
      expect(coins.coins, 30);
      expect(storage.coins, 30, reason: 'persisted to storage');
    });

    test('trySpend deducts when affordable', () async {
      await coins.award(50);
      expect(await coins.trySpend(15), isTrue);
      expect(coins.coins, 35);
    });

    test('trySpend refuses when short and changes nothing', () async {
      await coins.award(10);
      expect(await coins.trySpend(15), isFalse);
      expect(coins.coins, 10);
    });
  });
}
