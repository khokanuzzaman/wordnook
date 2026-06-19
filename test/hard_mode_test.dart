import 'package:flutter_test/flutter_test.dart';
import 'package:daily_word_game/logic/game_engine.dart';

void main() {
  group('GameEngine.hardModeViolation', () {
    const answer = 'CRANE';

    test('no previous guesses => always allowed', () {
      expect(GameEngine.hardModeViolation('PLUMB', const [], answer), isNull);
    });

    test('a correct (green) letter must be kept in place', () {
      // TRACE vs CRANE: R(1) A(2) E(4) are correct.
      final v = GameEngine.hardModeViolation('CHOSE', ['TRACE'], answer);
      expect(v, '2nd letter must be R');
    });

    test('a present (amber) letter must be reused somewhere', () {
      // SAUCE vs CRANE: A and C are present; E is correct.
      final v = GameEngine.hardModeViolation('PRIZE', ['SAUCE'], answer);
      expect(v, contains('A'));
    });

    test('a guess that respects all revealed hints is allowed', () {
      expect(GameEngine.hardModeViolation('CRANE', ['TRACE'], answer), isNull);
      expect(GameEngine.hardModeViolation('PLACE', ['SAUCE'], answer), isNull);
    });

    test('missing a known present letter is rejected', () {
      // TRACE reveals C is present; BRAKE keeps the greens but drops C.
      final v = GameEngine.hardModeViolation('BRAKE', ['TRACE'], answer);
      expect(v, 'Guess must contain C');
    });
  });
}
