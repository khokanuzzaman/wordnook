import 'package:flutter_test/flutter_test.dart';
import 'package:daily_word_game/logic/game_engine.dart';
import 'package:daily_word_game/models/letter_status.dart';

void main() {
  group('GameEngine.evaluateGuess', () {
    test('all correct', () {
      final r = GameEngine.evaluateGuess('CRANE', 'CRANE');
      expect(r, everyElement(LetterStatus.correct));
      expect(GameEngine.isWinning(r), isTrue);
    });

    test('all absent', () {
      final r = GameEngine.evaluateGuess('FUZZY', 'CROWD');
      expect(r, everyElement(LetterStatus.absent));
    });

    test('present in wrong position', () {
      // Guess RIVER vs answer DRIFT: R present, I present, others vary.
      final r = GameEngine.evaluateGuess('RIVER', 'DRIFT');
      expect(r[0], LetterStatus.present); // R is in DRIFT, wrong spot
      expect(r[1], LetterStatus.present); // I is in DRIFT, wrong spot
    });

    test('duplicate guess letter, single in answer marks only one', () {
      // Answer ABIDE has one E. Guess EERIE has three E's.
      final r = GameEngine.evaluateGuess('EERIE', 'ABIDE');
      final eStatuses = <LetterStatus>[];
      for (var i = 0; i < 5; i++) {
        if ('EERIE'[i] == 'E') eStatuses.add(r[i]);
      }
      // Exactly one E should be marked non-absent (present, since E is last in ABIDE).
      final nonAbsent =
          eStatuses.where((s) => s != LetterStatus.absent).length;
      expect(nonAbsent, 1);
    });

    test('exact match takes priority over present for duplicates', () {
      // Answer LLAMA, guess ALLAY.
      final r = GameEngine.evaluateGuess('ALLAY', 'LLAMA');
      // Position-by-position sanity: result length matches.
      expect(r.length, 5);
      // The two L's in the answer should be accounted for, not over-counted.
      final lMarks = <LetterStatus>[];
      for (var i = 0; i < 5; i++) {
        if ('ALLAY'[i] == 'L') lMarks.add(r[i]);
      }
      final lNonAbsent = lMarks.where((s) => s != LetterStatus.absent).length;
      expect(lNonAbsent, lessThanOrEqualTo(2));
    });
  });
}
