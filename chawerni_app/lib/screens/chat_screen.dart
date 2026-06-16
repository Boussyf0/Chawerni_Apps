import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../ads/ads_config.dart';
import '../ads/quota_service.dart';
import '../config/app_config.dart';
import '../data/api_service.dart';
import '../data/lang.dart';
import '../data/scenarios.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/alert_banner.dart';
import '../widgets/chat_bubble.dart';
import 'find_lawyer_screen.dart';
import '../widgets/chw_button.dart';
import '../widgets/chw_chip.dart';
import '../widgets/chw_icon.dart';
import '../widgets/lang_switcher.dart';
import '../widgets/logo_mark.dart';
import '../widgets/source_card.dart';
import '../widgets/thinking_dots.dart';
import '../widgets/article_sheet.dart';
import '../widgets/zellij_frieze.dart';

/// Un échange du fil. Deux origines possibles :
///   - scripté (`scenario`) : démo hors-ligne, textes de loi intégrés ;
///   - live (`apiAnswer`) : réponse réelle de l'API /ask.
/// `error` porte la micro-copy « connexion perdue ».
class _Exchange {
  final String userText; // question affichée dans la bulle utilisateur
  bool thinking;
  Scenario? scenario;
  ApiAnswer? apiAnswer;
  String? error;
  // Traduction de la réponse (à la demande). `translatedText` remplace l'affichage
  // tant qu'il est non nul ; `translating` montre un indicateur.
  String? translatedText;
  String? translatedTo;
  bool translating = false;
  _Exchange({required this.userText, this.scenario}) : thinking = true;
}

