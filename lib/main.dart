import 'dart:async';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/word_repository.dart';
import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/coin_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/game_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  // Apply the saved board theme before the first frame.
  AppPalette.selectedTheme.value = ThemeRegistry.byId(storage.selectedThemeId);

  final words = WordRepository();
  await words.load();

  // Ads init is fire-and-forget so it doesn't block first paint.
  // Comment this out if running on a platform without AdMob configured yet.
  unawaited(AdsService.instance.init());

  // Analytics init is likewise off the critical path. Once it's ready, seed the
  // bucketed user properties from current state so segments are populated even
  // for a session with no further events.
  unawaited(AnalyticsService.init().then((_) {
    final stats = storage.loadStats();
    AnalyticsService.instance
      ..syncStreak(stats.currentStreak)
      ..syncPlayed(stats.gamesPlayed)
      ..syncJourney(storage.journeyLevel)
      ..syncReminder(storage.reminderEnabled)
      ..syncTheme(storage.selectedThemeId);
  }));

  // Schedule (or refresh) the once-a-day reminder per the user's preference,
  // off the critical path so it never blocks first paint.
  unawaited(_setUpDailyReminder(storage));

  final coins = CoinService(storage);
  final controller =
      GameController(words: words, storage: storage, coins: coins);

  runApp(WordGameApp(controller: controller));
}

Future<void> _setUpDailyReminder(StorageService storage) async {
  await NotificationService.instance.init();
  if (storage.reminderEnabled) {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleDailyReminder(
      hour: storage.reminderHour,
      minute: storage.reminderMinute,
    );
  } else {
    await NotificationService.instance.cancelDailyReminder();
  }
}
