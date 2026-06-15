import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Diffuse l'AppState dans l'arbre ; reconstruit les dépendants à chaque notify.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope manquant dans l\'arbre');
    return scope!.notifier!;
  }
}
