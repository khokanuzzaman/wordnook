import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/screens/game_screen.dart';
import 'package:daily_word_game/screens/onboarding/onboarding_screen.dart';
import 'package:daily_word_game/screens/widgets/banner_ad_slot.dart';
import 'package:daily_word_game/screens/widgets/board_grid.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

/// QA found the tutorial keyboard and the "Keep going?" board cut off on a
/// 360×640dp phone. These pin that every key stays on screen there.

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

const _screen = Size(360, 640);

Future<void> _pumpSmall(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  BannerAdSlot.debugDisabled = true;
  addTearDown(() => BannerAdSlot.debugDisabled = false);
  await tester.pumpWidget(MaterialApp(
    home: home,
    builder: (context, w) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: w!,
    ),
  ));
  await tester.pump();
}

void _expectOnScreen(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  expect(r.top, greaterThanOrEqualTo(0));
  expect(r.bottom, lessThanOrEqualTo(_screen.height),
      reason: '$f must be fully on a 360×640 screen (bottom ${r.bottom})');
}

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tutorial: keyboard fully visible and playable on 360×640',
      (tester) async {
    final storage = await _storage();
    await _pumpSmall(
        tester, OnboardingScreen(storage: storage, onFinish: () {}));

    expect(tester.takeException(), isNull, reason: 'no layout overflow');
    _expectOnScreen(tester, find.text('ENTER'));
    _expectOnScreen(tester, find.text('Z'));

    for (final key in ['B', 'R', 'E', 'A', 'D', 'ENTER']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Nicely done.'), findsOneWidget,
        reason: 'the tutorial can be finished on a small phone');
  });

  testWidgets('"Keep going?" leaves the board and keyboard visible on 360×640',
      (tester) async {
    final storage = await _storage();
    await storage.setOnboardingSeen();
    final c = GameController(
      words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
      storage: storage,
      coins: CoinService(storage),
      ads: _FakeAds(),
    );
    await _pumpSmall(tester, GameScreen(controller: c));

    final wrong = ['CRANE', 'SLATE', 'BRINE'].firstWhere((w) => w != c.answer);
    for (var i = 0; i < GameController.maxGuesses; i++) {
      for (final ch in wrong.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.awaitingContinue, isTrue);

    expect(tester.takeException(), isNull, reason: 'no layout overflow');
    expect(tester.getSize(find.byType(BoardGrid)).height, greaterThan(80),
        reason: 'the board must stay visible next to the card');
    _expectOnScreen(tester, find.text('Show answer'));
    _expectOnScreen(tester, find.text('Watch ad'));
    _expectOnScreen(tester, find.text('ENTER'));
  });

  testWidgets('normal Daily board fits on 360×640', (tester) async {
    final storage = await _storage();
    await storage.setOnboardingSeen();
    final c = GameController(
      words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
      storage: storage,
      coins: CoinService(storage),
      ads: _FakeAds(),
    );
    await _pumpSmall(tester, GameScreen(controller: c));
    expect(tester.takeException(), isNull);
    _expectOnScreen(tester, find.text('ENTER'));
    expect(tester.getSize(find.byType(BoardGrid)).height, greaterThan(120));
  });
}