/// Écran principal — le Chat. En présence d'une API (`CHAWERNI_API_BASE`), les
/// questions partent au backend RAG ; sinon, scénarios scriptés (démo).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Exchange> _exchanges = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ApiService _api = ApiService();

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Question déposée depuis Hoquqi → la poser une fois, après la frame.
    final app = AppScope.of(context);
    if (app.pendingQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final q = app.consumePendingQuestion();
        if (q != null && mounted) _send(q, app.lang);
      });
    }
  }

  // --- Scripté (démo sans backend) -----------------------------------------

  void _askScenario(Scenario sc, Lang lang) {
    setState(() => _exchanges.add(_Exchange(userText: sc.chip(lang), scenario: sc)));
    _scrollToEnd();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _exchanges.last.thinking = false);
      _scrollToEnd();
    });
  }

  // --- Live (API RAG) ------------------------------------------------------

  /// Mémoire de conversation : on renvoie au backend les derniers tours aboutis
  /// (question + réponse) pour qu'il résolve les questions de suivi.
  List<Map<String, String>> _buildHistory() {
    final hist = <Map<String, String>>[];
    for (final ex in _exchanges) {
      final ans = ex.apiAnswer;
      if (ans == null || ans.refused) continue; // seulement les échanges aboutis
      hist.add({'role': 'user', 'content': ex.userText});
      hist.add({'role': 'assistant', 'content': ans.answer});
    }
    const maxMsgs = 6; // 3 derniers tours suffisent pour le contexte
    return hist.length > maxMsgs ? hist.sublist(hist.length - maxMsgs) : hist;
  }

  Future<void> _askApi(String question, Lang lang) async {
    final history = _buildHistory(); // avant d'ajouter le nouvel échange
    final ex = _Exchange(userText: question);
    setState(() => _exchanges.add(ex));
    _scrollToEnd();
    try {
      final ans = await _api.ask(question, lang, history: history);
      if (!mounted) return;
      setState(() {
        ex.apiAnswer = ans;
        ex.thinking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        ex.error = T(lang).netError;
        ex.thinking = false;
      });
    }
    _scrollToEnd();
  }

  // Freemium : la question IA passe par le quota (les textes de loi, eux, restent
  // gratuits et illimités côté Bibliothèque).
  Future<void> _askApiGated(String q, Lang lang) async {
    if (await QuotaService.instance.canAsk()) {
      _proceedAsk(q, lang);
    } else if (mounted) {
      _showQuotaSheet(q, lang);
    }
  }

  void _proceedAsk(String q, Lang lang) {
    QuotaService.instance.recordAsk();
    _askApi(q, lang);
    AdManager.instance.onChatQuestion(); // interstitiel (plafonné)
  }

  void _showQuotaSheet(String q, Lang lang) {
    final isFr = lang == Lang.fr;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSheet))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: C.midad10, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(isFr ? 'Questions gratuites épuisées' : 'انتهت أسئلتك المجانية',
                style: Typo.style(size: Typo.lg, weight: Typo.bold, color: C.midad)),
            const SizedBox(height: 6),
            Text(
              isFr
                  ? 'Tu as utilisé tes ${AdsConfig.freeQuestionsPerDay} questions du jour. Regarde une courte pub pour en débloquer 5 — ou consulte gratuitement les textes de loi dans la Bibliothèque.'
                  : 'استعملت ${AdsConfig.freeQuestionsPerDay} أسئلة اليوم. شاهد إعلانًا قصيرًا لفتح 5 أسئلة إضافية — أو تصفّح النصوص القانونية مجانًا في المكتبة.',
              style: Typo.style(size: Typo.sm, color: C.midad60, height: 1.5),
            ),
            const SizedBox(height: 18),
            ChwButton(
              label: isFr ? 'Regarder une pub (+5)' : 'شاهد إعلانًا (+5)',
              large: true,
              fullWidth: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                AdManager.instance.showRewarded(() async {
                  await QuotaService.instance.grantBonus(5);
                  if (mounted) _proceedAsk(q, lang);
                }).then((ok) {
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isFr
                          ? 'Pub indisponible, réessaie dans un instant.'
                          : 'الإعلان غير متاح، أعد المحاولة بعد قليل.'),
                    ));
                  }
                });
              },
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isFr ? 'Plus tard' : 'لاحقًا',
                    style: Typo.style(size: Typo.sm, color: C.midad60)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(String text, Lang lang) {
    final q = text.trim();
    if (q.isEmpty) return;
    if (AppConfig.hasApi) {
      _askApiGated(q, lang);
    } else {
      // Démo : aiguillage par mot-clé vers un scénario.
      Scenario pick = kScenarios.first;
      final lc = q.toLowerCase();
      if (lc.contains('divorce') || q.contains('طلاق')) {
        pick = kScenarios[1];
      } else if (lc.contains('loyer') || lc.contains('bail') || q.contains('كراء')) {
        pick = kScenarios[2];
      }
      _askScenario(pick, lang);
    }
  }

  void _onChip(Scenario sc, Lang lang) {
    if (AppConfig.hasApi) {
      _askApiGated(sc.chip(lang), lang);
    } else {
      _askScenario(sc, lang);
    }
  }

  void _submitTyped(Lang lang) {
    final q = _input.text;
    _input.clear();
    FocusScope.of(context).unfocus();
    _send(q, lang);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: S.durationBase, curve: S.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);
    final empty = _exchanges.isEmpty;

    return Column(
      children: [
        _ChatHeader(lang: app.lang, onLang: app.setLang),
        Expanded(
          child: empty
              ? _emptyState(t)
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  itemCount: _exchanges.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _buildExchange(_exchanges[i], app.lang, t),
                ),
        ),
        if (empty) _starterChips(app.lang),
        _inputBar(t, app.lang),
      ],
    );
  }

  Widget _emptyState(T t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Opacity(opacity: 0.9, child: LogoMark(size: 56)),
            const SizedBox(height: 16),
            Text(t.emptyTitle,
                textAlign: TextAlign.center,
                style: Typo.style(size: Typo.lg, weight: Typo.bold, color: C.midad)),
            const SizedBox(height: 6),
            Text(t.emptySub,
                textAlign: TextAlign.center,
                style: Typo.style(size: Typo.sm, color: C.midad60, height: 1.55)),
          ],
        ),
      ),
    );
  }

  Widget _buildExchange(_Exchange ex, Lang lang, T t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Appui long sur sa propre question → menu Modifier (live API seulement).
        GestureDetector(
          onLongPress: AppConfig.hasApi && ex.scenario == null
              ? () => _showEditSheet(ex, lang)
              : null,
          child: ChatBubble(text: ex.userText, isUser: true),
        ),
        const SizedBox(height: 12),
        if (ex.thinking)
          ThinkingDots(labels: t.thinking)
        else if (ex.error != null)
          _errorBubble(ex, lang, t)
        else if (ex.apiAnswer != null)
          ..._apiAnswerWidgets(ex, lang, t)
        else if (ex.scenario != null)
          ..._scenarioWidgets(ex.scenario!, lang, t),
      ],
    );
  }

  // --- Rendu réponse live --------------------------------------------------

  List<Widget> _apiAnswerWidgets(_Exchange ex, Lang lang, T t) {
    final a = ex.apiAnswer!;
    return [
      ChatBubble(text: ex.translatedText ?? a.answer, isUser: false),
      if (!a.refused) ...[
        const SizedBox(height: 6),
        _translateRow(ex, lang),
      ],
      for (final s in a.sources) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 36),
          child: SourceCard(
            num: '${s.marqueur} ${s.articleNum}',
            code: codeLabel(s.code, lang),
            excerpt: s.excerpt,
            date: s.version,
            unfold: true,
            onTap: () => showApiArticleSheet(context,
                api: _api, code: s.code, article: s.articleNum, appLang: lang),
          ),
        ),
      ],
      if (a.grave && a.lawyerBanner != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 36),
          child: AlertBanner(
            title: 'هاد الموضوع مهم بزاف',
            body: a.lawyerBanner!,
            actionLabel: t.findLawyer,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FindLawyerScreen()),
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      Text(a.disclaimer,
          style: Typo.style(size: Typo.xs, color: C.midad30, height: 1.4)),
      const SizedBox(height: 4),
      if (!a.refused)
        Text(T.sent,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: Typo.style(size: Typo.xs, color: C.midad30)),
    ];
  }

  // --- #2 Traduction ------------------------------------------------------

  static const _kTargets = {
    'fr': 'Français',
    'ar': 'العربية',
    'darija': 'الدارجة',
    'en': 'English',
  };

  Widget _translateRow(_Exchange ex, Lang lang) {
    if (ex.translating) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(lang == Lang.fr ? 'Traduction…' : 'جاري الترجمة…',
            style: Typo.style(size: Typo.xs, color: C.midad30)),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (ex.translatedText == null)
            ChwChip(
              label: lang == Lang.fr ? '🌐 Traduire' : '🌐 ترجم',
              onTap: () => _pickTranslate(ex, lang),
            )
          else
            ChwChip(
              label: lang == Lang.fr ? '↩︎ Original' : '↩︎ الأصل',
              onTap: () => setState(() {
                ex.translatedText = null;
                ex.translatedTo = null;
              }),
            ),
        ],
      ),
    );
  }

  void _pickTranslate(_Exchange ex, Lang lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSheet))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(lang == Lang.fr ? 'Traduire la réponse en…' : 'ترجم الجواب إلى…',
                style: Typo.style(size: Typo.base, weight: Typo.bold, color: C.midad)),
            const SizedBox(height: 6),
            for (final e in _kTargets.entries)
              ListTile(
                title: Text(e.value,
                    style: Typo.style(size: Typo.base, color: C.midad)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _translate(ex, e.key, lang);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _translate(_Exchange ex, String target, Lang lang) async {
    setState(() => ex.translating = true);
    try {
      final out = await _api.translate(ex.apiAnswer!.answer, target);
      if (!mounted) return;
      setState(() {
        ex.translatedText = out;
        ex.translatedTo = target;
        ex.translating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => ex.translating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang == Lang.fr
            ? 'Traduction indisponible, réessaie.'
            : 'الترجمة غير متاحة، أعد المحاولة.'),
      ));
    }
  }

  // --- #3 Modifier un message ---------------------------------------------

  /// Recharge le texte de la question dans le composer et supprime cet échange
  /// et tous les suivants (on repart de ce point de la conversation).
  void _showEditSheet(_Exchange ex, Lang lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSheet))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: C.midad),
              title: Text(lang == Lang.fr ? 'Modifier la question' : 'تعديل السؤال',
                  style: Typo.style(size: Typo.base, color: C.midad)),
              onTap: () {
                Navigator.of(ctx).pop();
                _startEdit(ex);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startEdit(_Exchange ex) {
    final i = _exchanges.indexOf(ex);
    if (i < 0) return;
    setState(() => _exchanges.removeRange(i, _exchanges.length));
    _input.text = ex.userText;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _inputFocus.requestFocus();
  }

  Widget _errorBubble(_Exchange ex, Lang lang, T t) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(text: ex.error!, isUser: false),
          const SizedBox(height: 8),
          ChwChip(
            label: lang == Lang.fr ? 'Réessayer' : 'عاود المحاولة',
            onTap: () {
              setState(() {
                ex.error = null;
                ex.thinking = true;
              });
              _retry(ex, lang);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _retry(_Exchange ex, Lang lang) async {
    try {
      final ans = await _api.ask(ex.userText, lang, history: _buildHistory());
      if (!mounted) return;
      setState(() {
        ex.apiAnswer = ans;
        ex.thinking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        ex.error = T(lang).netError;
        ex.thinking = false;
      });
    }
    _scrollToEnd();
  }

  // --- Rendu réponse scriptée (démo) ---------------------------------------

  List<Widget> _scenarioWidgets(Scenario sc, Lang lang, T t) {
    return [
      ChatBubble(text: sc.reply(lang), isUser: false),
      for (final s in sc.sources) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 36),
          child: SourceCard(
            num: s.num(lang),
            code: s.code(lang),
            excerpt: s.excerpt(lang),
            date: s.date(lang),
            unfold: true,
            onTap: () => showArticleSheet(context, source: s, appLang: lang),
          ),
        ),
      ],
      if (sc.banner != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 36),
          child: AlertBanner(
            title: sc.banner!.title(lang),
            body: sc.banner!.body(lang),
            actionLabel: t.findLawyer,
          ),
        ),
      ],
      if (sc.followUp != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ChwChip(label: sc.followUp!(lang), onTap: () {}),
        ),
      ],
      const SizedBox(height: 8),
      Text(T.sent,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: Typo.style(size: Typo.xs, color: C.midad30)),
    ];
  }

  Widget _starterChips(Lang lang) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: kScenarios.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Center(
          child: ChwChip(
            label: kScenarios[i].chip(lang),
            onTap: () => _onChip(kScenarios[i], lang),
          ),
        ),
      ),
    );
  }

  Widget _inputBar(T t, Lang lang) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: C.surfaceCard,
                  borderRadius: BorderRadius.circular(S.radiusPill),
                  border: Border.all(color: C.borderCard),
                  boxShadow: S.shadowSoft,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  cursorColor: C.nila,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitTyped(lang),
                  style: Typo.style(size: Typo.base, color: C.midad),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: InputBorder.none,
                    hintText: t.placeholder,
                    hintStyle: Typo.style(size: Typo.base, color: C.midad30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _submitTyped(lang),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: C.nila, shape: BoxShape.circle),
                child: const Center(
                  child: ChwIcon('send', size: 20, color: Colors.white, mirrorInRtl: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header du chat : fond nila, frise zellige blanche, wordmark, sélecteur.
class _ChatHeader extends StatelessWidget {
  final Lang lang;
  final ValueChanged<Lang> onLang;
  const _ChatHeader({required this.lang, required this.onLang});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.nila,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              const ZellijFrieze.onNila(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const LogoMark.warqa(size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('شاورني',
                              textDirection: TextDirection.rtl,
                              style: Typo.style(
                                  size: 18, weight: Typo.citation, color: Colors.white)),
                          Text('CHAWERNI',
                              style: Typo.style(
                                  size: 9,
                                  weight: Typo.medium,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                    LangSwitcher(value: lang, onChange: onLang, inverse: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
