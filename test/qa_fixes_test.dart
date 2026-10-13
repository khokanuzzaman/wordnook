import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/tips.dart';
import 'package:daily_word_game/screens/game_screen.dart';
import 'package:daily_word_game/screens/widgets/banner_ad_slot.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/analytics_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

/// Regression tests for the issues found in the Phase 2a QA pass.

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

class _Recorder implements Analytics {
  final List<String> calls = [];
  @override
  void logEvent(String name, [Map<String, Object>? params]) =>
      calls.add('event:$name');
  @override
  void setUserProperty(String name, String value) =>
      calls.add('prop:$name=$value');
}

Future<StorageService> _storage({bool firstSteps = false}) async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  await s.setOnboardingSeen();
  if (firstSteps) await s.setFirstStepsActive(true);
  return s;
}

GameController _controller(StorageService s) => GameController(
      words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
      storage: s,
      coins: CoinService(s),
      ads: _FakeAds(),
    );

Future<void> _solve(GameController c) async {
  for (final ch in c.answer.split('')) {
    c.onKey(ch);
  }
  c.onKey('ENTER');
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('header names the solved level until "Next level"', () {
    test('Journey level number', () async {
      final s = await _storage();
      final c = _controller(s)..startGame(GameMode.journey);
      expect(c.displayedJourneyLevel, 1);
      await _solve(c);
      expect(c.journeyLevel, 2, reason: 'progress is saved at the win');
      expect(c.displayedJourneyLevel, 1, reason: 'the board is still level 1');
      c.nextJourneyLevel();
      expect(c.displayedJourneyLevel, 2);
    });

    test('warm-up label stays on the solved warm-up, incl. the last one',
        () async {
      final s = await _storage(firstSteps: true);
      final c = _controller(s)..startGame(GameMode.journey);
      for (var n = 1; n <= GameController.firstStepsLevels; n++) {
        await _solve(c);
        expect(c.warmUpStep, n, reason: 'solved board is still warm-up $n');
        c.nextJourneyLevel();
      }
      expect(c.warmUpStep, isNull, reason: 'level 4 is a normal level');
    });
  });

  group('cold-start analytics are buffered, not dropped', () {
    test('events before init replay in order into the real sink', () {
      final buffer = BufferingAnalytics()
        ..logEvent('onboarding_started')
        ..setUserProperty('theme', 'cozy')
        ..logEvent('daily_started', {'x': 1});
      final real = _Recorder();
      buffer.flushTo(real);
      expect(real.calls, [
        'event:onboarding_started',
        'prop:theme=cozy',
        'event:daily_started',
      ]);
      expect(buffer.pendingCount, 0);
    });

    test('the buffer is capped', () {
      final buffer = BufferingAnalytics();
      for (var i = 0; i < BufferingAnalytics.maxBuffered + 50; i++) {
        buffer.logEvent('e$i');
      }
      expect(buffer.pendingCount, BufferingAnalytics.maxBuffered);
    });
  });

  group('idle tip respects the drawer', () {
    testWidgets('no idle tip while the drawer is open; it waits for close',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BannerAdSlot.debugDisabled = true;
      addTearDown(() => BannerAdSlot.debugDisabled = false);

      final s = await _storage();
      final c = _controller(s);
      await tester.pumpWidget(MaterialApp(
        home: GameScreen(controller: c),
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: w!,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.pump(TipRules.idleDelay + const Duration(seconds: 2));
      expect(s.tipsSeen, isNot(contains(TipRules.id(Tip.idleStart))),
          reason: 'nobody can see a tip behind the drawer');

      // Close the drawer: the idle clock starts again and the tip shows.
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.closeDrawer();
      await tester.pumpAndSettle();
      await tester.pump(TipRules.idleDelay + const Duration(seconds: 1));
      expect(s.tipsSeen, contains(TipRules.id(Tip.idleStart)));
      await tester.pump(const Duration(seconds: 5)); // let the toast finish
    });
  });
}
