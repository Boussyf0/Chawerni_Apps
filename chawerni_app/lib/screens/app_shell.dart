import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';
import 'chat_screen.dart';
import 'hoquqi_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

/// Coquille de l'app : 4 onglets (Chat / Bibliothèque / Hoquqi / Réglages).
/// L'onglet actif vit dans AppState pour que Hoquqi puisse basculer vers le Chat.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = [
    ChatScreen(),
    LibraryScreen(),
    HoquqiScreen(),
    SettingsScreen(),
  ];

  static const _icons = ['message-circle', 'book-open', 'file-text', 'settings'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);
    final tab = app.tab;
    final labels = [t.tabChat, t.tabLib, t.tabHoquqi, t.tabSettings];

    return Scaffold(
      backgroundColor: C.warqa,
      body: IndexedStack(index: tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.surfaceCard,
          border: Border(top: BorderSide(color: C.midad10)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(4, (i) {
                final selected = i == tab;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => app.setTab(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChwIcon(
                          _icons[i],
                          size: 23,
                          color: selected ? C.nila : C.midad30,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: Typo.style(
                            size: 11,
                            weight: selected ? Typo.citation : Typo.regular,
                            color: selected ? C.nila : C.midad60,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
