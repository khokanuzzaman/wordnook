import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/screens/game_screen.dart';
import 'package:daily_word_game/screens/widgets/banner_ad_slot.dart';
import 'package:daily_word_game/screens/widgets/daily_ready_sheet.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/analytics_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  int interstitials = 0;
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() => interstitials++;
}

class _RecordingAnalytics implements Analytics {
  final List<String> names = [];
  final List<Map<String, Object>?> params = [];
  @override
  void logEvent(String name, [Map<String, Object>? p]) {
    names.add(name);
    params.add(p);
  }

  @override
  void setUserProperty(String name, String value) {}
}

const _words = ['CRANE', 'SLATE', 'BRINE', 'PLUMP', 'GHOST'];

Future<StorageService> _storage({bool newPlayer = true}) async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  await s.setOnboardingSeen();
  if (newPlayer) await s.setFirstStepsActive(true);
  return s;
}

GameController _controller(StorageService s,
        {_FakeAds? ads, Analytics? analytics}) =>
    GameController(
      words: WordRepository()..debugLoad(_words),
      storage: s,
      coins: CoinService(s),
      ads: ads ?? _FakeAds(),
      analytics: analytics,
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
  tearDown(() => BannerAdSlot.debugDisabled = false);

  group('controller', () {
    test('warm-up numbers 1–3 on Journey, then none', () async {
      final s = await _storage();
      final c = _controller(s);
      c.startGame(GameMode.journey);
      for (var n = 1; n <= GameController.firstStepsLevels; n++) {
        expect(c.warmUpStep, n);
        expect(c.firstStepsJustCompleted, isFalse);
        await _solve(c);
        if (n < GameController.firstStepsLevels) c.nextJourneyLevel();
      }
      expect(c.firstStepsJustCompleted, isTrue,
          reason: 'solving the last warm-up is the moment for the Daily card');
      c.nextJourneyLevel();
      expect(c.warmUpStep, isNull, reason: 'level 4 is a normal level');
    });

    test('no warm-up label in Daily or for existing players', () async {
      var s = await _storage();
      var c = _controller(s)..startGame(GameMode.daily);
      expect(c.warmUpStep, isNull);

      s = await _storage(newPlayer: false);
      c = _controller(s)..startGame(GameMode.journey);
      expect(c.inFirstSteps, isFalse);
      expect(c.warmUpStep, isNull);
    });

    test('endFirstSteps is one-shot and logged once', () async {
      final s = await _storage();
      final analytics = _RecordingAnalytics();
      final c = _controller(s, analytics: analytics)
        ..startGame(GameMode.journey);
      await c.endFirstSteps(AnalyticsFirstStepsEnd.warmedUp);
      await c.endFirstSteps(AnalyticsFirstStepsEnd.warmedUp);
      expect(s.firstStepsActive, isFalse);
      expect(c.warmUpStep, isNull);
      expect(
          analytics.names
              .where((n) => n == AnalyticsEvents.firstStepsCompleted)
              .length,
          1);
    });

    test('no interstitial during the warm-up', () async {
      final s = await _storage();
      final ads = _FakeAds();
      final c = _controller(s, ads: ads)..startGame(GameMode.journey);
      for (var n = 1; n <= GameController.firstStepsLevels; n++) {
        await _solve(c);
        c.nextJourneyLevel();
      }
      expect(ads.interstitials, 0);
    });
  });

  group('screen', () {
    Future<void> pumpGame(WidgetTester tester, GameController c) async {
      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BannerAdSlot.debugDisabled = true;
      await tester.pumpWidget(MaterialApp(
        home: GameScreen(controller: c),
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: w!,
        ),
      ));
      await tester.pump();
    }

    testWidgets('a new player opens on warm-up 1 of 3', (tester) async {
      final s = await _storage();
      final c = _controller(s);
      await pumpGame(tester, c);
      expect(c.mode, GameMode.journey);
      expect(find.text('WARM-UP 1 OF 3'), findsOneWidget);
    });

    testWidgets('an existing player still opens on the Daily', (tester) async {
      final s = await _storage(newPlayer: false);
      final c = _controller(s);
      await pumpGame(tester, c);
      expect(c.mode, GameMode.daily);
      expect(find.text("TODAY'S PUZZLE"), findsOneWidget);
    });

    testWidgets('switching to Daily during the warm-up ends First Steps',
        (tester) async {
      final s = await _storage();
      final c = _controller(s);
      await pumpGame(tester, c);
      await tester.tap(find.text('Daily'));
      await tester.pump();
      expect(c.mode, GameMode.daily);
      expect(s.firstStepsActive, isFalse);
    });
  });

  group('DailyReadySheet', () {
    Future<bool?> openAndTap(WidgetTester tester, String label) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await DailyReadySheet.show(context),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text("You're ready"), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Play today\'s Daily resolves true', (tester) async {
      expect(await openAndTap(tester, "Play today's Daily"), isTrue);
    });

    testWidgets('Keep going resolves false', (tester) async {
      expect(await openAndTap(tester, 'Keep going in Journey'), isFalse);
    });
  });
}
