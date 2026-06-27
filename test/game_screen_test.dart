import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/screens/game_screen.dart';
import 'package:daily_word_game/screens/widgets/banner_ad_slot.dart';
import 'package:daily_word_game/screens/widgets/celebration_overlay.dart';
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

  tearDown(() => BannerAdSlot.debugDisabled = false);

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
    BannerAdSlot.debugDisabled = true;

    final words = WordRepository()
      ..debugLoad(['CRANE', 'SLATE', 'BRINE', 'PLUMP', 'GHOST']);
    final answer = words.dailyWord();
    // Mark today's daily as already completed (won).
    await storage.saveDailyProgress(guesses: [answer], done: true);

    final controller = GameController(
        words: words,
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds());

    await tester
        .pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    // Let the post-frame callback + the 700ms reveal delay elapse, then settle
    // the bottom-sheet animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Guess distribution'), findsOneWidget);
  });

  testWidgets('winning the daily shows the celebration overlay',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setOnboardingSeen();
    BannerAdSlot.debugDisabled = true;

    final words = WordRepository()
      ..debugLoad(['CRANE', 'SLATE', 'BRINE', 'PLUMP', 'GHOST']);
    final controller = GameController(
        words: words,
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds());

    await tester
        .pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    await tester.pump();

    // Solve today's word in one guess.
    for (final ch in controller.answer.split('')) {
      controller.onKey(ch);
    }
    controller.onKey('ENTER');
    await tester.pump(); // flush async submit + notifyListeners
    await tester.pump(const Duration(milliseconds: 16)); // post-frame handler
    await tester.pump(const Duration(milliseconds: 16)); // rebuild with overlay

    expect(controller.won, isTrue);
    expect(find.byType(CelebrationOverlay), findsOneWidget);

    // Drain the confetti + stats-sheet timers so the test ends cleanly.
    await tester.pumpAndSettle();
  });
}
