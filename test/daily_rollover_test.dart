import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/services/storage_service.dart';

/// Verifies the "Daily Word #NNN" header tracks the (UTC) date live, that the
/// number and the word never diverge, and that streak / daily-board state reset
/// correctly across a date rollover — all with an injected date (no real wait).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final epoch = DateTime.utc(2025, 1, 1); // must match WordRepository._epoch

  group('daily NUMBER + WORD track the UTC date', () {
    late WordRepository repo;
    setUp(() {
      repo = WordRepository()
        ..debugLoad(const [
          'CRANE', 'SLATE', 'BRINE', 'PLUMP', 'GHOST',
          'TIGER', 'MANGO', 'RIVER', 'STONE', 'FLAME',
        ]);
    });

    test('number increments by exactly 1 each consecutive day', () {
      final d1 = DateTime.utc(2026, 8, 8, 12);
      expect(repo.dailyNumber(DateTime.utc(2026, 8, 9, 12)),
          repo.dailyNumber(d1) + 1);
      expect(repo.dailyNumber(DateTime.utc(2026, 8, 10, 12)),
          repo.dailyNumber(d1) + 2);
    });

    test('the number for today (2026-08-08 UTC) is exactly 585', () {
      // Pins the epoch math: days since 2025-01-01 + 1. Matches the device.
      expect(repo.dailyNumber(DateTime.utc(2026, 8, 8, 12)), 585);
    });

    test('word changes each day AND belongs to the same day as the number', () {
      for (final d in [
        DateTime.utc(2026, 8, 8),
        DateTime.utc(2026, 8, 9),
        DateTime.utc(2026, 8, 10),
      ]) {
        final n = repo.dailyNumber(d);
        final w = repo.dailyWord(d);
        // Rebuild the date purely from the number; its word must be identical.
        final dateFromNumber = epoch.add(Duration(days: n - 1));
        expect(repo.dailyWord(dateFromNumber), w,
            reason: 'number $n and its word must resolve to the same UTC day');
      }
      expect(repo.dailyWord(DateTime.utc(2026, 8, 8)),
          isNot(repo.dailyWord(DateTime.utc(2026, 8, 9))));
    });

    test('rollover is at UTC midnight, not device-local', () {
      // Same UTC day, different clock times => same number.
      expect(repo.dailyNumber(DateTime.utc(2026, 8, 8, 0, 0, 1)),
          repo.dailyNumber(DateTime.utc(2026, 8, 8, 23, 59, 59)));
      // A Dhaka (+06:00) instant that is 2 AM "next day" locally is still the
      // PREVIOUS day in UTC -> same number (proves .toUtc() normalisation).
      final dhaka2amNextDay = DateTime.parse('2026-08-09T02:00:00+06:00');
      expect(repo.dailyNumber(dhaka2amNextDay),
          repo.dailyNumber(DateTime.utc(2026, 8, 8, 12)));
      // Crossing UTC midnight bumps it.
      expect(repo.dailyNumber(DateTime.utc(2026, 8, 9, 0, 0, 1)),
          repo.dailyNumber(DateTime.utc(2026, 8, 8, 12)) + 1);
    });
  });

  group('streak + daily-board reset across the rollover', () {
    late StorageService s;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      s = StorageService();
      await s.init();
    });

    test('consecutive-day wins increment the streak; a gap resets it', () async {
      var st = await s.recordDailyResult(
          won: true, guessesUsed: 3, now: DateTime.utc(2026, 8, 8, 12));
      expect(st.currentStreak, 1);
      st = await s.recordDailyResult(
          won: true, guessesUsed: 4, now: DateTime.utc(2026, 8, 9, 12));
      expect(st.currentStreak, 2);
      st = await s.recordDailyResult(
          won: true, guessesUsed: 2, now: DateTime.utc(2026, 8, 10, 12));
      expect(st.currentStreak, 3);
      // Skip 08-11 -> a genuine gap -> streak resets to 1 on 08-12.
      st = await s.recordDailyResult(
          won: true, guessesUsed: 5, now: DateTime.utc(2026, 8, 12, 12));
      expect(st.currentStreak, 1);
    });

    test('daily_done / daily_won / last_recorded reset on the new UTC day',
        () async {
      final d1 = DateTime.utc(2026, 8, 8, 12);
      final d2 = DateTime.utc(2026, 8, 9, 12);
      await s.saveDailyProgress(guesses: ['CRANE'], done: true, now: d1);
      await s.saveDailyOutcome(won: true, now: d1);
      await s.recordDailyResult(won: true, guessesUsed: 1, now: d1);

      expect(s.isDailyDone(d1), isTrue);
      expect(s.isDailyWon(d1), isTrue);
      expect(s.isDailyRecorded(d1), isTrue);
      expect(s.loadDailyGuesses(d1), ['CRANE']);

      // The SAME stored state, read on the next UTC day, is "not today":
      expect(s.isDailyDone(d2), isFalse);
      expect(s.isDailyWon(d2), isFalse);
      expect(s.isDailyRecorded(d2), isFalse);
      expect(s.loadDailyGuesses(d2), isEmpty);
    });

    test('recordDailyResult idempotent within a day, records again next day',
        () async {
      var st = await s.recordDailyResult(
          won: true, guessesUsed: 3, now: DateTime.utc(2026, 8, 8, 12));
      expect(st.gamesPlayed, 1);
      st = await s.recordDailyResult(
          won: true, guessesUsed: 1, now: DateTime.utc(2026, 8, 8, 20));
      expect(st.gamesPlayed, 1, reason: 'same UTC day = no-op');
      st = await s.recordDailyResult(
          won: true, guessesUsed: 2, now: DateTime.utc(2026, 8, 9, 12));
      expect(st.gamesPlayed, 2);
      expect(st.currentStreak, 2);
    });
  });
}
