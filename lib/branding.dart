/// Single source of truth for the app's brand name and store-facing copy.
///
/// Must NOT be "Wordle" or any confusingly similar name — see CLAUDE.md.
class Branding {
  static const String appName = 'Wordnook';
  static const String appTagline = 'A fresh 5-letter puzzle every day.';

  /// User-facing version string shown on the About screen. Keep in sync with
  /// the `version:` name in pubspec.yaml (no runtime package-info dependency).
  static const String version

  /// Longer About-screen description of the app's calm, cozy positioning.
  static const String appDescription =
      'A cozy daily word puzzle. One warm little word a day — no timers, no '
      'scores, just a quiet moment to think.';

  /// Store link appended to shared results so a share can become an install.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.khokan.dailyword';
}
