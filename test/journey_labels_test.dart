import 'package:flutter_test/flutter_test.dart';

import 'package:daily_word_game/logic/journey_labels.dart';

void main() {
  group('levelsClearedLabel', () {
    test('zero reads as a fresh start', () {
      expect(levelsClearedLabel(0), 'No levels cleared yet');
    });

    test('one is singular', () {
      expect(levelsClearedLabel(1), '1 level cleared');
    });

    test('several are plural', () {
      expect(levelsClearedLabel(5), '5 levels cleared');
    });

    test('a negative count never leaks into the text', () {
      expect(levelsClearedLabel(-1), 'No levels cleared yet');
    });
  });
}
