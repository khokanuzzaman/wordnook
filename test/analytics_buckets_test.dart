import 'package:flutter_test/flutter_test.dart';

import 'package:daily_word_game/logic/analytics_buckets.dart';

void main() {
  group('AnalyticsBuckets.streak', () {
    test('boundaries', () {
      expect(AnalyticsBuckets.streak(-3), '0');
      expect(AnalyticsBuckets.streak(0), '0');
      expect(AnalyticsBuckets.streak(1), '1-3');
      expect(AnalyticsBuckets.streak(3), '1-3');
      expect(AnalyticsBuckets.streak(4), '4-7');
      expect(AnalyticsBuckets.streak(7), '4-7');
      expect(AnalyticsBuckets.streak(8), '8-30');
      expect(AnalyticsBuckets.streak(30), '8-30');
      expect(AnalyticsBuckets.streak(31), '31+');
      expect(AnalyticsBuckets.streak(999), '31+');
    });
  });

  group('AnalyticsBuckets.journey', () {
    test('boundaries', () {
      expect(AnalyticsBuckets.journey(1), '1-10');
      expect(AnalyticsBuckets.journey(10), '1-10');
      expect(AnalyticsBuckets.journey(11), '11-50');
      expect(AnalyticsBuckets.journey(50), '11-50');
      expect(AnalyticsBuckets.journey(51), '51-100');
      expect(AnalyticsBuckets.journey(100), '51-100');
      expect(AnalyticsBuckets.journey(101), '100+');
      expect(AnalyticsBuckets.journey(5000), '100+');
    });
  });

  group('AnalyticsBuckets.played', () {
    test('boundaries', () {
      expect(AnalyticsBuckets.played(0), '0');
      expect(AnalyticsBuckets.played(1), '1');
      expect(AnalyticsBuckets.played(2), '2-5');
      expect(AnalyticsBuckets.played(5), '2-5');
      expect(AnalyticsBuckets.played(6), '6-20');
      expect(AnalyticsBuckets.played(20), '6-20');
      expect(AnalyticsBuckets.played(21), '21+');
      expect(AnalyticsBuckets.played(100), '21+');
    });
  });
}
