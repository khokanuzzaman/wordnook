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

  static Color forStatus(LetterStatus s) {
    switch (s) {
      case LetterStatus.correct:
        return correct;
      case LetterStatus.present:
        return present;
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
