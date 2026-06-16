import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../branding.dart';

/// Schedules the once-per-day "today's puzzle is live" local reminder.
///
/// Uses a single fixed notification id so there is never more than one pending
/// reminder — rescheduling replaces it. Repeats daily at a set local time via
/// [DateTimeComponents.time]. Inexact scheduling is used so we don't need the
/// Android 12+ exact-alarm permission.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily puzzle reminder';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _setLocalLocation();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      // We ask explicitly in requestPermissions() so first paint isn't blocked.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// Best-effort: pick a timezone location whose current UTC offset matches the
  /// device's, so the daily reminder fires at the right wall-clock time without
  /// pulling in an extra platform-timezone dependency.
  void _setLocalLocation() {
    final deviceOffset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset == deviceOffset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  /// Requests notification permission (Android 13+ / iOS). Returns true if
  /// granted (or already granted). Safe to call before scheduling.
  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true; // null => pre-Android-13, no runtime permission.
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  /// (Re)schedules the daily reminder at [hour]:[minute] local time.
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    await init();
    await cancelDailyReminder();
    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        '${Branding.appName} is live',
        "Today's puzzle is ready — keep your streak going!",
        _nextInstanceOf(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'A once-a-day nudge that the new puzzle is up.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    } catch (e) {
      // Scheduling can fail if permission was denied; don't crash the app.
      debugPrint('Daily reminder scheduling failed: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    await init();
    await _plugin.cancel(_dailyReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
