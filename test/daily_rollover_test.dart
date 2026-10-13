import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/countdown.dart';
import 'package:daily_word_game/services/storage_service.dart';

/// Verifies the "Daily Word #NNN" header tracks the (local) date live, that the
/// number and the word never diverge, and that streak / daily-board state reset
/// correctly across a date rollover — all with an injected date (no real wait).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final epoch = DateTime.utc(2025, 1, 1); // must match WordRepository._epoch

  group('daily NUMBER + WORD track the calendar date', () {
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

    test('rollover is at the LOCAL midnight of the passed date', () {
      // Same calendar day, different clock times => same number.
      expect(repo.dailyNumber(DateTime(2026, 8, 8, 0, 0, 1)),
          repo.dailyNumber(DateTime(2026, 8, 8, 23, 59, 59)));
      // Crossing local midnight bumps it, whatever the device's UTC offset.
      expect(repo.dailyNumber(DateTime(2026, 8, 9, 0, 0, 1)),
          repo.dailyNumber(DateTime(2026, 8, 8, 23, 59, 59)) + 1);
      // A New York evening (8 PM EDT = 00:00 UTC next day) is still the SAME
      // local day as that morning — the old UTC rollover changed the puzzle
      // mid-evening for US players.
      expect(repo.dailyNumber(DateTime(2026, 8, 8, 20, 30)),
          repo.dailyNumber(DateTime(2026, 8, 8, 9)));
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

  group('v6: switching day keys from UTC to local', () {
    test('future-dated keys are clamped; a future board is dropped', () async {
      // A New York player recorded a win at 9 PM local on Oct 12 — keyed to
      // the UTC date, Oct 13. After the upgrade it is still Oct 12 locally.
      SharedPreferences.setMockInitialValues({
        'flutter.daily_map_version': 6, // skip the real-clock migration
        'flutter.last_won_date': '2026-10-13',
        'flutter.last_recorded_date': '2026-10-13',
        'flutter.daily_date': '2026-10-13',
        'flutter.daily_done': true,
        'flutter.daily_won': true,
        'flutter.daily_guesses': 'CRANE',
        'flutter.stats_v1': '{"gamesPlayed":4,"gamesWon":4,"currentStreak":4,'
            '"bestStreak":4,"guessDistribution":[0,0,0,4,0,0,0]}',
      });
      final s = StorageService();
      await s.init();
      final localNow = DateTime.utc(2026, 10, 12, 22); // fields = local Oct 12
      await s.debugMigrateToV6(localNow);

      // Tomorrow's board must not resurface as "done".
      final tomorrow = DateTime.utc(2026, 10, 13, 12);
      expect(s.isDailyDone(tomorrow), isFalse);
      expect(s.loadDailyGuesses(tomorrow), isEmpty);

      // Today is already counted; tomorrow's win continues the streak.
      final same = await s.recordDailyResult(won: true, now: localNow);
      expect(same.currentStreak, 4, reason: 'no double count, no reset');
      final next = await s.recordDailyResult(
          won: true, guessesUsed: 3, now: tomorrow);
      expect(next.currentStreak, 5);
      expect(s.pendingRestoreStreak(), 0);
    });

    test('past and present keys are left alone', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.daily_map_version': 6,
        'flutter.last_won_date': '2026-10-11',
        'flutter.daily_date': '2026-10-12',
        'flutter.daily_done': false,
        'flutter.daily_guesses': 'CRANE',
      });
      final s = StorageService();
      await s.init();
      final now = DateTime.utc(2026, 10, 12, 9);
      await s.debugMigrateToV6(now);
      expect(s.loadDailyGuesses(now), ['CRANE']);
    });
  });

  group('streak survives a DST day', () {
    test('consecutive days across a 23h day still count', () async {
      SharedPreferences.setMockInitialValues({});
      final s = StorageService();
      await s.init();
      // US DST ends Nov 1 2026; keys are compared as UTC dates, so the short
      // or long local day can never break "yesterday".
      await s.recordDailyResult(
          won: true, guessesUsed: 3, now: DateTime(2026, 10, 31, 21));
      final st = await s.recordDailyResult(
          won: true, guessesUsed: 3, now: DateTime(2026, 11, 1, 21));
      expect(st.currentStreak, 2);
    });
  });

  test('countdown runs to the next LOCAL midnight', () {
    expect(timeUntilNextDaily(DateTime(2026, 10, 12, 22, 30)),
        const Duration(hours: 1, minutes: 30));
  });
}
