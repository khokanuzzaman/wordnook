import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/screens/game_screen.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  @override
  Future<void> showRewarded({required void Function() onReward}) async =>
      onReward();
  @override
  void maybeShowJourneyInterstitial() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AdsService.instance.removeAds = false);

  testWidgets('returning player with a finished daily sees the stats sheet',
      (tester) async {
    // Use a phone-sized surface so the board + keyboard fit without overflow.
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setOnboardingSeen();
    // Suppress the banner so the sheet doesn't touch the AdMob plugin in tests.
    AdsService.instance.removeAds = true;

    final words = WordRepository()
      ..debugLoad(['CRANE', 'SLATE', 'BRINE', 'PLUMP', 'GHOST']);
    final answer = words.dailyWord();
    // Mark today's daily as already completed (won).
    await storage.saveDailyProgress(guesses: [answer], done: true);

    final controller =
        GameController(words: words, storage: storage, ads: _FakeAds());

    await tester.pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    // Let the post-frame callback + the 700ms reveal delay elapse, then settle
    // the bottom-sheet animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Guess distribution'), findsOneWidget);
  });
}
