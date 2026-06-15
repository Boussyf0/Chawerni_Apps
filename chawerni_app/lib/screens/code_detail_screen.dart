import 'package:flutter/material.dart';

import '../data/api_service.dart';
import '../data/lang.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/accent_card.dart';
import '../widgets/article_sheet.dart';
import '../widgets/chw_icon.dart';
import '../widgets/search_field.dart';
import '../widgets/version_badge.dart';

/// Détail d'un code : parcours paginé des articles + recherche (n° ou mot-clé).
class CodeDetailScreen extends StatefulWidget {
  final ApiCode code;
  const CodeDetailScreen({super.key, required this.code});

  @override
  State<CodeDetailScreen> createState() => _CodeDetailScreenState();
}

class _CodeDetailScreenState extends State<CodeDetailScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();

  final List<ApiArticleItem> _browse = [];
  List<ApiSource>? _results; // non-null = mode recherche
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;

  String get _langCode => AppScope.of(context).lang == Lang.fr ? 'fr' : 'ar';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBrowse(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_results == null &&
        !_loadingMore &&
        _browse.length < _total &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      _loadBrowse();
    }
  }

  Future<void> _loadBrowse({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = false;
        _browse.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await _api.codeArticles(widget.code.code, _langCode,
          offset: _browse.length, limit: 30);
      setState(() {
        _total = page.total;
        _browse.addAll(page.articles);
      });
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _results = null); // retour au parcours
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await _api.search(query, code: widget.code.code, langue: _langCode);
      setState(() => _results = res);
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _open(String articleNum) {
    showApiArticleSheet(context,
        api: _api,
        code: widget.code.code,
        article: articleNum,
        appLang: AppScope.of(context).lang);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final color = C.matiere(widget.code.accent);
    final title = lang == Lang.fr ? widget.code.titleFr : widget.code.titleAr;
    final subtitle = lang == Lang.fr ? widget.code.titleAr : widget.code.titleFr;

    return Scaffold(
      backgroundColor: C.warqa,
      appBar: AppBar(
        backgroundColor: C.warqa,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const ChwIcon('chevron', size: 22, color: C.midad, mirrorInRtl: true),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Typo.style(size: Typo.md, weight: Typo.bold, color: color)),
            Text(subtitle,
                style: Typo.style(size: Typo.xs, color: C.midad60)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VersionBadge(date: widget.code.version),
                    const SizedBox(width: 10),
                    Text('${widget.code.articles} articles',
                        style: Typo.style(size: Typo.xs, color: C.midad60)),
                  ],
                ),
                const SizedBox(height: 12),
                SearchField(
                  placeholder: lang == Lang.fr
                      ? 'Article (« 446 ») ou mot-clé…'
                      : 'رقم المادة أو كلمة مفتاحية…',
                  onChanged: (_) {},
                  onSubmitted: _runSearch,
                ),
              ],
            ),
          ),
          Expanded(child: _list(lang, color)),
        ],
      ),
    );
  }

  Widget _list(Lang lang, Color color) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.nila));
    }
    if (_error) {
      return _centered(lang == Lang.fr ? 'Connexion perdue' : 'انقطع الاتصال', C.aker);
    }

    if (_results != null) {
      if (_results!.isEmpty) {
        return _centered(
            lang == Lang.fr ? 'Aucun article trouvé' : 'لا توجد نتيجة', C.midad60);
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _results!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _results![i];
          return _ArticleRow(
            label: '${s.marqueur} ${s.articleNum}',
            excerpt: s.excerpt,
            color: color,
            onTap: () => _open(s.articleNum),
          );
        },
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _browse.length + (_browse.length < _total ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= _browse.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: C.nila)),
          );
        }
        final a = _browse[i];
        return _ArticleRow(
          label: '${a.marqueur} ${a.articleNum}',
          excerpt: a.excerpt,
          color: color,
          onTap: () => _open(a.articleNum),
        );
      },
    );
  }

  Widget _centered(String text, Color color) => Center(
        child: Text(text, style: Typo.style(size: Typo.base, color: color)),
      );
}

/// Ligne d'article (parcours ou résultat de recherche).
class _ArticleRow extends StatelessWidget {
  final String label;
  final String excerpt;
  final Color color;
  final VoidCallback onTap;
  const _ArticleRow(
      {required this.label,
      required this.excerpt,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      accent: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: C.zaafranLight,
                  borderRadius: BorderRadius.circular(S.radiusPill),
                ),
                child: Text(label,
                    style: Typo.article(
                        size: Typo.sm, weight: Typo.citation, color: C.midad)),
              ),
              const Spacer(),
              ChwIcon('chevron', size: 16, color: color, mirrorInRtl: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Typo.style(size: Typo.sm, color: C.midad, height: 1.5)),
        ],
      ),
    );
  }
}
