import 'package:flutter/material.dart';

/// A cosmetic board palette: the three letter-status colours (which drive both
/// the tiles and the keyboard keys). The neutral chrome (empty tile, borders,
/// idle keys, background) is shared across themes and lives in AppPalette.
///
/// IP note: none of these reproduce the green / yellow / gray trio of the
/// best-known word game — see the per-theme comments.
class GameTheme {
  final String id;
  final String name;

  /// Coin cost to unlock (0 = free / always unlocked).
  final int cost;

  /// Free accessibility theme (grouped separately, never costs coins).
  final bool accessibility;

  final Color correct; // right letter, right spot
  final Color present; // right letter, wrong spot
  final Color absent; // not in the word

  const GameTheme({
    required this.id,
    required this.name,
    required this.cost,
    required this.correct,
    required this.present,
    required this.absent,
    this.accessibility = false,
  });
}

/// All available board themes. Add new ones here.
class ThemeRegistry {
  ThemeRegistry._();

  /// Default brand look (teal / amber / slate). Free.
  static const cozy = GameTheme(
    id: 'cozy',
    name: 'Cozy',
    cost: 0,
    correct: Color(0xFF2A9D8F), // teal
    present: Color(0xFFE9A23B), // amber
    absent: Color(0xFF3A3F44), // slate
  );

  /// Teal-leaning green + clay orange + bark brown. NOT green/yellow/gray:
  /// present is orange (not yellow) and absent is brown (not neutral gray).
  static const forest = GameTheme(
    id: 'forest',
    name: 'Forest',
    cost: 150,
    correct: Color(0xFF2E8B74), // pine/teal green
    present: Color(0xFFC9772D), // clay orange
    absent: Color(0xFF4A4035), // bark brown
  );

  /// Warm coral + gold + plum. No green, no gray.
  static const sunset = GameTheme(
    id: 'sunset',
    name: 'Sunset',
    cost: 200,
    correct: Color(0xFFE26D5C), // coral
    present: Color(0xFFF2A65A), // gold
    absent: Color(0xFF4C3B52), // dusky plum
  );

  /// Monochrome cool-grays graded by lightness (stylistic, single-hue).
  static const mono = GameTheme(
    id: 'mono',
    name: 'Mono',
    cost: 100,
    correct: Color(0xFF6C7A89), // light slate
    present: Color(0xFF45525E), // mid slate
    absent: Color(0xFF2A323B), // dark slate
  );

  /// Accessibility: colour-blind-safe blue / orange. Free.
  static const highContrast = GameTheme(
    id: 'high_contrast',
    name: 'High contrast',
    cost: 0,
    accessibility: true,
    correct: Color(0xFF1E6FD9), // blue
    present: Color(0xFFE8730C), // orange
    absent: Color(0xFF3A3F44), // slate
  );

  static const List<GameTheme> all = [cozy, forest, sunset, mono, highContrast];

  static const GameTheme defaultTheme = cozy;

  static GameTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
}
