import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/models/letter_status.dart';
import 'package:daily_word_game/screens/onboarding/onboarding_screen.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/onboarding_controller.dart';

void _type(OnboardingController c, String word) {
  for (final ch in word.split('')) {
    c.onKey(ch);
  }
  c.onKey('ENTER');
}

Future<StorageService> _freshStorage() async {
  SharedPreferences.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  return s;
}

/// Pumps [child] on a phone-sized surface with animations disabled, so the
/// board + keyboard fit and no flip timers keep the tree busy.
Future<void> _pumpApp(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 3000);
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingController scoring & legend (pure)', () {
    test('CRANE scores correctly against BREAD', () {
      final c = OnboardingController();
      expect(c.statusesFor('CRANE'), const [
        LetterStatus.absent, // C
        LetterStatus.correct, // R (pos 2)
        LetterStatus.present, // A
        LetterStatus.absent, // N
        LetterStatus.present, // E
      ]);
    });

    test('solving requires BREAD exactly', () {
      final c = OnboardingController();
      _type(c, 'CRANE');
      expect(c.solved, isFalse);
      expect(c.step, OnboardingStep.reveal);
      _type(c, 'BREAD');
      expect(c.solved, isTrue);
      expect(c.step, OnboardingStep.win);
    });

    test('reveal legend from CRANE: R green, A/E amber, C/N grey', () {
      final c = OnboardingController()..onKey('C');
      _type(c, 'RANE'); // completes CRANE (C already typed) then ENTER
      final legend = c.revealLegend();
      expect(legend.length, 3);
      expect(legend[0].status, LetterStatus.correct);
      expect(legend[0].letter, 'R');
      expect(legend[1].status, LetterStatus.present);
      expect(['A', 'E'], contains(legend[1].letter));
      expect(legend[2].status, LetterStatus.absent);
      expect(['C', 'N'], contains(legend[2].letter));
    });

    test('grey example avoids a letter that is also amber (BERRY → Y, not R)',
        () {
      final c = OnboardingController();
      _type(c, 'BERRY');
      final legend = c.revealLegend();
      final grey = legend.firstWhere((e) => e.status == LetterStatus.absent);
      // R is amber in BERRY, so it must NOT be the "not in the word" example.
      expect(grey.letter, 'Y');
    });
  });

  group('OnboardingController stall nudge', () {
    test('shows after two guesses with no new green, dismisses, re-arms', () {
      final c = OnboardingController();
      _type(c, 'GHOST'); // no BREAD letters
      expect(c.showStallNudge, isFalse); // only one stalled guess
      _type(c, 'THUMP'); // still no green
      expect(c.showStallNudge, isTrue);

      c.dismissStallNudge();
      expect(c.showStallNudge, isFalse);

      // Making green progress re-arms; then stalling again shows it once more.
      _type(c, 'CRANE'); // locks R green → progress
      expect(c.showStallNudge, isFalse);
      _type(c, 'GHOST');
      _type(c, 'THUMP');
      expect(c.showStallNudge, isTrue);
    });
  });

  group('tutorial isolation: typing never writes real game state', () {
    test('driving the tutorial to a win leaves storage untouched', () async {
      final storage = await _freshStorage();
      // Snapshot the sensitive fields.
      final c = OnboardingController();
      _type(c, 'CRANE');
      _type(c, 'BLOND'); // arbitrary
      _type(c, 'BREAD'); // win
      expect(c.solved, isTrue);

      // The controller has no storage handle; prove nothing was written.
      expect(storage.coins, 0);
      expect(storage.journeyLevel, 1);
      expect(storage.isDailyDone(), isFalse);
      expect(storage.loadDailyGuesses(), isEmpty);
      final stats = storage.loadStats();
      expect(stats.gamesPlayed, 0);
      expect(stats.currentStreak, 0);
      expect(storage.onboardingSeen, isFalse); // controller doesn't set it
    });
  });

  group('v5 migration: existing players skip onboarding', () {
    test('a true fresh install leaves onboarding UNSEEN', () async {
      SharedPreferences.setMockInitialValues({});
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isFalse);
    });

    test('prior STATS backfills onboarding_seen (no flag before)', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.stats_v1':
            '{"gamesPlayed":4,"gamesWon":3,"currentStreak":2,"bestStreak":5,'
                '"guessDistribution":[0,0,1,1,1,0,0]}',
      });
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isTrue);
    });

    test('prior COINS alone backfills the flag', () async {
      SharedPreferences.setMockInitialValues({'flutter.coins': 60});
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isTrue);
    });

    test('prior JOURNEY progress alone backfills the flag', () async {
      SharedPreferences.setMockInitialValues({'flutter.journey_level': 4});
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isTrue);
    });

    test('an unlocked THEME alone backfills the flag', () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.unlocked_themes': 'forest'});
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isTrue);
    });

    test('a recorded DAILY alone backfills the flag', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.last_won_date': '2026-01-02',
      });
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isTrue);
    });

    test('does not clobber an explicit onboarding_seen=false with no state',
        () async {
      // Fresh install that has begun (version stamped) but no play + no flag:
      // journey_level default 1, coins 0 → still unseen.
      SharedPreferences.setMockInitialValues({
        'flutter.journey_level': 1,
        'flutter.coins': 0,
      });
      final s = StorageService();
      await s.init();
      expect(s.onboardingSeen, isFalse);
    });
  });

  group('storage.beginStreakFromOnboarding', () {
    test('seeds streak=1 and last_won_date=today, nothing else', () async {
      final storage = await _freshStorage();
      final s = await storage.beginStreakFromOnboarding();
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 1);
      // Daily ledger + coins untouched; today's real daily still playable.
      expect(storage.isDailyDone(), isFalse);
      expect(storage.isDailyRecorded(), isFalse);
      expect(storage.coins, 0);
      expect(s.gamesPlayed, 0);
      // last_won_date == today means tomorrow's win makes it two.
      expect(storage.pendingRestoreStreak(), 0);
    });
  });

  group('OnboardingScreen widget flow', () {
    testWidgets('skip sets the seen flag and does NOT seed a streak',
        (tester) async {
      final storage = await _freshStorage();
      var finished = false;
      await _pumpApp(
        tester,
        OnboardingScreen(storage: storage, onFinish: () => finished = true),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(storage.onboardingSeen, isTrue);
      expect(storage.loadStats().currentStreak, 0, reason: 'skip seeds nothing');
      expect(storage.reminderEnabled, isFalse,
          reason: 'skip must not silently enable the reminder');
    });

    testWidgets('winning sets the flag, seeds streak=1, leaves the daily free',
        (tester) async {
      final storage = await _freshStorage();
      var finished = false;
      await _pumpApp(
        tester,
        OnboardingScreen(storage: storage, onFinish: () => finished = true),
      );

      for (final key in ['B', 'R', 'E', 'A', 'D', 'ENTER']) {
        await tester.tap(find.text(key));
        await tester.pump();
      }
      await tester.pumpAndSettle(); // win sheet

      expect(find.text('Nicely done.'), findsOneWidget);
      await tester.tap(find.text("Play today's Daily"));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(storage.onboardingSeen, isTrue);
      expect(storage.loadStats().currentStreak, 1);
      expect(storage.isDailyDone(), isFalse, reason: 'daily stays playable');
      expect(storage.coins, 0);
      expect(storage.reminderEnabled, isFalse,
          reason: 'ignoring the reminder card leaves it off');
    });
  });
}
