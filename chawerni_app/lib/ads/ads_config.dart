import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

/// Identifiants AdMob.
///
/// **Debug → IDs de TEST Google** (obligatoire : cliquer ses VRAIES pubs en dev
/// fait bannir le compte). **Release → vrais IDs de prod.** Le basculement est
/// automatique via `kDebugMode` — `flutter run` montre des pubs de test,
/// `flutter build apk --release` montre les vraies.
///
/// App ID (réel) à mettre dans AndroidManifest.xml :
///   ca-app-pub-8986402840311549~6876241989
/// iOS : pas encore d'app AdMob iOS → on garde les IDs de test côté iOS.
class AdsConfig {
  // --- IDs de TEST officiels Google (utilisés en debug) ---
  static const _testBannerA = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerI = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterA = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterI = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardA = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardI = 'ca-app-pub-3940256099942544/1712485313';
  static const _testOpenA = 'ca-app-pub-3940256099942544/9257395921';
  static const _testOpenI = 'ca-app-pub-3940256099942544/5575463023';

  // --- Vrais IDs de PROD (Android, compte pub-8986402840311549) ---
  static const _prodBannerA = 'ca-app-pub-8986402840311549/4302049530';
  static const _prodInterA = 'ca-app-pub-8986402840311549/9154879403';
  static const _prodRewardA = 'ca-app-pub-8986402840311549/7626175313';
  static const _prodOpenA = 'ca-app-pub-8986402840311549/9833536254';

  static bool get _android => Platform.isAndroid;

  // En debug : toujours test. En release : vrais IDs Android (iOS → test tant
  // qu'aucune app AdMob iOS n'existe).
  static String get banner => kDebugMode
      ? (_android ? _testBannerA : _testBannerI)
      : (_android ? _prodBannerA : _testBannerI);
  static String get interstitial => kDebugMode
      ? (_android ? _testInterA : _testInterI)
      : (_android ? _prodInterA : _testInterI);
  static String get rewarded => kDebugMode
      ? (_android ? _testRewardA : _testRewardI)
      : (_android ? _prodRewardA : _testRewardI);
  static String get appOpen => kDebugMode
      ? (_android ? _testOpenA : _testOpenI)
      : (_android ? _prodOpenA : _testOpenI);

  /// Vrai si on sert des pubs de test (debug).
  static bool get usingTestIds => kDebugMode;

  /// Appareils de DEV : reçoivent toujours des pubs de TEST (même en release),
  /// donc cliquables sans risquer un ban du compte AdMob. Récupérer l'ID dans
  /// les logs : `Use RequestConfiguration… setTestDeviceIds(…"<ID>"…)`.
  static const testDeviceIds = <String>[
    'DD1E38A987561D249BB17DD743A237DE', // Pixel d'Abderrahim
  ];

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
