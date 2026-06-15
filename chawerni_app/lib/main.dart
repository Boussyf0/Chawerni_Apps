import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/app_shell.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(ChawerniApp(state: state));
}

class ChawerniApp extends StatelessWidget {
  final AppState state;
  const ChawerniApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'Chawerni',
            debugShowCheckedModeBanner: false,
            theme: buildChawerniTheme(),
            // Direction + taille de texte pilotées par l'état (RTL d'abord).
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return Directionality(
                textDirection: state.lang.dir,
                child: MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(state.scaleFactor),
                  ),
                  child: child!,
                ),
              );
            },
            home: const _Root(),
          );
        },
      ),
    );
  }
}

/// Aiguille selon l'étape du parcours : onboarding → disclaimer → app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    Widget body;
    switch (app.flow) {
      case AppFlow.onboarding:
        body = OnboardingScreen(onDone: () => app.setFlow(AppFlow.disclaimer));
        break;
      case AppFlow.disclaimer:
        body = DisclaimerScreen(onDone: () => app.setFlow(AppFlow.app));
        break;
      case AppFlow.app:
        return const AppShell();
    }

    return Scaffold(
      backgroundColor: C.warqa,
      body: AnimatedSwitcher(
        duration: S.durationBase,
        switchInCurve: S.easeOut,
        child: KeyedSubtree(key: ValueKey(app.flow), child: body),
      ),
    );
  }
}
