import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/api_service.dart';
import '../data/lang.dart';
import '../data/scenarios.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/article_sheet.dart';
import '../widgets/chw_icon.dart';
import '../widgets/code_card.dart';
import '../widgets/search_field.dart';
import 'code_detail_screen.dart';

/// Bibliothèque juridique. Vide → liste des 13 codes. Recherche → articles
/// (numéro « 446 » ou mot-clé), via /search (hybride RRF + court-circuit n°).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ApiService _api = ApiService();

  List<ApiCode>? _codes;
  bool _loadingCodes = false;
  bool _codesError = false;

  String _q = '';
  Timer? _debounce;
  List<ApiSource>? _results; // non-null = mode recherche
  bool _searching = false;
  bool _searchError = false;

  // Dev/QA : pré-remplir une recherche / ouvrir un code au lancement (vide en prod).
  static const String _devSearch = String.fromEnvironment('CHAWERNI_DEV_SEARCH');
  static const String _devCode = String.fromEnvironment('CHAWERNI_DEV_CODE');

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasApi) _loadCodes();
    if (_devSearch.isNotEmpty && AppConfig.hasApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _q = _devSearch;
        _runSearch(_devSearch);
      });
    }
  }

  void _maybeOpenDevCode() {
    if (_devCode.isEmpty || _codes == null || !mounted) return;
    final match = _codes!.where((c) => c.code == _devCode);
    if (match.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CodeDetailScreen(code: match.first)),
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _loadingCodes = true;
      _codesError = false;
    });
    try {
      final c = await _api.codes();
      setState(() => _codes = c);
      _maybeOpenDevCode();
    } catch (_) {
      setState(() => _codesError = true);
    } finally {
      setState(() => _loadingCodes = false);
    }
  }

  void _onQueryChanged(String v) {
    _q = v;
    _debounce?.cancel();
    final query = v.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _searchError = false;
      });
      return;
    }
    if (!AppConfig.hasApi) return; // démo : pas de recherche d'articles
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final lang = AppScope.of(context).lang;
    setState(() {
      _searching = true;
      _searchError = false;
    });
    try {
      final res = await _api.search(query, langue: lang == Lang.fr ? 'fr' : 'ar');
      if (_q.trim() == query) setState(() => _results = res);
    } catch (_) {
      setState(() => _searchError = true);
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.libTitle,
                    style: Typo.style(size: Typo.lg, weight: Typo.bold, color: C.nila)),
                const SizedBox(height: 3),
                Text(t.libSub, style: Typo.style(size: Typo.sm, color: C.midad60)),
                const SizedBox(height: 14),
                SearchField(
                  placeholder: t.searchPlaceholder,
                  onChanged: _onQueryChanged,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    if (v.trim().isNotEmpty && AppConfig.hasApi) _runSearch(v.trim());
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _body(app.lang, t)),
        ],
      ),
    );
  }

  Widget _body(Lang lang, T t) {
    // Mode recherche d'articles.
    if (_results != null || _searching) {
      if (_searching && _results == null) {
        return const Center(child: CircularProgressIndicator(color: C.nila));
      }
      if (_searchError) {
        return _msg(t.netError, C.aker);
      }
      if (_results!.isEmpty) {
        return _msg(lang == Lang.fr ? 'Aucun article trouvé' : 'لا توجد نتيجة', C.midad60);
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: _results!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _results![i];
          return _ResultRow(
            source: s,
            lang: lang,
            onTap: () => showApiArticleSheet(context,
                api: _api, code: s.code, article: s.articleNum, appLang: lang),
          );
        },
      );
    }

    // Mode liste des codes.
    if (_loadingCodes) {
      return const Center(child: CircularProgressIndicator(color: C.nila));
    }
    if (_codesError) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t.netError, style: Typo.style(size: Typo.base, color: C.aker)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadCodes, child: const Text('Réessayer')),
        ]),
      );
    }
    return AppConfig.hasApi ? _apiCodes(lang, t) : _offlineCodes(lang, t);
  }

  Widget _apiCodes(Lang lang, T t) {
    final codes = _codes ?? const [];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = codes[i];
        return CodeCard(
          titleAr: c.titleAr,
          titleFr: c.titleFr,
          accent: c.accent,
          date: c.version,
          dahir: lang == Lang.fr
              ? '${c.articles} articles · consultables hors-ligne'
              : '${c.articles} مادة · متاحة دون إنترنت',
          consultLabel: t.consult,
          lang: lang,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CodeDetailScreen(code: c)),
          ),
        );
      },
    );
  }

  Widget _offlineCodes(Lang lang, T t) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: kCodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = kCodes[i];
        return CodeCard(
          titleAr: c.titleAr,
          titleFr: c.titleFr,
          accent: c.accent,
          date: c.date,
          dahir: c.dahir(lang),
          consultLabel: t.consult,
          lang: lang,
          onTap: () {},
        );
      },
    );
  }

  Widget _msg(String text, Color color) =>
      Center(child: Text(text, style: Typo.style(size: Typo.base, color: color)));
}

/// Résultat de recherche : code + article + extrait.
class _ResultRow extends StatelessWidget {
  final ApiSource source;
  final Lang lang;
  final VoidCallback onTap;
  const _ResultRow({required this.source, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = C.matiere(kCodeAccent(source.code));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.circular(S.radiusCard),
          border: Border.all(color: C.borderCard),
          boxShadow: S.shadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: C.zaafranLight,
                              borderRadius: BorderRadius.circular(S.radiusPill),
                            ),
                            child: Text('${source.marqueur} ${source.articleNum}',
                                style: Typo.article(
                                    size: Typo.sm, weight: Typo.citation, color: C.midad)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(codeLabel(source.code, lang),
                                overflow: TextOverflow.ellipsis,
                                style: Typo.style(
                                    size: Typo.sm, weight: Typo.medium, color: C.midad60)),
                          ),
                          ChwIcon('chevron', size: 16, color: color, mirrorInRtl: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(source.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.style(size: Typo.sm, color: C.midad, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
