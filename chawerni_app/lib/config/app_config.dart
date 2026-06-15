/// Configuration de compilation de l'app.
///
/// `CHAWERNI_API_BASE` est injecté via `--dart-define` au build :
///   flutter build apk --release --dart-define=CHAWERNI_API_BASE=https://chawerni.me
///
/// Si vide (build de démo), l'app retombe sur les scénarios scriptés intégrés —
/// le chat fonctionne hors-ligne pour la démo sans backend.
class AppConfig {
  static const String apiBase = String.fromEnvironment('CHAWERNI_API_BASE');

  /// L'app appelle l'API réelle uniquement si une base est fournie.
  static bool get hasApi => apiBase.isNotEmpty;
}
