import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/countdown.dart';
import 'package:daily_word_game/screens/widgets/board_info_bar.dart';
import 'package:daily_word_game/screens/widgets/identity_header.dart';
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

const _words = ['CRANE', 'SLATE', 'BRINE'];

Future<GameController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return GameController(
    words: WordRepository()..debugLoad(_words),
    storage: storage,
    coins: CoinService(storage),
    ads: _FakeAds(),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: child),
    builder: (context, w) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: w!,
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('countdown (pure)', () {
    test('time to next daily is within (0, 24h]', () {
      final d = timeUntilNextDaily(DateTime.utc(2026, 5, 1, 9, 39, 30));
      expect(d, const Duration(hours: 14, minutes: 20, seconds: 30));
    });
    test('formats with and without seconds', () {
      const d = Duration(hours: 14, minutes: 11, seconds: 30);
      expect(formatCountdown(d), '14h 11m');
      expect(formatCountdown(d, withSeconds: true), '14h 11m 30s');
    });
    test('never negative', () {
      expect(formatCountdown(const Duration(seconds: -5)), '0h 0m');
    });
  });

  group('journeyChapter derivation', () {
    test('10 levels per chapter', () async {
      final c = await _controller();
      // Level 1 by default.
      expect(c.journeyChapter, 1);
    });
  });

  group('daily rollover refresh guard', () {
    test('a freshly started daily is NOT flagged stale', () async {
      final c = await _controller();
      c.startGame(GameMode.daily);
      expect(c.dailyNeedsRefresh, isFalse);
    });
    test('journey mode never asks for a daily refresh', () async {
      final c = await _controller();
      c.startGame(GameMode.journey);
      expect(c.dailyNeedsRefresh, isFalse);
    });
  });

  group('daily header number', () {
    test('is the live number, and its day matches the loaded word', () async {
      final c = await _controller();
      c.startGame(GameMode.daily);

      // A separate repo with the SAME word list resolves the same permutation.
      final words = WordRepository()..debugLoad(_words);

      // Not hardcoded/cached: it equals today's live computation.
      expect(c.dailyNumber, words.dailyNumber());

      // Same-day guarantee: the word for the day the header number points to is
      // exactly the puzzle loaded on the board.
      final dayIndex = c.dailyNumber - 1;
      final dateOfNumber =
          DateTime.utc(2025, 1, 1).add(Duration(days: dayIndex));
      expect(words.dailyWord(dateOfNumber), c.answer,
          reason: 'header number and puzzle must be the same day');
    });
  });

  group('IdentityHeader', () {
    testWidgets('Daily shows the real puzzle number', (tester) async {
      await _pump(
        tester,
        const IdentityHeader(
            isJourney: false, dailyNumber: 584, level: 1, chapter: 1),
      );
      expect(find.text("TODAY'S PUZZLE"), findsOneWidget);
      expect(find.text('Daily Word #584'), findsOneWidget);
      expect(find.text('Guess the hidden 5-letter word in six tries.'),
          findsOneWidget);
    });

    testWidgets('Journey shows chapter + level', (tester) async {
      await _pump(
        tester,
        const IdentityHeader(
            isJourney: true, dailyNumber: 584, level: 12, chapter: 2),
      );
      expect(find.text('JOURNEY · CHAPTER 2'), findsOneWidget);
      expect(find.text('Level 12'), findsOneWidget);
      expect(find.text('Guess the hidden 5-letter word to advance.'),
          findsOneWidget);
    });
  });

  group('BoardInfoBar', () {
    testWidgets('empty Daily: prompt + streak chip, NO countdown',
        (tester) async {
      final c = await _controller();
      c.startGame(GameMode.daily);
      await _pump(tester, BoardInfoBar(controller: c));

      expect(find.text('Start with any 5-letter word.'), findsOneWidget);
      expect(find.textContaining('streak'), findsOneWidget);
      expect(find.textContaining('Next word in'), findsNothing);
    });

    testWidgets('solved Daily: countdown chip appears, prompt gone',
        (tester) async {
      final c = await _controller();
      // Seed today's daily as already solved (deterministic — no async win).
      c.startGame(GameMode.daily);
      final answer = c.answer;
      await c.storage.saveDailyProgress(guesses: [answer], done: true);
      await c.storage.saveDailyOutcome(won: true);
      c.startGame(GameMode.daily);
      expect(c.gameOver && c.won, isTrue);

      await _pump(tester, BoardInfoBar(controller: c));
      expect(find.textContaining('Next word in'), findsOneWidget);
      expect(find.text('Start with any 5-letter word.'), findsNothing);
    });

    testWidgets('Journey chip: fresh Level 1 says no levels cleared yet',
        (tester) async {
      final c = await _controller();
      c.startGame(GameMode.journey);
      expect(c.journeyLevel, 1);
      await _pump(tester, BoardInfoBar(controller: c));
      expect(find.text('No levels cleared yet'), findsOneWidget);
      expect(find.textContaining('Next word in'), findsNothing);
    });

    testWidgets(
        'Journey chip: after solving one level it says "1 level cleared"',
        (tester) async {
      final c = await _controller();
      c.startGame(GameMode.journey);
      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      // Real async: the win persists progress through the (mock) prefs.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(c.won, isTrue);
      expect(c.journeyLevel, 2); // advanced on the win

      await _pump(tester, BoardInfoBar(controller: c));
      expect(find.text('1 level cleared'), findsOneWidget);
      expect(find.text('No levels cleared yet'), findsNothing);
    });
  });
}
