import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'analytics_service.dart';

/// The slice of ad behaviour the game controller depends on. Kept narrow so it
/// can be faked in unit tests without the AdMob plugin.
abstract interface class GameAds {
  /// Shows a rewarded ad. Resolves to `true` ONLY if an ad actually displayed
  /// AND the user earned the reward. Resolves to `false` when no ad was ready
  /// or the user didn't earn it — callers must NOT grant anything on `false`.
  Future<bool> showRewarded();
  void maybeShowJourneyInterstitial();
}

/// Thin wrapper around AdMob. Defaults to Google's PUBLIC TEST ad unit IDs so
/// the app runs in development without real inventory. Override with real IDs
/// at build time via --dart-define (see keys below). NEVER hardcode real IDs.
///
/// Placements:
///   - rewarded:    watch-to-earn coins / streak restore
///   - interstitial: Journey level-end ONLY, frequency-capped
///   - banner:      stats screen
class AdsService implements GameAds {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Google's documented test ad unit IDs (safe to ship as dev defaults).
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  // Real IDs come from --dart-define=ADMOB_REWARDED=... etc. Empty => use test.
  static const _realRewarded = String.fromEnvironment('ADMOB_REWARDED');
  static const _realInterstitial = String.fromEnvironment('ADMOB_INTERSTITIAL');
  static const _realBanner = String.fromEnvironment('ADMOB_BANNER');

  // Comma-separated device ids that should always receive TEST ads (even on
  // real ad units), so you can safely test on your own device without risking
  // an AdMob policy strike. From --dart-define=ADMOB_TEST_DEVICE_IDS=...
  static const _testDeviceIds = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');

  // When set to '1'/'true', forces the UMP consent form to behave as if the
  // device were in the EEA, so the consent flow can be verified on a test
  // device outside Europe. Uses [_testDeviceIds] as the debug identifiers.
  // From --dart-define=ADMOB_CONSENT_DEBUG_EEA=1. NEVER enable for a real
  // production build — it would show the EEA form to everyone.
  static const _consentDebugEea =
      String.fromEnvironment('ADMOB_CONSENT_DEBUG_EEA');

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  // Frequency cap for Journey interstitials.
  int _journeyLevelsSinceAd = 0;
  static const _interstitialEveryNLevels = 3;

  String get _rewardedUnitId {
    if (_realRewarded.isNotEmpty) return _realRewarded;
    return Platform.isIOS ? _testRewardedIos : _testRewardedAndroid;
  }

  String get _interstitialUnitId {
    if (_realInterstitial.isNotEmpty) return _realInterstitial;
    return Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;
  }

  String get bannerUnitId {
    if (_realBanner.isNotEmpty) return _realBanner;
    return Platform.isIOS ? _testBannerIos : _testBannerAndroid;
  }

  Future<void> init() async {
    final testIds = _testDeviceIds
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Gather user consent (UMP) BEFORE requesting any ads. Required for
    // GDPR/EEA; on non-EEA devices the form simply isn't shown. Failures are
    // non-fatal — AdMob then serves non-personalized ads.
    await _gatherConsent(testIds);

    // Register test devices so real ad units serve TEST ads on them (avoids
    // policy strikes from self-clicks during development).
    if (testIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testIds),
      );
    }
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  /// Runs the UMP consent flow: refresh consent info, then show the consent
  /// form if one is required. Completes once the form is dismissed, consent
  /// isn't required, or the request fails — never throws, never blocks
  /// indefinitely, so ad init can always proceed.
  Future<void> _gatherConsent(List<String> testIds) async {
    final debugEea = _consentDebugEea == '1' ||
        _consentDebugEea.toLowerCase() == 'true';
    final params = ConsentRequestParameters(
      consentDebugSettings: (debugEea && testIds.isNotEmpty)
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: testIds,
            )
          : null,
    );

    final completer = Completer<void>();
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        // Info refreshed — show the form only if consent is required.
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) => done());
        } catch (_) {
          done();
        }
      },
      (FormError _) => done(), // Update failed — proceed without a form.
    );

    // Safety net: if the platform never calls back, don't hang ad init.
    return completer.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  // --- Rewarded ------------------------------------------------------------

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Shows a rewarded ad. Returns `true` only when an ad actually displayed and
  /// the user earned the reward. If no ad is ready, returns `false` immediately
  /// (and kicks off a load for next time) — the caller must NOT grant anything.
  /// This prevents reward/coin farming when ads fail to fill.
  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null; // consume so it can't be shown twice
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    AnalyticsService.instance.logEvent(AnalyticsEvents.rewardedShown);
    await ad.show(onUserEarnedReward: (_, __) {
      earned = true;
      AnalyticsService.instance.logEvent(AnalyticsEvents.rewardedEarned);
    });
    return completer.future;
  }

  // --- Interstitial (Journey mode only) ------------------------------------

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Pure cadence + entitlement decision: returns true when an interstitial is
  /// due now, advancing/resetting the level counter as a side effect. Kept
  /// separate from [maybeShowJourneyInterstitial] so the gating is unit-testable
  /// without the AdMob plugin.
  bool shouldShowJourneyInterstitial() {
    _journeyLevelsSinceAd++;
    if (_journeyLevelsSinceAd < _interstitialEveryNLevels) return false;
    _journeyLevelsSinceAd = 0;
    return true;
  }

  /// Test seam: reset the cadence counter to a known state.
  @visibleForTesting
  void debugResetCadence() {
    _journeyLevelsSinceAd = 0;
  }

  /// Call at the end of a JOURNEY level. Shows an interstitial only every N
  /// levels, and never when Remove Ads is owned. Do NOT call this in Daily mode.
  @override
  void maybeShowJourneyInterstitial() {
    if (!shouldShowJourneyInterstitial()) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );
    AnalyticsService.instance.logEvent(AnalyticsEvents.interstitialShown);
    ad.show();
  }
}
