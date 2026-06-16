import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Thin wrapper around AdMob. Defaults to Google's PUBLIC TEST ad unit IDs so
/// the app runs in development without real inventory. Override with real IDs
/// at build time via --dart-define (see keys below). NEVER hardcode real IDs.
///
/// Placements:
///   - rewarded:    hint / reveal letter / extra guess / streak restore
///   - interstitial: Practice mode round-end ONLY, frequency-capped
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // Google's documented test ad unit IDs (safe to ship as dev defaults).
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // Real IDs come from --dart-define=ADMOB_REWARDED=... etc. Empty => use test.
  static const _realRewarded = String.fromEnvironment('ADMOB_REWARDED');
  static const _realInterstitial = String.fromEnvironment('ADMOB_INTERSTITIAL');

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  // Frequency cap for Practice interstitials.
  int _practiceRoundsSinceAd = 0;
  static const _interstitialEveryNRounds = 3;

  String get _rewardedUnitId {
    if (_realRewarded.isNotEmpty) return _realRewarded;
    return Platform.isIOS ? _testRewardedIos : _testRewardedAndroid;
  }

  String get _interstitialUnitId {
    if (_realInterstitial.isNotEmpty) return _realInterstitial;
    return Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;
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

  // --- Interstitial (Practice mode only) -----------------------------------

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

  /// Call at the end of a PRACTICE round. Shows an interstitial only every N
  /// rounds. Do NOT call this in Daily mode.
  void maybeShowPracticeInterstitial() {
    _practiceRoundsSinceAd++;
    if (_practiceRoundsSinceAd < _interstitialEveryNRounds) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _practiceRoundsSinceAd = 0;
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
