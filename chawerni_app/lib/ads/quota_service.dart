import 'package:shared_preferences/shared_preferences.dart';

import 'ads_config.dart';

/// Quota freemium des questions du chat IA (la génération coûte des tokens Groq).
/// La **consultation des textes de loi reste gratuite et illimitée** (Bibliothèque)
/// — on ne met jamais de paywall sur la loi (règle de marque).
///
/// Gratuit : `freeQuestionsPerDay` questions/jour. Au-delà → pub rewarded (+bonus)
/// ou abonnement Pro (à venir). Stocké en local (clés `chw-q-*`).
class QuotaService {
  QuotaService._();
  static final QuotaService instance = QuotaService._();

  static const _kDate = 'chw-q-date';
  static const _kCount = 'chw-q-count';
  static const _kBonus = 'chw-q-bonus';

  bool isPro = false; // futur : débloqué par l'abonnement

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<int> _used(SharedPreferences p) async {
    if (p.getString(_kDate) != _today()) {
      await p.setString(_kDate, _today());
      await p.setInt(_kCount, 0);
      await p.setInt(_kBonus, 0);
    }
    return p.getInt(_kCount) ?? 0;
  }

  /// Questions restantes aujourd'hui (gratuites + bonus rewarded). 9999 si Pro.
  Future<int> remaining() async {
    if (isPro) return 9999;
    final p = await SharedPreferences.getInstance();
    final used = await _used(p);
    final bonus = p.getInt(_kBonus) ?? 0;
    return (AdsConfig.freeQuestionsPerDay + bonus - used).clamp(0, 9999);
  }

  Future<bool> canAsk() async => isPro || (await remaining()) > 0;

  /// Décrémente après une question réellement posée.
  Future<void> recordAsk() async {
    if (isPro) return;
    final p = await SharedPreferences.getInstance();
    final used = await _used(p);
    await p.setInt(_kCount, used + 1);
  }

  /// Bonus accordé après une pub rewarded (ex. +5 questions).
  Future<void> grantBonus([int n = 5]) async {
    final p = await SharedPreferences.getInstance();
    await _used(p);
    await p.setInt(_kBonus, (p.getInt(_kBonus) ?? 0) + n);
  }
}
