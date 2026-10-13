import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/screens/how_to_play_screen.dart';
import 'package:daily_word_game/screens/settings_screen.dart';
import 'package:daily_word_game/screens/statistics_screen.dart';
import 'package:daily_word_game/screens/widgets/banner_ad_slot.dart';
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

/// Pumps [child] on a phone-sized surface with animations disabled (so implicit
/// animations settle instantly and reduced-motion paths are exercised).
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: child,
    builder: (context, w) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: w!,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<StorageService> _storage(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final s = StorageService();
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => BannerAdSlot.debugDisabled = false);

  group('Settings — board theme prices (real app values, not the mockup)', () {
    testWidgets('locked themes show their real coin cost; free/selected do not',
        (tester) async {
      final storage = await _storage({});
      await _pump(
        tester,
        SettingsScreen(storage: storage, coins: CoinService(storage)),
      );

      // Every theme is listed.
      for (final name in [
        'Cozy',
        'Forest',
        'Sunset',
        'Mono',
        'High contrast'
      ]) {
        expect(find.text(name), findsOneWidget, reason: '$name should render');
      }

      // Real prices from game_theme.dart — NOT the addendum's 120/120/200.
      expect(find.text('150'), findsOneWidget); // Forest
      expect(find.text('200'), findsOneWidget); // Sunset
      expect(find.text('100'), findsOneWidget); // Mono
      expect(find.text('120'), findsNothing); // the mockup's wrong price

      // Exactly three locked themes (Forest/Sunset/Mono); Cozy is selected and
      // High contrast is a free accessibility theme — neither is locked.
      expect(find.byIcon(Icons.lock), findsNWidgets(3));
      // The single selected check badge belongs to Cozy (the default).
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('Settings — reminder time row dimming', () {
    testWidgets('dims (opacity 0.4) when the reminder is off', (tester) async {
      final storage = await _storage({'reminder_enabled': false});
      await _pump(
        tester,
        SettingsScreen(storage: storage, coins: CoinService(storage)),
      );

      final opacity =
          tester.widget<Opacity>(find.byKey(const Key('reminder-time-dim')));
      expect(opacity.opacity, 0.4);
    });

    testWidgets('is full opacity when the reminder is on', (tester) async {
      final storage = await _storage({'reminder_enabled': true});
      await _pump(
        tester,
        SettingsScreen(storage: storage, coins: CoinService(storage)),
      );

      final opacity =
          tester.widget<Opacity>(find.byKey(const Key('reminder-time-dim')));
      expect(opacity.opacity, 1.0);
    });
  });

  group('Statistics — renders the real numbers', () {
    testWidgets('stat cards + best distribution bar show seeded values',
        (tester) async {
      BannerAdSlot.debugDisabled = true;
      final storage = await _storage({
        'stats_v1': jsonEncode({
          'gamesPlayed': 48,
          'gamesWon': 44, // 44/48 = 92%
          'currentStreak': 3,
          'bestStreak': 11,
          'guessDistribution': [0, 0, 1, 5, 16, 7, 3],
        }),
      });
      final controller = GameController(
        words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
      );

      await _pump(tester, StatisticsScreen(controller: controller));

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('48'), findsOneWidget); // Played
      expect(find.text('92'), findsOneWidget); // Win %
      expect(find.text('11'), findsOneWidget); // Best
      expect(find.text('16'), findsOneWidget); // the max distribution row
      expect(find.text('GUESS DISTRIBUTION'), findsOneWidget);
      // The cozy line reflects the real current streak.
      expect(find.textContaining('3-day streak'), findsOneWidget);
    });
  });

  group('Statistics — banner ad only in Journey', () {
    Future<GameController> controllerFor(GameMode mode) async {
      final storage = await _storage({});
      final controller = GameController(
        words: WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
      );
      controller.startGame(mode);
      return controller;
    }

    // BannerAdSlot.debugDisabled keeps the slot off the AdMob plugin, so the
    // slot is present in the tree (as a zero-size widget) without loading an ad.
    testWidgets('Daily: no banner slot', (tester) async {
      BannerAdSlot.debugDisabled = true;
      final controller = await controllerFor(GameMode.daily);
      await _pump(tester, StatisticsScreen(controller: controller));

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.byType(BannerAdSlot), findsNothing);
    });

    testWidgets('Journey: banner slot present', (tester) async {
      BannerAdSlot.debugDisabled = true;
      final controller = await controllerFor(GameMode.journey);
      await _pump(tester, StatisticsScreen(controller: controller));

      expect(find.byType(BannerAdSlot), findsOneWidget);
    });
  });

  group('How to play — the three worked examples render', () {
    testWidgets('shows the intro, three example rows, and the info note',
        (tester) async {
      await _pump(tester, const HowToPlayScreen());

      expect(find.text('How to play'), findsOneWidget);
      expect(find.textContaining('Guess the hidden 5-letter word in six tries'),
          findsOneWidget);
      expect(find.textContaining('BREAD'), findsOneWidget);
      expect(find.textContaining('CRUMB'), findsOneWidget);
      expect(find.textContaining('TOAST'), findsOneWidget);
      expect(
          find.textContaining('A new word arrives every day'), findsOneWidget);
    });
  });
}
