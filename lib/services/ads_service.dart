import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The slice of ad behaviour the game controller depends on. Kept narrow so it
/// can be faked in unit tests without the AdMob plugin.
abstract interface class GameAds {
  Future<void> showRewarded({required void Function() onReward});
  void maybeShowJourneyInterstitial();
}

/// Thin wrapper around AdMob. Defaults to Google's PUBLIC TEST ad unit IDs so
/// the app runs in development without real inventory. Override with real IDs
/// at build time via --dart-define (see keys below). NEVER hardcode real IDs.
///
/// Placements:
///   - rewarded:    hint / reveal letter / extra guess / streak restore
///   - interstitial: Journey level-end ONLY, frequency-capped
///   - banner:      stats screen (suppressed when Remove Ads is owned)
class AdsService implements GameAds {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Google's documented test ad unit IDs (safe to ship as dev defaults).
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  // Real IDs come from --dart-define=ADMOB_REWARDED=... etc. Empty => use test.
  static const _realRewarded = String.fromEnvironment('ADMOB_REWARDED');
  static const _realInterstitial = String.fromEnvironment('ADMOB_INTERSTITIAL');
  static const _realBanner = String.fromEnvironment('ADMOB_BANNER');

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  // Frequency cap for Journey interstitials.
  int _journeyLevelsSinceAd = 0;
  static const _interstitialEveryNLevels = 3;

  /// True when the user owns the Remove Ads IAP. Suppresses interstitials and
  /// banners (rewarded boosters remain opt-in). Set from the persisted
  /// entitlement at startup and after a purchase/restore.
  bool removeAds = false;

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
    await MobileAds.instance.initialize();
    // TODO(consent): integrate the UMP consent flow before requesting ads in
    // GDPR regions, then load. eCPM in Tier-1 depends on consented signals.
    _loadRewarded();
    _loadInterstitial();
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

  /// Shows a rewarded ad. Calls [onReward] only if the user earned the reward.
  /// If no ad is ready, [onReward] is called anyway so the feature still works
  /// in development — tighten this to require a real view before launch.
  @override
  Future<void> showRewarded({required void Function() onReward}) async {
    final ad = _rewarded;
    if (ad == null) {
      onReward(); // dev fallback; remove for production strictness.
      _loadRewarded();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onReward());
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
    if (removeAds) return false;
    _journeyLevelsSinceAd++;
    if (_journeyLevelsSinceAd < _interstitialEveryNLevels) return false;
    _journeyLevelsSinceAd = 0;
    return true;
  }

  /// Test seam: reset the cadence counter and entitlement to a known state.
  @visibleForTesting
  void debugResetCadence() {
    _journeyLevelsSinceAd = 0;
    removeAds = false;
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
    ad.show();
  }
}
