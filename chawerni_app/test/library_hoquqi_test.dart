import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:chawerni/screens/hoquqi_screen.dart';
import 'package:chawerni/screens/library_screen.dart';
import 'package:chawerni/state/app_scope.dart';
import 'package:chawerni/state/app_state.dart';

Widget _wrap(AppState state, Widget child) => AppScope(
      state: state,
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Hoquqi affiche les situations', (tester) async {
    // Géométrie d'un vrai téléphone (étroit) pour attraper les débordements de carte.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(AppState(), const HoquqiScreen()));
    await tester.pump();
    // Items visibles dans les 2 premières lignes de la grille (lazy GridView).
    expect(find.text('Licenciement'), findsOneWidget);
    expect(find.text('Congés'), findsOneWidget);
    expect(find.text('Divorce'), findsOneWidget);
  });

  testWidgets('Bibliothèque (hors-ligne) liste les codes sans débordement',
      (tester) async {
    // Téléphone étroit : le dahir passe sur 2 lignes → ancien IntrinsicHeight
    // débordait. Régression verrouillée ici.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(AppState(), const LibraryScreen()));
    await tester.pump();
    expect(find.text('Code pénal'), findsOneWidget);
    expect(find.text('Code du travail'), findsOneWidget);
    expect(tester.takeException(), isNull); // aucun RenderFlex overflow
  });

  test('Hoquqi → Chat : askInChat dépose la question et bascule sur l\'onglet 0', () {
    final s = AppState();
    s.setTab(2); // sur Hoquqi
    s.askInChat('Quels sont mes droits si je suis licencié ?');
    expect(s.tab, 0); // bascule vers le Chat
    expect(s.consumePendingQuestion(), 'Quels sont mes droits si je suis licencié ?');
    expect(s.pendingQuestion, isNull); // consommée une seule fois
  });
}
