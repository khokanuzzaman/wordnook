/// Pure bucketing helpers for analytics USER PROPERTIES. Raw counts are never
/// sent as user properties (too high-cardinality, and a churn-risk for a tiny
/// user base); we send coarse buckets instead. Free of Flutter/Firebase imports
/// so the boundaries can be unit-tested in isolation.
class AnalyticsBuckets {
  const AnalyticsBuckets._();

  /// Current daily streak → "0", "1-3", "4-7", "8-30", "31+".
  static String streak(int streak) {
    if (streak <= 0) return '0';
    if (streak <= 3) return '1-3';
    if (streak <= 7) return '4-7';
    if (streak <= 30) return '8-30';
    return '31+';
  }

  /// Journey level reached → "1-10", "11-50", "51-100", "100+".
  static String journey(int level) {
    if (level <= 10) return '1-10';
    if (level <= 50) return '11-50';
    if (level <= 100) return '51-100';
    return '100+';
  }

  /// Total games played → "1", "2-5", "6-20", "21+". (0 also maps to "1" is
  /// avoided: a never-played user reports "0".)
  static String played(int gamesPlayed) {
    if (gamesPlayed <= 0) return '0';
    if (gamesPlayed == 1) return '1';
    if (gamesPlayed <= 5) return '2-5';
    if (gamesPlayed <= 20) return '6-20';
    return '21+';
  }
}
