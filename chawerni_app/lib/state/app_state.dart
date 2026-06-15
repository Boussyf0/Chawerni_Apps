import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/lang.dart';

/// Étape du parcours global : onboarding → disclaimer → app.
enum AppFlow { onboarding, disclaimer, app }

/// État partagé de l'app (langue, parcours, taille de texte).
/// Persistant via SharedPreferences — clés héritées du prototype web :
/// `chw-lang`, `chw-flow`, plus `chw-scale` pour les 3 crans de taille.
class AppState extends ChangeNotifier {
  static const _kLang = 'chw-lang';
  static const _kFlow = 'chw-flow';
  static const _kScale = 'chw-scale';

  Lang _lang = Lang.fr;
  AppFlow _flow = AppFlow.onboarding;
  int _textScale = 1; // 0 / 1 / 2 — trois crans
  bool _ready = false;
  int _tab = 0; // onglet actif (Chat / Bibliothèque / Hoquqi / Réglages)
  String? _pendingQuestion; // question à poser au Chat (depuis Hoquqi)

  // Dev/QA : ouvrir directement un onglet et sauter l'onboarding (0 = prod).
  static const int _devTab = int.fromEnvironment('CHAWERNI_DEV_TAB');

  Lang get lang => _lang;
  AppFlow get flow => _flow;
  int get textScale => _textScale;
  bool get ready => _ready;
  int get tab => _tab;
  String? get pendingQuestion => _pendingQuestion;

  /// Facteur appliqué à MediaQuery.textScaler : 0,94 / 1,0 / 1,15.
  double get scaleFactor => const [0.94, 1.0, 1.15][_textScale];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = Lang.fromCode(prefs.getString(_kLang));
    final f = prefs.getString(_kFlow);
    _flow = AppFlow.values.firstWhere(
      (x) => x.name == f,
      orElse: () => AppFlow.onboarding,
    );
    _textScale = prefs.getInt(_kScale) ?? 1;
    if (_devTab > 0) {
      _flow = AppFlow.app; // QA : on saute onboarding/disclaimer
      _tab = _devTab;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences) write) async {
    final prefs = await SharedPreferences.getInstance();
    write(prefs);
  }

  void setLang(Lang l) {
    if (l == _lang) return;
    _lang = l;
    notifyListeners();
    _save((p) => p.setString(_kLang, l.code));
  }

  void setFlow(AppFlow f) {
    _flow = f;
    notifyListeners();
    _save((p) => p.setString(_kFlow, f.name));
  }

  void setTextScale(int i) {
    if (i == _textScale) return;
    _textScale = i;
    notifyListeners();
    _save((p) => p.setInt(_kScale, i));
  }

  /// Rejouer l'onboarding (bouton ↺ du prototype).
  void replayOnboarding() => setFlow(AppFlow.onboarding);

  void setTab(int i) {
    if (i == _tab) return;
    _tab = i;
    notifyListeners();
  }

  /// Depuis Hoquqi : bascule sur le Chat et y dépose une question à poser.
  void askInChat(String question) {
    _pendingQuestion = question;
    _tab = 0;
    notifyListeners();
  }

  /// Le Chat récupère et efface la question en attente (évite de la rejouer).
  String? consumePendingQuestion() {
    final q = _pendingQuestion;
    _pendingQuestion = null;
    return q;
  }
}
