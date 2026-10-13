import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/branding.dart';
import 'package:daily_word_game/data/word_repository.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a won Daily shares the streak and the store link', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    // Yesterday's win, so today's makes a 2-day streak.
    await storage.recordDailyResult(
        won: true,
        guessesUsed: 3,
        now: DateTime.now().subtract(const Duration(days: 1)));

    final c = GameController(
      words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
      storage: storage,
      coins: CoinService(storage),
      ads: _FakeAds(),
    )..startGame(GameMode.daily);
    for (final ch in c.answer.split('')) {
      c.onKey(ch);
    }
    c.onKey('ENTER');
    await Future<void>.delayed(Duration.zero);

    final text = c.shareText!;
    expect(text.split('\n').first,
        '${Branding.appName} #${c.dailyNumber} 1/6 🔥2');
    expect(text.split('\n').last, 'Play: ${Branding.playStoreUrl}');
  });

  test('Journey shares carry the link but no streak', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final c = GameController(
      words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
      storage: storage,
      coins: CoinService(storage),
      ads: _FakeAds(),
    )..startGame(GameMode.journey);
    for (final ch in c.answer.split('')) {
      c.onKey(ch);
    }
    c.onKey('ENTER');
    await Future<void>.delayed(Duration.zero);

    final text = c.shareText!;
    expect(text.split('\n').first, '${Branding.appName} Journey 1/6');
    expect(text.split('\n').last, 'Play: ${Branding.playStoreUrl}');
  });
}
