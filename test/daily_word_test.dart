import 'package:flutter_test/flutter_test.dart';

import 'package:daily_word_game/data/word_repository.dart';

/// A sorted, alphabetical answer list — the shape of the real answers.txt, so
/// "consecutive days walk the alphabet" would reproduce the original bug.
List<String> _sortedAnswers(int n) =>
    List.generate(n, (i) => 'W${i.toString().padLeft(4, '0')}')..sort();

WordRepository _repo(List<String> answers) =>
    WordRepository()..debugLoad(answers);

DateTime _day(int offsetFromEpoch) =>
    DateTime.utc(2025, 1, 1).add(Duration(days: offsetFromEpoch));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dailyWord determinism', () {
    test('same date gives the same word across calls and fresh instances', () {
      final answers = _sortedAnswers(500);
      final date = DateTime.utc(2026, 7, 24);

      final a = _repo(answers);
      final first = a.dailyWord(date);
      // Repeated calls on the same instance.
      expect(a.dailyWord(date), first);
      expect(a.dailyWord(date), first);
      // A completely fresh instance (simulates relaunch / another device).
      expect(_repo(answers).dailyWord(date), first);
      expect(_repo(answers).dailyWord(date), first);
    });

    test('time of day does not matter — only the UTC calendar date', () {
      final repo = _repo(_sortedAnswers(500));
      final morning = DateTime.utc(2026, 7, 24, 0, 5);
      final night = DateTime.utc(2026, 7, 24, 23, 55);
      expect(repo.dailyWord(morning), repo.dailyWord(night));
    });
  });

  group('consecutive days are not alphabetically adjacent', () {
    test('no two consecutive days sit next to each other in the sorted list',
        () {
      final answers = _sortedAnswers(500);
      final repo = _repo(answers);

      var totalGap = 0;
      var adjacentPairs = 0;
      var forwardSteps = 0; // the exact shape of the original bug: +1 each day
      const sample = 120;
      for (var d = 0; d < sample; d++) {
        final i = answers.indexOf(repo.dailyWord(_day(d)));
        final j = answers.indexOf(repo.dailyWord(_day(d + 1)));
        if (j - i == 1) forwardSteps++;
        if ((i - j).abs() == 1) adjacentPairs++;
        totalGap += (i - j).abs();
      }

      // The original bug stepped forward exactly one slot EVERY day.
      expect(forwardSteps, lessThan(3),
          reason: '$forwardSteps/$sample days stepped +1 alphabetically — '
              'that is the sorted-walk bug');

      // A real shuffle may occasionally land on a neighbour by chance; that is
      // harmless. It must just not be the rule.
      expect(adjacentPairs, lessThan(sample * 0.05),
          reason: '$adjacentPairs/$sample consecutive days were alphabetically '
              'adjacent — too many to be chance');

      // On a shuffled permutation the average gap is a large fraction of the
      // list length (~n/3 for a random pair); the sorted walk would give 1.
      final meanGap = totalGap / sample;
      expect(meanGap, greaterThan(answers.length / 8),
          reason: 'mean alphabetical gap $meanGap looks too sequential');
    });
  });

  group('the daily order is a true bijection', () {
    test('over answers.length days every answer appears exactly once', () {
      final answers = _sortedAnswers(300);
      final repo = _repo(answers);

      final seen = <String>[];
      for (var d = 0; d < answers.length; d++) {
        seen.add(repo.dailyWord(_day(d)));
      }

      expect(seen.length, answers.length);
      expect(seen.toSet().length, answers.length,
          reason: 'a word repeated within one full period');
      expect(seen.toSet(), answers.toSet(),
          reason: 'some answers never appear (gaps in the permutation)');
    });

    test('the cycle repeats after a full period', () {
      final answers = _sortedAnswers(300);
      final repo = _repo(answers);
      expect(repo.dailyWord(_day(answers.length)), repo.dailyWord(_day(0)));
      expect(repo.dailyWord(_day(answers.length + 7)), repo.dailyWord(_day(7)));
    });
  });

  group('dailyNumber is unchanged by the remap', () {
    test('epoch is puzzle 1 and it increments by one per day', () {
      final repo = _repo(_sortedAnswers(500));
      expect(repo.dailyNumber(_day(0)), 1);
      expect(repo.dailyNumber(_day(1)), 2);
      expect(repo.dailyNumber(_day(100)), 101);
      // A fixed real-world date keeps its published puzzle number.
      expect(repo.dailyNumber(DateTime.utc(2026, 7, 24)),
          DateTime.utc(2026, 7, 24).difference(DateTime.utc(2025, 1, 1)).inDays +
              1);
    });

    test('puzzle number does not depend on the answer-list length', () {
      expect(_repo(_sortedAnswers(50)).dailyNumber(_day(400)),
          _repo(_sortedAnswers(900)).dailyNumber(_day(400)));
    });
  });

  group('daily and journey walk different orders', () {
    test('the two seeds produce different sequences', () {
      final answers = _sortedAnswers(300);
      final repo = _repo(answers);
      // Compare the first N daily words against the first N journey levels.
      final daily = [for (var d = 0; d < 30; d++) repo.dailyWord(_day(d))];
      final journey = [for (var l = 1; l <= 30; l++) repo.wordForLevel(l)];
      expect(daily, isNot(equals(journey)));
    });
  });
}
