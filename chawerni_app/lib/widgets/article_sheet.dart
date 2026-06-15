import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_service.dart';
import '../data/lang.dart';
import '../data/scenarios.dart';
import '../data/strings.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'chw_button.dart';
import 'chw_icon.dart';
import 'version_badge.dart';

/// Bottom sheet « live » : récupère le texte intégral via l'API /sources.
Future<void> showApiArticleSheet(
  BuildContext context, {
  required ApiService api,
  required String code,
  required String article,
  required Lang appLang,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x661E1B18),
    builder: (_) => _ApiArticleSheet(
        api: api, code: code, article: article, appLang: appLang),
  );
}

class _ApiArticleSheet extends StatefulWidget {
  final ApiService api;
  final String code;
  final String article;
  final Lang appLang;
  const _ApiArticleSheet(
      {required this.api,
      required this.code,
      required this.article,
      required this.appLang});

  @override
  State<_ApiArticleSheet> createState() => _ApiArticleSheetState();
}

class _ApiArticleSheetState extends State<_ApiArticleSheet> {
  late String _lang = widget.appLang == Lang.fr ? 'fr' : 'ar';
  ApiArticle? _data;
  bool _loading = true;
  bool _error = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final a = await widget.api.source(widget.code, widget.article, _lang);
      if (mounted) setState(() => _data = a);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = _lang == 'fr' ? TextDirection.ltr : TextDirection.rtl;
    return Directionality(
      textDirection: dir,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        decoration: const BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSheet)),
          boxShadow: S.shadowSheet,
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: C.midad10, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    codeLabel(widget.code, _lang == 'fr' ? Lang.fr : Lang.ar),
                    style: Typo.style(size: Typo.sm, color: C.midad60),
                  ),
                ),
                _langToggle(),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: ChwIcon('x', size: 20, color: C.midad60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: _body())),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: C.nila)),
      );
    }
    if (_error || _data == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Connexion perdue',
            style: Typo.style(size: Typo.base, color: C.aker)),
      );
    }
    final d = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 22,
                decoration: BoxDecoration(
                    color: C.zellij, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('${d.marqueur} ${d.articleNum}',
                style: Typo.article(size: Typo.lg, weight: Typo.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: C.warqa,
            borderRadius: BorderRadius.circular(S.radiusCard),
            border: const BorderDirectional(
                start: BorderSide(color: C.zaafran, width: 4)),
          ),
          child: Text(
            d.texte,
            style: Typo.style(
                size: Typo.base, weight: Typo.citation, color: C.midad, height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            VersionBadge(date: d.version),
            Text(T.faith,
                textDirection: TextDirection.rtl,
                style: Typo.style(size: Typo.xs, color: C.midad60)),
            ChwButton(
              label: _copied ? '✓' : 'Copier',
              variant: ChwButtonVariant.secondary,
              leading: ChwIcon(_copied ? 'check' : 'copy', size: 17, color: C.nila),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(
                    text: '${d.marqueur} ${d.articleNum} — ${codeLabel(d.code, Lang.fr)}'));
                if (!mounted) return;
                setState(() => _copied = true);
                Future.delayed(const Duration(milliseconds: 1600),
                    () => mounted ? setState(() => _copied = false) : null);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _langToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: C.midad10, borderRadius: BorderRadius.circular(S.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['ar', 'fr'].map((l) {
          final sel = _lang == l;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_lang != l) {
                setState(() => _lang = l);
                _load();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(S.radiusPill),
                boxShadow: sel ? S.shadowSoft : null,
              ),
              child: Text(l == 'ar' ? 'ع' : 'FR',
                  style: Typo.style(
                      size: 13,
                      weight: Typo.medium,
                      color: sel ? C.nila : C.midad60)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom sheet — texte intégral de l'article. Toggle ع/FR indépendant de la
/// langue d'app (le sheet démarre dans la langue courante, FR ou عربية).
Future<void> showArticleSheet(
  BuildContext context, {
  required LegalSource source,
  required Lang appLang,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x661E1B18),
    builder: (_) => _ArticleSheet(source: source, appLang: appLang),
  );
}

class _ArticleSheet extends StatefulWidget {
  final LegalSource source;
  final Lang appLang;
  const _ArticleSheet({required this.source, required this.appLang});

  @override
  State<_ArticleSheet> createState() => _ArticleSheetState();
}

class _ArticleSheetState extends State<_ArticleSheet> {
  late Lang _sheetLang = widget.appLang == Lang.fr ? Lang.fr : Lang.ar;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final src = widget.source;
    final t = T(widget.appLang);
    final dir = _sheetLang.dir;
    final isFr = _sheetLang == Lang.fr;

    return Directionality(
      textDirection: dir,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSheet)),
          boxShadow: S.shadowSheet,
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: C.midad10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _header(src, isFr),
            const SizedBox(height: 10),
            Text(
              src.hier(isFr ? Lang.fr : Lang.ar),
              style: Typo.style(size: Typo.xs, color: C.midad60),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(child: _articleBody(src, isFr)),
            ),
            const SizedBox(height: 14),
            _footer(src, isFr, t),
          ],
        ),
      ),
    );
  }

  Widget _header(LegalSource src, bool isFr) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: C.zaafranLight,
            borderRadius: BorderRadius.circular(S.radiusPill),
          ),
          child: Text(
            src.num(isFr ? Lang.fr : Lang.ar),
            style: Typo.article(size: Typo.base, weight: Typo.citation),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            src.code(isFr ? Lang.fr : Lang.ar),
            style: Typo.style(size: Typo.sm, color: C.midad60),
          ),
        ),
        _langToggle(),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: ChwIcon('x', size: 20, color: C.midad60),
          ),
        ),
      ],
    );
  }

  Widget _langToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.midad10,
        borderRadius: BorderRadius.circular(S.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Lang.ar, Lang.fr].map((l) {
          final selected = _sheetLang == l;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _sheetLang = l),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(S.radiusPill),
                boxShadow: selected ? S.shadowSoft : null,
              ),
              child: Text(
                l == Lang.ar ? 'ع' : 'FR',
                style: Typo.style(
                  size: 13,
                  weight: Typo.medium,
                  color: selected ? C.nila : C.midad60,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _articleBody(LegalSource src, bool isFr) {
    final lang = isFr ? Lang.fr : Lang.ar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: C.zellij,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                src.num(lang),
                style: Typo.article(size: Typo.lg, weight: Typo.bold),
              ),
            ],
          ),
        ),
        // Texte intégral — héros typo : graisse 600, interligne 1.6, barre zaafran.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: C.warqa,
            borderRadius: BorderRadius.circular(S.radiusCard),
            border: const BorderDirectional(
              start: BorderSide(color: C.zaafran, width: 4),
            ),
          ),
          child: Text(
            src.full(lang),
            style: Typo.style(
              size: Typo.base,
              weight: Typo.citation,
              color: C.midad,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(LegalSource src, bool isFr, T t) {
    final lang = isFr ? Lang.fr : Lang.ar;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        VersionBadge(date: src.date(lang)),
        Text(
          T.faith,
          textDirection: TextDirection.rtl,
          style: Typo.style(size: Typo.xs, color: C.midad60),
        ),
        ChwButton(
          label: _copied ? '✓ ${t.copied}' : t.sheetCopy,
          variant: ChwButtonVariant.secondary,
          leading: ChwIcon(_copied ? 'check' : 'copy', size: 17, color: C.nila),
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: '${src.num(lang)} — ${src.code(lang)}'),
            );
            if (!mounted) return;
            setState(() => _copied = true);
            Future.delayed(const Duration(milliseconds: 1600), () {
              if (mounted) setState(() => _copied = false);
            });
          },
        ),
      ],
    );
  }
}
