import 'dart:io' show Platform;

/// Identifiants AdMob. Par défaut = **IDs de TEST officiels Google** (sûrs, à
/// utiliser en dev — ne jamais cliquer ses VRAIES pubs en test, ça fait bannir
/// le compte). Les vrais IDs se passent à la compilation via --dart-define :
///   flutter build apk --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY …
///
/// À remplacer aussi : l'App ID dans AndroidManifest.xml et ios/Runner/Info.plist.
class AdsConfig {
  // --- IDs de TEST Google (par format / plateforme) ---
  static const _testBannerA = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerI = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterA = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterI = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardA = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardI = 'ca-app-pub-3940256099942544/1712485313';
  static const _testOpenA = 'ca-app-pub-3940256099942544/9257395921';
  static const _testOpenI = 'ca-app-pub-3940256099942544/5575463023';

  // --- Vrais IDs (vides par défaut → on retombe sur les IDs de test) ---
  static const _realBannerA = String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const _realBannerI = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _realInterA = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const _realInterI = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const _realRewardA = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _realRewardI = String.fromEnvironment('ADMOB_REWARDED_IOS');
  static const _realOpenA = String.fromEnvironment('ADMOB_APPOPEN_ANDROID');
  static const _realOpenI = String.fromEnvironment('ADMOB_APPOPEN_IOS');

  static String _pick(String real, String test) => real.isNotEmpty ? real : test;
  static bool get _android => Platform.isAndroid;

  static String get banner =>
      _android ? _pick(_realBannerA, _testBannerA) : _pick(_realBannerI, _testBannerI);
  static String get interstitial =>
      _android ? _pick(_realInterA, _testInterA) : _pick(_realInterI, _testInterI);
  static String get rewarded =>
      _android ? _pick(_realRewardA, _testRewardA) : _pick(_realRewardI, _testRewardI);
  static String get appOpen =>
      _android ? _pick(_realOpenA, _testOpenA) : _pick(_realOpenI, _testOpenI);

  /// Vrai si on tourne encore sur les IDs de test (utile pour un bandeau debug).
  static bool get usingTestIds => _pick(_realBannerA, '').isEmpty;

  // --- Réglages de fréquence (protègent le compte AdMob d'un ban) ---
  /// Interstitiel : au plus 1 toutes les X questions de chat…
  static const interstitialEveryNQuestions = 3;
  /// …et jamais plus souvent que ce délai.
  static const interstitialMinGap = Duration(seconds: 60);
  /// App-open : pas plus d'une fois par cette fenêtre.
  static const appOpenMinGap = Duration(minutes: 4);
  /// Freemium : questions gratuites par jour avant pub rewarded / Pro.
  static const freeQuestionsPerDay = 5;
}
