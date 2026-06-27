import 'package:flutter/material.dart';
import '../models/letter_status.dart';
import 'game_theme.dart';

export 'game_theme.dart';

/// App palette. The three status colours come from the active [selectedTheme]
/// (a cosmetic, unlockable palette); the neutral chrome below is shared by all
/// themes. Intentionally NOT the green/yellow/gray of the best-known word game.
class AppPalette {
  static const Color background = Color(0xFF14181B);
  static const Color surface = Color(0xFF1B2126);

  // Cozy brand accents used by non-board chrome (labels, stat bars). Kept const
  // so they stay consistent regardless of the player's chosen board theme.
  static const Color correct = Color(0xFF2A9D8F); // teal
  static const Color present = Color(0xFFE9A23B); // amber
  static const Color absent = Color(0xFF3A3F44); // slate

  // Shared neutral chrome for the board (same across all themes).
  static const Color empty = Color(0xFF20262B);
  static const Color border = Color(0xFF333B41);
  static const Color keyIdle = Color(0xFF2C343A);

  /// The active board theme. Tiles/keyboard rebuild when this changes (it's
  /// merged into the game screen's listeners).
  static final ValueNotifier<GameTheme> selectedTheme =
      ValueNotifier<GameTheme>(ThemeRegistry.defaultTheme);

  /// Status colour for a tile/key, from the active theme (empty uses chrome).
  static Color forStatus(LetterStatus s) {
    final t = selectedTheme.value;
    switch (s) {
      case LetterStatus.correct:
        return t.correct;
      case LetterStatus.present:
        return t.present;
      case LetterStatus.absent:
        return t.absent;
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
