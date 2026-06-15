import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Gestion centralisée des publicités AdMob.
///
/// - Initialise le SDK + le consentement (UMP, requis : les pubs collectent des
///   données — cohérent avec la loi 09-08, à documenter dans la politique de
///   confidentialité).
/// - Précharge et affiche interstitiel / rewarded / app-open, avec des **plafonds
///   de fréquence** (sinon AdMob bannit le compte ; cf. AdsConfig).
/// - Les bannières sont gérées par `BannerAdWidget` (chaque écran a la sienne).
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _ready = false;
  bool get ready => _ready;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;

  int _questionsSinceInterstitial = 0;
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAppOpen = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showingFullScreen = false;

  /// À appeler une fois au démarrage (après runApp).
  Future<void> init() async {
    await _requestConsent();
    // Appareils de dev → pubs de TEST même en release (cliquables sans ban).
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: AdsConfig.testDeviceIds),
    );
    await MobileAds.instance.initialize();
    _ready = true;
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
  }

  // --- Consentement (UMP) ---------------------------------------------------
  Future<void> _requestConsent() async {
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        }
      }, (e) => debugPrint('Consent error: ${e.message}'));
    } catch (e) {
      debugPrint('Consent exception: $e');
    }
  }

  // --- Interstitiel ---------------------------------------------------------
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) => _interstitial = null,
      ),
    );
  }

  /// Compte une question et montre un interstitiel si les plafonds le permettent.
  void onChatQuestion() {
    _questionsSinceInterstitial++;
    if (_questionsSinceInterstitial < AdsConfig.interstitialEveryNQuestions) return;
    if (DateTime.now().difference(_lastInterstitial) < AdsConfig.interstitialMinGap) {
      return;
    }
    _showInterstitial();
  }

  void _showInterstitial() {
    final ad = _interstitial;
    if (ad == null || _showingFullScreen) return;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
    );
    _interstitial = null;
    _questionsSinceInterstitial = 0;
    _lastInterstitial = DateTime.now();
    ad.show();
  }

  // --- Rewarded (débloquer une action) --------------------------------------
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdsConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }

  bool get rewardedReady => _rewarded != null;

  /// Affiche une pub rewarded ; `onReward` appelé si l'utilisateur la regarde.
  /// Renvoie false si aucune pub n'était prête.
  Future<bool> showRewarded(VoidCallback onReward) async {
    final ad = _rewarded;
    if (ad == null || _showingFullScreen) {
      _loadRewarded();
      return false;
    }
    _showingFullScreen = true;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadRewarded();
        if (earned) onReward();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        ad.dispose();
        _showingFullScreen = false;
        _loadRewarded();
      },
    );
    _rewarded = null;
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return true;
  }

  // --- App Open (ouverture / retour à l'app) --------------------------------
  void _loadAppOpen() {
    AppOpenAd.load(
      adUnitId: AdsConfig.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (e) => _appOpen = null,
      ),
    );
  }

  /// Montre l'app-open si dispo et hors de la fenêtre de fréquence.
  void showAppOpenIfReady() {
    final ad = _appOpen;
    if (ad == null || _showingFullScreen) return;
    if (DateTime.now().difference(_lastAppOpen) < AdsConfig.appOpenMinGap) return;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, e) {
        ad.dispose();
        _showingFullScreen = false;
        _loadAppOpen();
      },
    );
    _appOpen = null;
    _lastAppOpen = DateTime.now();
    ad.show();
  }
}
