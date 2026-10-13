import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/data/word_repository.dart';
import 'package:daily_word_game/logic/journey_ramp.dart';
import 'package:daily_word_game/logic/tips.dart';
import 'package:daily_word_game/services/storage_service.dart';

List<String> _read(String path) => File(path)
    .readAsLinesSync()
    .map((l) => l.trim().toUpperCase())
    .where((l) => l.isNotEmpty)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final answers = _read('assets/words/answers.txt');
  final easy = _read('assets/words/answers_easy.txt');
  final medium = _read('assets/words/answers_medium.txt');
  final hard = _read('assets/words/answers_hard.txt');
  final allowed = _read('assets/words/allowed.txt').toSet();

  WordRepository tiered() => WordRepository()
    ..debugLoad(answers, tiers: {
      WordTier.easy: easy,
      WordTier.medium: medium,
      WordTier.hard: hard,
    });

  group('tier files', () {
    test('together they are exactly answers.txt, with no overlap', () {
      final all = [...easy, ...medium, ...hard];
      expect(all.length, answers.length, reason: 'no word in two tiers');
      expect(all.toSet(), answers.toSet());
    });

    test('every tier word is a valid guess', () {
      for (final w in [...easy, ...medium, ...hard]) {
        expect(allowed, contains(w));
      }
    });

    test('easy holds everyday words, not obscure ones', () {
      for (final w in ['HOUSE', 'WATER', 'HAPPY', 'SMILE', 'BREAD']) {
        expect(easy, contains(w));
      }
      for (final w in ['QUALM', 'WRACK', 'IMBUE', 'TWIXT']) {
        expect(easy, isNot(contains(w)));
      }
      expect(easy.length, inInclusiveRange(350, 550));
    });
  });

  group('JourneyRamp.tierFor', () {
    test('levels 1–10 are all easy', () {
      for (var l = 1; l <= 10; l++) {
        expect(JourneyRamp.tierFor(l), WordTier.easy);
      }
    });

    test('11–30 mostly easy with some medium, never hard', () {
      final tiers = [for (var l = 11; l <= 30; l++) JourneyRamp.tierFor(l)];
      expect(tiers, isNot(contains(WordTier.hard)));
      expect(tiers.where((t) => t == WordTier.medium), isNotEmpty);
      expect(tiers.where((t) => t == WordTier.easy).length,
          greaterThan(tiers.length ~/ 2));
    });

    test('31–60 mostly medium with some hard, never easy', () {
      final tiers = [for (var l = 31; l <= 60; l++) JourneyRamp.tierFor(l)];
      expect(tiers, isNot(contains(WordTier.easy)));
      expect(tiers.where((t) => t == WordTier.hard), isNotEmpty);
      expect(tiers.where((t) => t == WordTier.medium).length,
          greaterThan(tiers.length ~/ 2));
    });

    test('61+ uses all three tiers', () {
      final tiers = {for (var l = 61; l <= 70; l++) JourneyRamp.tierFor(l)};
      expect(tiers, WordTier.values.toSet());
    });

    test('a level below 1 is treated as level 1', () {
      expect(JourneyRamp.tierFor(0), WordTier.easy);
      expect(JourneyRamp.occurrenceIndex(-3), 0);
    });
  });

  group('JourneyRamp.indexFor', () {
    test('a retry never returns the canonical index', () {
      for (var level = 1; level <= 80; level++) {
        final base = JourneyRamp.indexFor(level, 7);
        for (var attempt = 1; attempt <= 5; attempt++) {
          expect(JourneyRamp.indexFor(level, 7, attempt: attempt),
              isNot(base));
        }
      }
    });

    test('stays in range for any length', () {
      for (final len in [1, 2, 3, 459]) {
        for (var level = 1; level <= 200; level++) {
          final i = JourneyRamp.indexFor(level, len, attempt: level % 3);
          expect(i, inInclusiveRange(0, len - 1));
        }
      }
    });
  });

  group('journey words with the real tiers', () {
    test('levels 1–10 come from the easy tier', () {
      final repo = tiered();
      for (var l = 1; l <= 10; l++) {
        expect(easy, contains(repo.journeyWord(l)), reason: 'level $l');
      }
    });

    test('each level draws from its ramp tier', () {
      final repo = tiered();
      final byTier = {
        WordTier.easy: easy.toSet(),
        WordTier.medium: medium.toSet(),
        WordTier.hard: hard.toSet(),
      };
      for (var l = 1; l <= 120; l++) {
        expect(byTier[JourneyRamp.tierFor(l)], contains(repo.journeyWord(l)),
            reason: 'level $l');
      }
    });

    test('no word repeats in the first 500 levels', () {
      final repo = tiered();
      final words = [for (var l = 1; l <= 500; l++) repo.journeyWord(l)];
      expect(words.toSet().length, words.length);
    });

    test('deterministic across instances', () {
      final a = tiered();
      final b = tiered();
      for (var l = 1; l <= 50; l++) {
        expect(a.journeyWord(l), b.journeyWord(l));
        expect(a.journeyWord(l, attempt: 2), b.journeyWord(l, attempt: 2));
      }
    });

    test('a retry gives a different word from the same tier', () {
      final repo = tiered();
      final easySet = easy.toSet();
      for (var l = 1; l <= 10; l++) {
        final first = repo.journeyWord(l);
        final retry = repo.journeyWord(l, attempt: 1);
        expect(retry, isNot(first));
        expect(easySet, contains(retry));
      }
    });

    test('without tier data, journey still works from all answers', () {
      final repo = WordRepository()..debugLoad(['CRANE', 'SLATE', 'BRINE']);
      for (var l = 1; l <= 20; l++) {
        expect(['CRANE', 'SLATE', 'BRINE'], contains(repo.journeyWord(l)));
      }
    });
  });

  group('the Daily did NOT change', () {
    // Pinned from the shipped build: the daily walks a fixed shuffle of
    // answers.txt, which tiers must never affect.
    const pins = {
      '2025-01-01': 'GRADE',
      '2026-01-01': 'STEAL',
      '2026-10-13': 'SPELL',
      '2027-06-30': 'PLAZA',
    };

    for (final withTiers in [false, true]) {
      test('known dates map to known words (tiers loaded: $withTiers)', () {
        final repo = withTiers
            ? tiered()
            : (WordRepository()..debugLoad(answers));
        pins.forEach((date, word) {
          expect(repo.dailyWord(DateTime.parse('${date}T12:00:00Z')), word,
              reason: date);
        });
      });
    }
  });

  group('v7 migration', () {
    test('an upgrading player skips the beginner tips; a fresh install does not',
        () async {
      SharedPreferences.setMockInitialValues({
        'flutter.daily_map_version': 6,
        'flutter.onboarding_seen': true,
        'flutter.stats_v1': '{"gamesPlayed":12,"gamesWon":10,'
            '"currentStreak":3,"bestStreak":5,'
            '"guessDistribution":[0,0,2,4,3,1,0]}',
      });
      var s = StorageService();
      await s.init();
      expect(s.gamesFinished, StorageService.tipsWindowGames);

      SharedPreferences.setMockInitialValues({});
      s = StorageService();
      await s.init();
      expect(s.gamesFinished, 0);
    });

    test('the storage tips window matches TipRules', () {
      expect(StorageService.tipsWindowGames, TipRules.eligibleGames);
    });

    test('drops a journey hint, keeps a daily hint', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.daily_map_version': 6,
        'flutter.hint_scope': 'j:3:0',
        'flutter.hint_reveals': '0:Q',
      });
      var s = StorageService();
      await s.init();
      expect(s.loadHints('j:3:0'), isEmpty);

      SharedPreferences.setMockInitialValues({
        'flutter.daily_map_version': 6,
        'flutter.hint_scope': 'd:2026-10-13',
        'flutter.hint_reveals': '0:S',
      });
      s = StorageService();
      await s.init();
      expect(s.loadHints('d:2026-10-13'), {0: 'S'});
    });
  });
}
