import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();

  static RewardedAd? _rewardedAd;
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;
  static bool _isLoadingRewarded = false;
  static bool _isLoadingInterstitial = false;
  static bool _isLoadingAppOpen = false;
  static bool _isShowingFullScreenAd = false;
  static int _shopVisitsSinceInterstitial = 0;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    // Preload Rewarded Video in the background; this does NOT display it automatically.
    // It can only be shown after a clear customer opt-in action.
    loadRewardedAd();
    loadInterstitialAd();
    loadAppOpenAd();
  }

  static String get bannerAdUnitId => _androidOrIos(
        'ca-app-pub-6141339446909248/1441458533',
        const String.fromEnvironment('ADMOB_IOS_BANNER_ID'),
      );

  static String get rewardedAdUnitId => _androidOrIos(
        'ca-app-pub-6141339446909248/2536203308',
        const String.fromEnvironment('ADMOB_IOS_REWARDED_ID'),
      );

  static String get interstitialAdUnitId => _androidOrIos(
        'ca-app-pub-6141339446909248/2811535478',
        const String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID'),
      );

  static String get appOpenAdUnitId => _androidOrIos(
        'ca-app-pub-6141339446909248/2203875862',
        const String.fromEnvironment('ADMOB_IOS_APP_OPEN_ID'),
      );

  static String _androidOrIos(String androidId, String iosId) {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidId;
      case TargetPlatform.iOS:
        return iosId;
      default:
        return '';
    }
  }

  static bool get isRewardedAdReady => _rewardedAd != null;

  static void loadRewardedAd({VoidCallback? onLoaded, Function(LoadAdError)? onFailed}) {
    if (kIsWeb || _isLoadingRewarded || _rewardedAd != null) return;
    final id = rewardedAdUnitId;
    if (id.isEmpty) return;
    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingRewarded = false;
          _rewardedAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _isLoadingRewarded = false;
          _rewardedAd = null;
          onFailed?.call(error);
        },
      ),
    );
  }

  /// Google controls rewarded-video duration and when its close/skip control
  /// appears. The app must not fake a 5/15-second timer over an AdMob ad.
  static Future<bool> showRewardedAd({
    required String userId,
    required String customData,
    required OnUserEarnedRewardCallback onUserEarnedReward,
    VoidCallback? onAdDismissed,
    Function(AdError)? onAdFailedToShow,
  }) async {
    if (_isShowingFullScreenAd) return false;
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      return false;
    }
    _rewardedAd = null;
    _isShowingFullScreenAd = true;
    try {
      await ad.setServerSideOptions(ServerSideVerificationOptions(
        userId: userId,
        customData: customData,
      ));
    } catch (_) {
      _isShowingFullScreenAd = false;
      _rewardedAd = ad;
      rethrow;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (closedAd) {
        _isShowingFullScreenAd = false;
        closedAd.dispose();
        onAdDismissed?.call();
        loadRewardedAd();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        _isShowingFullScreenAd = false;
        failedAd.dispose();
        onAdFailedToShow?.call(error);
        loadRewardedAd();
      },
    );
    await ad.show(onUserEarnedReward: onUserEarnedReward);
    return true;
  }

  static void loadInterstitialAd() {
    if (kIsWeb || _isLoadingInterstitial || _interstitialAd != null) return;
    final id = interstitialAdUnitId;
    if (id.isEmpty) return;
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoadingInterstitial = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show only at a natural break: after the customer returns from a shop.
  /// One interstitial per four shop visits; never interrupts checkout/payment.
  /// Google controls the close countdown shown inside the ad.
  static void maybeShowInterstitialAfterShopVisit() {
    if (kIsWeb || _isShowingFullScreenAd) return;
    _shopVisitsSinceInterstitial++;
    if (_shopVisitsSinceInterstitial < 4) return;
    final ad = _interstitialAd;
    if (ad == null || _isShowingFullScreenAd) {
      loadInterstitialAd();
      return;
    }
    _shopVisitsSinceInterstitial = 0;
    _interstitialAd = null;
    _isShowingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (closedAd) {
        _isShowingFullScreenAd = false;
        closedAd.dispose();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        _isShowingFullScreenAd = false;
        failedAd.dispose();
        loadInterstitialAd();
      },
    );
    ad.show();
  }

  static void loadAppOpenAd() {
    if (kIsWeb || _isLoadingAppOpen || _appOpenAd != null) return;
    final id = appOpenAdUnitId;
    if (id.isEmpty) return;
    _isLoadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAppOpen = false;
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoadingAppOpen = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  static void showAppOpenAdIfAvailable() {
    if (kIsWeb || _isShowingFullScreenAd) return;
    final ad = _appOpenAd;
    if (ad == null) {
      loadAppOpenAd();
      return;
    }
    _appOpenAd = null;
    _isShowingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (closedAd) {
        _isShowingFullScreenAd = false;
        closedAd.dispose();
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        _isShowingFullScreenAd = false;
        failedAd.dispose();
        loadAppOpenAd();
      },
    );
    ad.show();
  }
}
