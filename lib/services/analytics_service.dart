import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../logic/analytics_buckets.dart';

/// DEBUG KILL SWITCH.
///
/// Firebase Analytics runs in debug builds so events show up in DebugView while
/// verifying instrumentation. Flip this to `false` once verification is done so
/// your own debug/test sessions stop flowing into the production Analytics
/// property and skewing retention for a small user base. Release builds are
/// unaffected — they always report.
const bool kAnalyticsEnabledInDebug = false;

/// The slice of analytics the app depends on. Kept narrow so tests can use a
/// no-op fake and so no call site ever touches Firebase directly.
abstract interface class Analytics {
  /// Logs an event. [params] values may be bool/num/String — the implementation
  /// coerces them to the types Firebase accepts. Must never throw.
  void logEvent(String name, [Map<String, Object>? params]);

  /// Sets a bucketed user property. Must never throw.
  void setUserProperty(String name, String value);
}

/// Event names. Never type these as string literals at call sites.
class AnalyticsEvents {
  const AnalyticsEvents._();

  // Onboarding funnel.
  static const onboardingStarted = 'onboarding_started';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';
  static const onboardingStepReached = 'onboarding_step_reached';

  // Daily mode.
  static const dailyStarted = 'daily_started';
  static const dailyCompleted = 'daily_completed';
  static const streakBroken = 'streak_broken';

  // Journey mode.
  static const journeyLevelStarted = 'journey_level_started';
  static const journeyLevelCompleted = 'journey_level_completed';

  // Economy.
  static const coinsEarned = 'coins_earned';
  static const coinsSpent = 'coins_spent';
  static const hintUsed = 'hint_used';
  static const themeUnlocked = 'theme_unlocked';

  // Engagement.
  static const shareResult = 'share_result';
  static const statsOpened = 'stats_opened';
  static const modeSwitched = 'mode_switched';
  static const reminderEnabled = 'reminder_enabled';
  static const reminderDisabled = 'reminder_disabled';
  static const hardModeToggled = 'hard_mode_toggled';

  // Ads.
  static const rewardedShown = 'rewarded_shown';
  static const rewardedEarned = 'rewarded_earned';
  static const interstitialShown = 'interstitial_shown';
}

/// Event parameter keys.
class AnalyticsParams {
  const AnalyticsParams._();

  static const solved = 'solved';
  static const guessCount = 'guess_count';
  static const streakAfter = 'streak_after';
  static const previousStreak = 'previous_streak';
  static const reason = 'reason';
  static const level = 'level';
  static const amount = 'amount';
  static const source = 'source';
  static const sink = 'sink';
  static const mode = 'mode';
  static const themeId = 'theme_id';
  static const enabled = 'enabled';
  static const to = 'to';
  static const step = 'step';
}

/// Enum-like values for coin `source` (coins_earned).
class AnalyticsSources {
  const AnalyticsSources._();
  static const dailyWin = 'daily_win';
  static const journeyLevel = 'journey_level';
  static const watchAd = 'watch_ad';
}

/// Enum-like values for coin `sink` (coins_spent).
class AnalyticsSinks {
  const AnalyticsSinks._();
  static const hint = 'hint';
  static const extraGuess = 'extra_guess';
  static const theme = 'theme';
}

/// Enum-like values for onboarding_step_reached `step`.
class AnalyticsOnboardingSteps {
  const AnalyticsOnboardingSteps._();
  static const invite = 'invite';
  static const reveal = 'reveal';
  static const solve = 'solve';
  static const win = 'win';
}

/// Enum-like values for streak_broken `reason`.
class AnalyticsReasons {
  const AnalyticsReasons._();
  static const loss = 'loss';
  static const missedDay = 'missed_day';
}

/// User-property names (bucketed values only).
class AnalyticsUserProps {
  const AnalyticsUserProps._();
  static const streakBucket = 'streak_bucket';
  static const journeyBucket = 'journey_bucket';
  static const playedBucket = 'played_bucket';
  static const reminderOn = 'reminder_on';
  static const theme = 'theme';
}

/// No-op implementation used in tests and (optionally) debug. Does nothing.
class NoOpAnalytics implements Analytics {
  const NoOpAnalytics();

  @override
  void logEvent(String name, [Map<String, Object>? params]) {}

  @override
  void setUserProperty(String name, String value) {}
}

/// Real Firebase-backed implementation. Every call is fire-and-forget and
/// swallows errors so analytics can never crash or block gameplay.
class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._fa);
  final FirebaseAnalytics _fa;

  @override
  void logEvent(String name, [Map<String, Object>? params]) {
    try {
      _fa
          .logEvent(name: name, parameters: _coerce(params))
          .catchError((_) {});
    } catch (_) {
      // Never propagate analytics failures.
    }
  }

  @override
  void setUserProperty(String name, String value) {
    try {
      _fa.setUserProperty(name: name, value: value).catchError((_) {});
    } catch (_) {
      // Never propagate analytics failures.
    }
  }

  /// Firebase only accepts String/num param values. Coerce bool → "true"/
  /// "false" and anything unexpected → its string form.
  Map<String, Object>? _coerce(Map<String, Object>? params) {
    if (params == null || params.isEmpty) return null;
    return params.map((k, v) {
      if (v is num || v is String) return MapEntry(k, v);
      if (v is bool) return MapEntry(k, v.toString());
      return MapEntry(k, v.toString());
    });
  }
}

/// Owns the global [Analytics] instance. Defaults to a no-op so tests (and any
/// code that runs before [init]) are always safe; [init] swaps in the real
/// Firebase implementation.
class AnalyticsService {
  AnalyticsService._();

  /// The live analytics sink. No-op until [init] succeeds.
  static Analytics instance = const NoOpAnalytics();

  /// Initializes Firebase and installs the real implementation. Honors the
  /// [kAnalyticsEnabledInDebug] kill switch. Safe to fire-and-forget — it never
  /// throws and never blocks the first frame.
  static Future<void> init() async {
    if (kDebugMode && !kAnalyticsEnabledInDebug) {
      instance = const NoOpAnalytics();
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final fa = FirebaseAnalytics.instance;
      await fa.setAnalyticsCollectionEnabled(true);
      instance = FirebaseAnalyticsService(fa);
    } catch (_) {
      // Leave the no-op in place; the app keeps working without analytics.
      instance = const NoOpAnalytics();
    }
  }
}

/// Convenience for setting the bucketed user properties without spelling out
/// bucket math or property names at call sites.
extension AnalyticsUserPropsSync on Analytics {
  void syncStreak(int streak) =>
      setUserProperty(AnalyticsUserProps.streakBucket,
          AnalyticsBuckets.streak(streak));

  void syncJourney(int level) =>
      setUserProperty(AnalyticsUserProps.journeyBucket,
          AnalyticsBuckets.journey(level));

  void syncPlayed(int gamesPlayed) =>
      setUserProperty(AnalyticsUserProps.playedBucket,
          AnalyticsBuckets.played(gamesPlayed));

  void syncReminder(bool on) =>
      setUserProperty(AnalyticsUserProps.reminderOn, on.toString());

  void syncTheme(String themeId) =>
      setUserProperty(AnalyticsUserProps.theme, themeId);
}
