import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the shipped word-list assets. These read the files directly from disk
/// (not via rootBundle) so they validate exactly what we commit.
void main() {
  final answersFile = File('assets/words/answers.txt');
  final allowedFile = File('assets/words/allowed.txt');

  final fiveLetters = RegExp(r'^[A-Z]{5}$');

  List<String> readWords(File f) => f
      .readAsLinesSync()
      .map((l) => l.trim().toUpperCase())
      .where((l) => l.isNotEmpty)
      .toList();

  test('answers.txt entries are all uppercase 5-letter words', () {
    final answers = readWords(answersFile);
    expect(answers, isNotEmpty);
    for (final w in answers) {
      expect(fiveLetters.hasMatch(w), isTrue,
          reason: '"$w" is not 5 letters A-Z');
    }
  });

  test('allowed.txt entries are all uppercase 5-letter words', () {
    final allowed = readWords(allowedFile);
    expect(allowed, isNotEmpty);
    for (final w in allowed) {
      expect(fiveLetters.hasMatch(w), isTrue,
          reason: '"$w" is not 5 letters A-Z');
    }
  });

  test('no duplicate answers', () {
    final answers = readWords(answersFile);
    expect(answers.length, answers.toSet().length);
  });

  test('every answer is a valid guess (subset of allowed)', () {
    final answers = readWords(answersFile).toSet();
    final allowed = readWords(allowedFile).toSet();
    final missing = answers.difference(allowed);
    expect(missing, isEmpty, reason: 'answers missing from allowed: $missing');
  });

  test('answer pool is large enough for daily play', () {
    // A healthy daily game should not repeat words for a long time.
    expect(readWords(answersFile).length, greaterThanOrEqualTo(365));
  });
}
