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

  group('controller: "Keep going?" happens BEFORE the result is recorded', () {
    Future<void> missSix(GameController c) async {
      final wrong = _words.firstWhere((w) => w != c.answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        for (final ch in wrong.split('')) {
          c.onKey(ch);
        }
        c.onKey('ENTER');
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('sixth miss opens the offer and records nothing yet', () async {
      final storage = await _storage();
      final c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
        analytics: _RecordingAnalytics(),
      );
      c.startGame(GameMode.daily);
      await missSix(c);

      expect(c.awaitingContinue, isTrue);
      expect(c.gameOver, isFalse);
      expect(c.acceptingInput, isFalse);
      expect(storage.isDailyRecorded(), isFalse,
          reason: 'nothing may be final while the offer is open');
      expect(storage.loadStats().gamesPlayed, 0);
    });

    test('buying a row and then winning keeps the streak going', () async {
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

      // A real streak from yesterday.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: yesterday);
      expect(storage.loadStats().currentStreak, 1);

      c.startGame(GameMode.daily);
      await missSix(c);
      await coins.award(CoinRules.extraGuessCost);
      await c.continueWithCoins();
      expect(coins.coins, 0);
      expect(c.acceptingInput, isTrue);
      expect(c.maxRows, GameController.maxGuesses + 1);

      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);

      expect(c.won, isTrue);
      final s = storage.loadStats();
      expect(s.currentStreak, 2, reason: 'the extra row saved the streak');
      expect(s.gamesPlayed, 2);
      expect(s.gamesWon, 2);
      expect(
          analytics.names.where((n) => n == AnalyticsEvents.streakBroken),
          isEmpty);
    });

    test('giving up records exactly one loss and one streak_broken', () async {
      final storage = await _storage();
      final analytics = _RecordingAnalytics();
      final c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
        analytics: analytics,
      );
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await storage.recordDailyResult(
          won: true, guessesUsed: 3, now: yesterday);

      c.startGame(GameMode.daily);
      await missSix(c);
      await c.declineContinue();

      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);
      final s = storage.loadStats();
      expect(s.currentStreak, 0);
      expect(s.gamesPlayed, 2);
      expect(
          analytics.names.where((n) => n == AnalyticsEvents.streakBroken).length,
          1);
      for (final p in analytics.paramsFor(AnalyticsEvents.streakBroken)) {
        expect(p?[AnalyticsParams.reason], AnalyticsReasons.loss);
      }

      // A second decline is a no-op.
      await c.declineContinue();
      expect(storage.loadStats().gamesPlayed, 2);
    });

    test('only one extra row per puzzle', () async {
      final storage = await _storage();
      final coins = CoinService(storage);
      final c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: coins,
        ads: _FakeAds(),
      );
      c.startGame(GameMode.daily);
      await missSix(c);
      await c.continueWithAd();
      expect(c.acceptingInput, isTrue);

      // Miss the extra row too.
      final wrong = _words.firstWhere((w) => w != c.answer);
      for (final ch in wrong.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);

      expect(c.gameOver, isTrue, reason: 'no second offer — the loss is final');
      expect(c.awaitingContinue, isFalse);
      expect(storage.isDailyRecorded(), isTrue);
    });

    test('an open offer survives an app restart', () async {
      var storage = await _storage();
      var c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
      );
      c.startGame(GameMode.daily);
      await missSix(c);
      expect(c.awaitingContinue, isTrue);

      storage = await _storage();
      c = GameController(
        words: WordRepository()..debugLoad(_words),
        storage: storage,
        coins: CoinService(storage),
        ads: _FakeAds(),
      );
      c.startGame(GameMode.daily);
      expect(c.awaitingContinue, isTrue);
      expect(c.gameOver, isFalse);
      expect(c.guesses.length, GameController.maxGuesses);
    });
  });

  group('"Keep going?" edge cases', () {
    Future<void> type(GameController c, String w) async {
      for (final ch in w.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);
    }

    GameController make(StorageService st, CoinService coins) =>
        GameController(
          words: WordRepository()..debugLoad(_words),
          storage: st,
          coins: coins,
          ads: _FakeAds(),
        );

    test('a bought row survives a restart — no paying twice', () async {
      var storage = await _storage();
      var coins = CoinService(storage);
      var c = make(storage, coins);
      c.startGame(GameMode.daily);
      final wrong = _words.firstWhere((w) => w != c.answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        await type(c, wrong);
      }
      await coins.award(CoinRules.extraGuessCost);
      await c.continueWithCoins();
      expect(coins.coins, 0);
      await Future<void>.delayed(Duration.zero);

      // App killed before the 7th guess.
      storage = await _storage();
      coins = CoinService(storage);
      c = make(storage, coins);
      c.startGame(GameMode.daily);
      expect(c.awaitingContinue, isFalse, reason: 'the row is already paid');
      expect(c.acceptingInput, isTrue);
      expect(c.maxRows, GameController.maxGuesses + 1);
    });

    test('a board abandoned at the offer is recorded as a loss later',
        () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final storage = await _storage();
      await storage.saveDailyProgress(
          guesses: List.filled(GameController.maxGuesses, 'CRANE'),
          done: false,
          now: yesterday);

      final c = make(storage, CoinService(storage));
      c.startGame(GameMode.daily);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(storage.loadStats().gamesPlayed, 1);
      expect(storage.loadStats().gamesWon, 0);
      expect(c.guesses, isEmpty, reason: "today's board is fresh");
      expect(c.acceptingInput, isTrue);
    });

    test('a win on the extra row counts in the last distribution bar',
        () async {
      final storage = await _storage();
      final s = await storage.recordDailyResult(won: true, guessesUsed: 7);
      expect(s.gamesWon, 1);
      expect(s.guessDistribution.reduce((a, b) => a + b), 1);
      expect(s.guessDistribution.last, 1);
    });
  });

  group('restore streak after midnight', () {
    test('does not pre-credit the new day', () async {
      final storage = await _storage();
      final d1 = _d(2026, 10, 10);
      final d2 = _d(2026, 10, 11);
      final d3 = _d(2026, 10, 12);
      await storage.recordDailyResult(won: true, guessesUsed: 3, now: d1);
      await storage.recordDailyResult(won: false, now: d2); // breaks it
      expect(storage.pendingRestoreStreak(), 1);
      // Sheet left open; restore tapped after midnight (d3).
      final restored = await storage.restoreStreak(now: d3);
      expect(restored.currentStreak, 1);
      // d3's real daily is still live: a loss must break the streak.
      final after = await storage.recordDailyResult(won: false, now: d3);
      expect(after.currentStreak, 0);
    });
  });

  group('migration v3 backfills the guard for existing installs', () {
    /// yyyy-mm-dd for today in UTC, matching StorageService's day key.
    String todayKey() {
      final d = DateTime.now();
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
