import 'package:flutter_test/flutter_test.dart';
import 'package:daily_word_game/logic/share_formatter.dart';

void main() {
  group('ShareFormatter', () {
    test('uses our own circle emojis, not Wordle squares', () {
      final text = ShareFormatter.build(
        appName: 'Daily Word',
        dayNumber: 42,
        guesses: const ['CRANE', 'STONE'],
        answer: 'STONE',
        won: true,
        maxGuesses: 6,
      );
      // Header
      expect(text, startsWith('Daily Word #42 2/6'));
      // Final row is all-correct.
      expect(text, contains('🔵🔵🔵🔵🔵'));
      // Must not contain the green/yellow/black square trade dress.
      for (final wordleGlyph in ['🟩', '🟨', '⬛', '⬜']) {
        expect(text.contains(wordleGlyph), isFalse,
            reason: 'should not reproduce Wordle squares ($wordleGlyph)');
      }
    });

    test('CRANE vs STONE maps positions correctly', () {
      // answer STONE: C(absent) R(absent) A(absent) N(correct) E(correct)
      final text = ShareFormatter.build(
        appName: 'X',
        dayNumber: 1,
        guesses: const ['CRANE'],
        answer: 'STONE',
        won: false,
        maxGuesses: 6,
      );
      expect(text, endsWith('⚪⚪⚪🔵🔵'));
    });

    test('present (right letter, wrong spot) maps to the amber circle', () {
      // answer STONE, guess OPENS:
      // O(present) P(absent) E(present) N(correct) S(present)
      final text = ShareFormatter.build(
        appName: 'X',
        dayNumber: 1,
        guesses: const ['OPENS'],
        answer: 'STONE',
        won: false,
        maxGuesses: 6,
      );
      expect(text, endsWith('🟠⚪🟠🔵🟠'));
    });

    test('loss shows X/6 score', () {
      final text = ShareFormatter.build(
        appName: 'X',
        dayNumber: 7,
        guesses: const ['CRANE', 'SLATE', 'PLATE', 'BRACE', 'GRACE', 'TRACE'],
        answer: 'STONE',
        won: false,
        maxGuesses: 6,
      );
      expect(text, startsWith('X #7 X/6'));
    });

    test('journey mode omits the day number', () {
      final text = ShareFormatter.build(
        appName: 'X',
        dayNumber: null,
        guesses: const ['STONE'],
        answer: 'STONE',
        won: true,
        maxGuesses: 6,
      );
      expect(text, startsWith('X Journey 1/6'));
    });
  });

  test('a win on a bought extra row reads 6+1/6', () {
    final text = ShareFormatter.build(
      appName: 'Wordnook',
      dayNumber: 650,
      guesses: const ['SLATE', 'SLATE', 'SLATE', 'SLATE', 'SLATE', 'SLATE',
          'CRANE'],
      answer: 'CRANE',
      won: true,
      maxGuesses: 6,
    );
    expect(text.split('\n').first, 'Wordnook #650 6+1/6');
  });

  group('streak + link', () {
    String build({int? streak, String? link}) => ShareFormatter.build(
          appName: 'Wordnook',
          dayNumber: 650,
          guesses: const ['SLATE', 'CRANE'],
          answer: 'CRANE',
          won: true,
          maxGuesses: 6,
          streak: streak,
          link: link,
        );

    test('a streak of 2+ rides on the header', () {
      expect(build(streak: 5).split('\n').first, 'Wordnook #650 2/6 🔥5');
    });

    test('a streak under 2 is left off', () {
      expect(build(streak: 1).split('\n').first, 'Wordnook #650 2/6');
      expect(build().split('\n').first, 'Wordnook #650 2/6');
    });

    test('the link is the last line', () {
      final text = build(link: 'https://example.com/app');
      expect(text.split('\n').last, 'Play: https://example.com/app');
      expect(text, contains('🔵🔵🔵🔵🔵'));
    });

    test('no link, no footer', () {
      expect(build().contains('Play:'), isFalse);
    });
  });
}
