import 'package:flutter/material.dart';
import '../models/letter_status.dart';

/// App palette. Intentionally NOT Wordle's green/yellow/gray — this is our own
/// brand look (teal / amber / slate) to avoid copying their trade dress.
class AppPalette {
  static const Color background = Color(0xFF14181B);
  static const Color surface = Color(0xFF1B2126);

  static const Color correct = Color(0xFF2A9D8F); // teal
  static const Color present = Color(0xFFE9A23B); // amber
  static const Color absent = Color(0xFF3A3F44); // slate
  static const Color empty = Color(0xFF20262B);
  static const Color border = Color(0xFF333B41);
  static const Color keyIdle = Color(0xFF2C343A);

  // Colour-blind-safe alternates (blue / orange — high luminance contrast and
  // distinguishable under deuteranopia/protanopia, unlike a teal/amber pair).
  static const Color correctHC = Color(0xFF1E6FD9); // blue
  static const Color presentHC = Color(0xFFE8730C); // orange

  /// Toggles the high-contrast palette app-wide. Tiles/keyboard rebuild when
  /// this changes (it's merged into the game screen's listeners).
  static final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  static Color forStatus(LetterStatus s) {
    final hc = highContrast.value;
    switch (s) {
      case LetterStatus.correct:
        return hc ? correctHC : correct;
      case LetterStatus.present:
        return hc ? presentHC : present;
      case LetterStatus.absent:
        return absent;
      case LetterStatus.empty:
        return empty;
    }
  }
}

ThemeData buildTheme() {
  return ThemeData.dark(useMaterial3: true).copyWith(
    scaffoldBackgroundColor: AppPalette.background,
    appBarTheme: const AppBarTheme(backgroundColor: AppPalette.surface),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.correct,
      brightness: Brightness.dark,
    ),
  );
}
