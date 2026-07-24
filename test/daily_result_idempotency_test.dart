import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/coin_rules.dart';
import 'package:daily_word_game/services/ads_service.dart';
import 'package:daily_word_game/services/analytics_service.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/state/game_controller.dart';

class _FakeAds implements GameAds {
  @override
  Future<bool> showRewarded() async => true;
  @override
  void maybeShowJourneyInterstitial() {}
}

/// Captures emitted events so we can assert a bogus streak_broken never fires.
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

  Iterable<Map<String, Object>?> paramsFor(String name) sync* {
    for (var i = 0; i < names.length; i++) {
      if (names[i] == name) yield params[i];
    }
  }
}

const _words = ['CRANE', 'SLATE', 'BRINE'];

DateTime _d(int y, int m, int day) => DateTime.utc(y, m, day);

Future<StorageService> _storage() async {
  final s = StorageService();
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('recordDailyResult is idempotent per UTC date', () {
    test('a second record for the same date changes nothing', () async {
      final storage = await _storage();
      final day = _d(2026, 3, 10);

      final first = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: day);
      expect(first.gamesPlayed, 1);
      expect(first.currentStreak, 1);

      // A conflicting second write for the SAME date must be ignored entirely.
      final second = await storage.recordDailyResult(
          won: false, guessesUsed: null, now: day);

      expect(second.gamesPlayed, first.gamesPlayed);
      expect(second.gamesWon, first.gamesWon);
      expect(second.currentStreak, first.currentStreak);
      expect(second.bestStreak, first.bestStreak);
      expect(second.guessDistribution, first.guessDistribution);
      // last_won_date / broken_streak must be untouched too: a restore offer
      // must not appear out of nowhere.
      expect(storage.pendingRestoreStreak(), 0);
    });

    test('a repeated WIN does not inflate stats or the streak', () async {
      final storage = await _storage();
      final day = _d(2026, 3, 10);
      await storage.recordDailyResult(won: true, guessesUsed: 2, now: day);
      for (var i = 0; i < 4; i++) {
        await storage.recordDailyResult(won: true, guessesUsed: 2, now: day);
      }
      final s = storage.loadStats();
      expect(s.gamesPlayed, 1);
      expect(s.gamesWon, 1);
      expect(s.currentStreak, 1);
      expect(s.guessDistribution[2], 1);
    });

    test('normal day-over-day progression still increments the streak',
        () async {
      final storage = await _storage();
      var s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 10));
      expect(s.currentStreak, 1);
      s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 11));
      expect(s.currentStreak, 2);
      s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 12));
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
      expect(s.gamesPlayed, 3);
      expect(storage.pendingRestoreStreak(), 0);
    });

    test('a genuine missed day still breaks the streak', () async {
      final storage = await _storage();
      await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 10));
      await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 11));
      // 3/12 skipped entirely.
      final s = await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: _d(2026, 3, 13));
      expect(s.currentStreak, 1, reason: 'the gap must break the run');
      expect(s.bestStreak, 2);
      expect(storage.pendingRestoreStreak(), greaterThan(0),
          reason: 'a broken streak should still be restorable');
    });
  });

  group('controller: extra guess cannot rewrite a recorded daily', () {
    test('lose → extra guess → win leaves the streak alone and fires '
        'streak_broken exactly once', () async {
      final storage = await _storage();
      final coins = CoinService(storage);
      final analytics = _RecordingAnalytics();
      final c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: coins,
        ads: _FakeAds(),
        analytics: analytics,
      );

      // Build a real streak first, so a bogus reset would be visible.
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: yesterday);
      expect(storage.loadStats().currentStreak, 1);

      c.startGame(GameMode.daily);
      // Lose today: six wrong guesses.
      final wrong = _words.firstWhere((w) => w != c.answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        for (final ch in wrong.split('')) {
          c.onKey(ch);
        }
        c.onKey('ENTER');
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);

      final afterLoss = storage.loadStats();
      expect(afterLoss.currentStreak, 0, reason: 'the loss legitimately ends it');
      final brokenAfterLoss =
          analytics.names.where((n) => n == AnalyticsEvents.streakBroken).length;
      expect(brokenAfterLoss, 1, reason: 'one legitimate break for the loss');

      // Buy an extra guess and WIN on the reopened board.
      await coins.award(CoinRules.extraGuessCost);
      await c.useExtraGuess();
      expect(c.gameOver, isFalse);
      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);
      expect(c.won, isTrue);

      // The recorded result for today is final.
      final afterExtra = storage.loadStats();
      expect(afterExtra.gamesPlayed, afterLoss.gamesPlayed,
          reason: 'today must not be counted twice');
      expect(afterExtra.gamesWon, afterLoss.gamesWon);
      expect(afterExtra.currentStreak, afterLoss.currentStreak,
          reason: 'the streak must not be rewritten by the extra guess');
      expect(afterExtra.guessDistribution, afterLoss.guessDistribution);

      // No SECOND streak_broken, and nothing claiming a missed day.
      final breaks =
          analytics.names.where((n) => n == AnalyticsEvents.streakBroken).length;
      expect(breaks, 1, reason: 'no bogus extra break may fire');
      for (final p in analytics.paramsFor(AnalyticsEvents.streakBroken)) {
        expect(p?[AnalyticsParams.reason], AnalyticsReasons.loss,
            reason: 'a missed_day break here would be fabricated');
      }
    });
  });

  group('migration v3 backfills the guard for existing installs', () {
    /// yyyy-mm-dd for today in UTC, matching StorageService's day key.
    String todayKey() {
      final d = DateTime.now().toUtc();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    test('a daily finished on an older build cannot be re-recorded', () async {
      final today = todayKey();
      // An old install: today's daily already finished and counted, but with
      // no schema version and no last_recorded_date.
      SharedPreferences.setMockInitialValues({
        'flutter.daily_date': today,
        'flutter.daily_done': true,
        'flutter.daily_guesses': 'CRANE,SLATE',
        'flutter.last_won_date': today,
        'flutter.stats_v1':
            '{"gamesPlayed":5,"gamesWon":5,"currentStreak":5,"bestStreak":5,'
                '"guessDistribution":[0,0,0,5,0,0,0]}',
      });

      final storage = await _storage();
      final before = storage.loadStats();
      expect(before.currentStreak, 5, reason: 'migration preserves stats');
      expect(before.gamesPlayed, 5);

      // The guard must now know today was already recorded.
      final after = await storage.recordDailyResult(won: false);
      expect(after.currentStreak, 5,
          reason: 'a post-upgrade re-record must not reset the streak');
      expect(after.gamesPlayed, 5);
      expect(after.gamesWon, 5);
      expect(storage.pendingRestoreStreak(), 0);
    });

    test('an unfinished daily is still recordable after upgrade', () async {
      final today = todayKey();
      SharedPreferences.setMockInitialValues({
        'flutter.daily_date': today,
        'flutter.daily_done': false,
        'flutter.daily_guesses': 'CRANE',
      });

      final storage = await _storage();
      // Nothing was recorded for today, so the first real result must land.
      final s = await storage.recordDailyResult(won: true, guessesUsed: 4);
      expect(s.gamesPlayed, 1);
      expect(s.currentStreak, 1);
    });
  });
}
