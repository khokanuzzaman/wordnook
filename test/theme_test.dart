import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_word_game/models/letter_status.dart';
import 'package:daily_word_game/services/coin_service.dart';
import 'package:daily_word_game/services/storage_service.dart';
import 'package:daily_word_game/services/theme_service.dart';
import 'package:daily_word_game/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPalette.forStatus follows the selected theme', () {
    tearDown(() => AppPalette.selectedTheme.value = ThemeRegistry.cozy);

    test('status colours come from the active theme', () {
      AppPalette.selectedTheme.value = ThemeRegistry.sunset;
      expect(AppPalette.forStatus(LetterStatus.correct),
          ThemeRegistry.sunset.correct);
      expect(AppPalette.forStatus(LetterStatus.present),
          ThemeRegistry.sunset.present);
      expect(AppPalette.forStatus(LetterStatus.absent),
          ThemeRegistry.sunset.absent);

      AppPalette.selectedTheme.value = ThemeRegistry.cozy;
      expect(AppPalette.forStatus(LetterStatus.correct),
          ThemeRegistry.cozy.correct);
    });
  });

  group('ThemeService', () {
    late StorageService storage;
    late CoinService coins;
    late ThemeService themes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      coins = CoinService(storage);
      themes = ThemeService(storage, coins);
      AppPalette.selectedTheme.value = ThemeRegistry.cozy;
    });
    tearDown(() => AppPalette.selectedTheme.value = ThemeRegistry.cozy);

    test('defaults: cozy selected; free themes unlocked, paid locked', () {
      expect(themes.selectedId, 'cozy');
      expect(themes.isUnlocked(ThemeRegistry.cozy), isTrue);
      expect(themes.isUnlocked(ThemeRegistry.highContrast), isTrue); // free a11y
      expect(themes.isUnlocked(ThemeRegistry.forest), isFalse); // paid
    });

    test('unlock fails without enough coins and changes nothing', () async {
      final ok = await themes.unlock('forest');
      expect(ok, isFalse);
      expect(themes.isUnlocked(ThemeRegistry.forest), isFalse);
      expect(themes.selectedId, 'cozy');
      expect(AppPalette.selectedTheme.value.id, 'cozy');
    });

    test('unlock spends coins, persists, selects, and applies the palette',
        () async {
      await coins.award(500);
      final ok = await themes.unlock('forest');
      expect(ok, isTrue);
      expect(coins.coins, 500 - ThemeRegistry.forest.cost);
      expect(themes.isUnlocked(ThemeRegistry.forest), isTrue);
      expect(themes.selectedId, 'forest');
      expect(AppPalette.selectedTheme.value.id, 'forest');
      // persisted
      expect(storage.unlockedThemes.contains('forest'), isTrue);
      expect(storage.selectedThemeId, 'forest');
    });

    test('free accessibility theme can be selected without coins', () async {
      await themes.select('high_contrast');
      expect(themes.selectedId, 'high_contrast');
      expect(AppPalette.selectedTheme.value.id, 'high_contrast');
    });

    test('applySelected restores the persisted theme on a fresh service',
        () async {
      await coins.award(200);
      await themes.unlock('mono');
      // Simulate a relaunch: reset the live palette, rebuild the service.
      AppPalette.selectedTheme.value = ThemeRegistry.cozy;
      ThemeService(storage, coins).applySelected();
      expect(AppPalette.selectedTheme.value.id, 'mono');
    });
  });

  test('no theme reproduces the green/yellow/gray trade dress', () {
    // Guard: no theme should pair a green correct with a yellow present.
    bool isGreen(int v) {
      final c = v & 0xFFFFFF;
      final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
      return g > r + 30 && g > b + 30;
    }

    bool isYellow(int v) {
      final c = v & 0xFFFFFF;
      final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
      return r > 150 && g > 150 && b < 100;
    }

    for (final t in ThemeRegistry.all) {
      final greenCorrect = isGreen(t.correct.toARGB32());
      final yellowPresent = isYellow(t.present.toARGB32());
      expect(greenCorrect && yellowPresent, isFalse,
          reason: '${t.name} looks like the green/yellow trade dress');
    }
  });
}
