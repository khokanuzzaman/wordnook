import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
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

String _todayKey() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Stats JSON for a player mid-streak, so we can prove migration preserves it.
const _statsJson =
    '{"gamesPlayed":7,"gamesWon":6,"currentStreak":4,"bestStreak":9,'
    '"guessDistribution":[0,0,1,2,3,0,0]}';

/// Simulates an install created BEFORE the daily remap: a finished board whose
/// guesses were played against the old word, and no schema version.
void _seedPreRemapInstall({required bool wonToday}) {
  final today = _todayKey();
  SharedPreferences.setMockInitialValues({
    'flutter.daily_date': today,
    'flutter.daily_done': true,
    'flutter.daily_guesses': 'CRANE,SLATE,BRINE',
    if (wonToday) 'flutter.last_won_date': today,
    'flutter.stats_v1': _statsJson,
    'flutter.coins': 250,
    'flutter.unlocked_themes': 'forest,mono',
    'flutter.selected_theme': 'forest',
    'flutter.journey_level': 12,
    'flutter.hard_mode': true,
    'flutter.reminder_enabled': false,
  });
}

Future<GameController> _controller(StorageService storage) async {
  return GameController(
    words: WordRepository()..debugLoad(_words),
    storage: storage,
    coins: CoinService(storage),
    ads: _FakeAds(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the daily outcome is stored, not inferred', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a win is persisted and restored across a rebuild', () async {
      var storage = StorageService();
      await storage.init();
      var c = await _controller(storage);
      c.startGame(GameMode.daily);

      for (final ch in c.answer.split('')) {
        c.onKey(ch);
      }
      c.onKey('ENTER');
      await Future<void>.delayed(Duration.zero);
      expect(c.won, isTrue);

      // Relaunch.
      storage = StorageService();
      await storage.init();
      c = await _controller(storage);
      c.startGame(GameMode.daily);
      expect(c.gameOver, isTrue);
      expect(c.won, isTrue, reason: 'the win must survive a restart');
    });

    test('a loss is persisted and restored across a rebuild', () async {
      var storage = StorageService();
      await storage.init();
      var c = await _controller(storage);
      c.startGame(GameMode.daily);

      final wrong = _words.firstWhere((w) => w != c.answer);
      for (var i = 0; i < GameController.maxGuesses; i++) {
        for (final ch in wrong.split('')) {
          c.onKey(ch);
        }
        c.onKey('ENTER');
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.awaitingContinue, isTrue);
      await c.declineContinue();
      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);

      storage = StorageService();
      await storage.init();
      c = await _controller(storage);
      c.startGame(GameMode.daily);
      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);
    });

    test('the outcome survives even when the board itself is gone', () async {
      final storage = StorageService();
      await storage.init();
      await storage.saveDailyProgress(guesses: const ['CRANE'], done: true);
      await storage.saveDailyOutcome(won: true);
      // The old inference (saved.last == answer) would report a LOSS here.
      expect(storage.isDailyWon(), isTrue);
    });
  });

  group('migration renders the correct outcome for a pre-remap board', () {
    test('a device that WON today shows a won board, not a loss', () async {
      _seedPreRemapInstall(wonToday: true);
      final storage = StorageService();
      await storage.init();

      final c = await _controller(storage);
      c.startGame(GameMode.daily);

      expect(c.gameOver, isTrue, reason: 'today stays locked');
      expect(c.won, isTrue,
          reason: 'last_won_date == today, so the day was won');
      expect(c.guesses, isEmpty, reason: 'stale pre-remap guesses are dropped');
    });

    test('a device that LOST today shows a loss', () async {
      _seedPreRemapInstall(wonToday: false);
      final storage = StorageService();
      await storage.init();

      final c = await _controller(storage);
      c.startGame(GameMode.daily);

      expect(c.gameOver, isTrue);
      expect(c.won, isFalse);
    });

    test('stats, streak, coins, themes and journey level survive migration',
        () async {
      _seedPreRemapInstall(wonToday: true);
      final storage = StorageService();
      await storage.init();

      final s = storage.loadStats();
      expect(s.gamesPlayed, 7);
      expect(s.gamesWon, 6);
      expect(s.currentStreak, 4);
      expect(s.bestStreak, 9);
      expect(s.guessDistribution, [0, 0, 1, 2, 3, 0, 0]);

      expect(storage.coins, 250);
      expect(storage.unlockedThemes, {'forest', 'mono'});
      expect(storage.selectedThemeId, 'forest');
      expect(storage.journeyLevel, 12);
      expect(storage.hardMode, isTrue);
      expect(storage.reminderEnabled, isFalse);
    });

    test('a migrated finished day cannot be re-recorded', () async {
      _seedPreRemapInstall(wonToday: true);
      final storage = StorageService();
      await storage.init();
      final before = storage.loadStats();

      await storage.recordDailyResult(won: false);

      final after = storage.loadStats();
      expect(after.currentStreak, before.currentStreak);
      expect(after.gamesPlayed, before.gamesPlayed);
    });
  });
}
