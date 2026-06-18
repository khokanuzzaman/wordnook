import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  Future<void> fresh() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  }

  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d, 12);

  setUp(fresh);

  group('streak', () {
    test('consecutive-day wins increment current and best streak', () async {
      var s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: day(2026, 1, 1));
      expect(s.currentStreak, 1);

      s = await storage.recordDailyResult(
          won: true, guessesUsed: 4, now: day(2026, 1, 2));
      expect(s.currentStreak, 2);

      s = await storage.recordDailyResult(
          won: true, guessesUsed: 2, now: day(2026, 1, 3));
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
      expect(s.gamesPlayed, 3);
      expect(s.gamesWon, 3);
    });

    test('a loss resets the streak and offers a restore', () async {
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 1));
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 2));
      final s = await storage.recordDailyResult(won: false, now: day(2026, 1, 3));

      expect(s.currentStreak, 0);
      expect(s.bestStreak, 2);
      expect(storage.pendingRestoreStreak(), 2, reason: 'lost streak of 2');
    });

    test('a missed day breaks the streak; next win restarts at 1 and offers restore',
        () async {
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 1));
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 2));
      // Skip Jan 3 entirely, win again on Jan 4.
      final s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: day(2026, 1, 4));

      expect(s.currentStreak, 1);
      // Restore bridges the broken run (2) plus today (1).
      expect(storage.pendingRestoreStreak(), 3);
    });

    test('restoreStreak brings the streak back and continues next day', () async {
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 1));
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 2));
      await storage.recordDailyResult(won: false, now: day(2026, 1, 3));

      final restored = await storage.restoreStreak(now: day(2026, 1, 3));
      expect(restored.currentStreak, 2);
      expect(storage.pendingRestoreStreak(), 0, reason: 'consumed once');

      // The very next day's win continues from the restored value.
      final next = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: day(2026, 1, 4));
      expect(next.currentStreak, 3);
    });

    test('first ever win does not offer a restore', () async {
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 1));
      expect(storage.pendingRestoreStreak(), 0);
    });
  });

  group('stats', () {
    test('win rate and guess distribution', () async {
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: day(2026, 1, 1));
      await storage.recordDailyResult(won: false, now: day(2026, 1, 2));
      final s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: day(2026, 1, 3));

      expect(s.gamesPlayed, 3);
      expect(s.gamesWon, 2);
      expect((s.winRate * 100).round(), 67);
      expect(s.guessDistribution[3], 2, reason: 'two wins in 3 guesses');
    });
  });

  group('journey + entitlement persistence', () {
    test('journey level defaults to 1 and persists', () async {
      expect(storage.journeyLevel, 1);
      await storage.setJourneyLevel(7);
      expect(storage.journeyLevel, 7);
      // Floor at 1.
      await storage.setJourneyLevel(0);
      expect(storage.journeyLevel, 1);
    });

    test('removeAds entitlement defaults off and persists', () async {
      expect(storage.removeAds, isFalse);
      await storage.setRemoveAds(true);
      expect(storage.removeAds, isTrue);
    });
  });

  group('daily board persistence', () {
    test('saves and restores today\'s guesses', () async {
      final today = day(2026, 1, 1);
      await storage.saveDailyProgress(
          guesses: ['CRANE', 'SLATE'], done: false, now: today);

      expect(storage.loadDailyGuesses(today), ['CRANE', 'SLATE']);
      expect(storage.isDailyDone(today), isFalse);
    });

    test('does not restore a board from a previous day', () async {
      await storage.saveDailyProgress(
          guesses: ['CRANE'], done: true, now: day(2026, 1, 1));

      expect(storage.loadDailyGuesses(day(2026, 1, 2)), isEmpty);
      expect(storage.isDailyDone(day(2026, 1, 2)), isFalse);
    });

    test('isDailyDone reflects the done flag for today', () async {
      final today = day(2026, 1, 1);
      await storage.saveDailyProgress(
          guesses: ['CRANE', 'SLATE', 'BRINE'], done: true, now: today);
      expect(storage.isDailyDone(today), isTrue);
    });
  });
}
