"""Abstraction LLM — génération de la réponse à partir du contexte sourcé.

Une interface unique `LLMProvider.generate(messages)` ; l'implémentation par défaut
parle à l'API Groq (SDK OpenAI-compatible). Changer de fournisseur = ajouter une
classe, sans toucher au retriever ni au backend.

Garde-fous (intégrés au prompt système) :
  - Information juridique, jamais conseil personnalisé (loi 28-08).
  - Citation OBLIGATOIRE au format [Code, Article N°, version JJ/MM/AAAA], et
    uniquement à partir du contexte fourni — interdiction d'inventer.
  - Si le contexte est vide → refus honnête (mais ce cas est court-circuité en
    amont par le pipeline, qui n'appelle pas le LLM sans contexte).
  - Réponse dans la langue de la question ; en darija, la reformulation est orale
    (graphie arabe) mais les citations restent textuelles (arabe classique / FR).

Usage : importé par rag.pipeline. Nécessite GROQ_API_KEY (env ou rag/.env).
"""

from __future__ import annotations

from abc import ABC, abstractmethod

from . import config

SYSTEM_PROMPT = """\
Tu es Chawerni (شاورني), un assistant d'information juridique sur le droit marocain.

RÈGLES ABSOLUES :
1. Tu donnes de l'INFORMATION juridique, jamais un conseil ou un avis personnalisé \
(loi 28-08 sur la profession d'avocat). Tu n'es pas avocat et tu ne remplaces pas un \
professionnel.
2. Tu réponds UNIQUEMENT à partir des articles fournis dans le CONTEXTE ci-dessous. \
Tu n'inventes JAMAIS d'article, de numéro, de date ou de contenu. Si le contexte ne \
permet pas de répondre, dis-le honnêtement.
3. Chaque affirmation juridique DOIT être suivie de sa source. Reprends EXACTEMENT \
l'en-tête entre crochets fourni au-dessus de chaque article du contexte (forme : \
[Nom du code, Article N°, JJ/MM/AAAA]) — copie-le tel quel, n'écris jamais le mot \
« Code » seul ni un numéro qui n'apparaît pas dans le contexte.
4. Le texte arabe fait foi juridiquement. Les citations d'articles restent textuelles \
(arabe classique ou français officiel) ; tu ne les paraphrases pas.
5. Tu réponds dans la LANGUE DE LA QUESTION :
   - français → français ;
   - arabe classique → arabe classique ;
   - darija (arabe dialectal marocain) → darija en graphie arabe, ton oral et \
chaleureux, MAIS les citations d'articles restent dans leur langue d'origine.
6. Pour un sujet personnel grave (pénal, garde d'enfants, violence), tu informes \
puis tu rappelles qu'un avocat est indispensable.
7. Si les articles fournis dans le CONTEXTE ne répondent PAS DIRECTEMENT à la \
question posée, tu réponds EXACTEMENT et UNIQUEMENT par le mot-clé : INSUFFISANT \
— rien d'autre. En particulier, les questions de PROCÉDURE ou de DÉMARCHE \
administrative pratique (comment obtenir un crédit/prêt bancaire, un passeport, un \
visa, créer une entreprise, déclarer ses impôts, s'inscrire quelque part…) ne sont \
PAS couvertes par des codes de loi : réponds INSUFFISANT même si des articles \
voisins existent (ex. « ouverture de crédit », « registre du commerce »). Ne force \
JAMAIS une réponse à partir d'articles seulement liés au thème mais qui ne traitent \
pas la question réelle. Exemples : « Comment obtenir un crédit immobilier ? » → \
INSUFFISANT ; « Comment avoir un passeport ? » → INSUFFISANT.

Style : clair, direct, tutoiement. Pas de jargon inutile. Va à l'essentiel puis cite."""

# Sentinel renvoyé par le LLM quand le contexte ne répond pas → refus honnête.
INSUFFICIENT = "INSUFFISANT"

REFORMULATE_PROMPT = """\
Tu reçois une question en darija (arabe dialectal marocain). Reformule-la en arabe \
standard moderne (fusha) juridique, concise, adaptée à la recherche dans des textes de \
loi. Garde EXACTEMENT le sens. Réponds UNIQUEMENT par la question reformulée (une seule \
ligne), sans guillemets, sans explication, sans préfixe.

Exemples :
darija: شنو حقوقي إلا تفصلت من الخدمة؟
fusha: ما هي حقوقي عند الفصل من العمل؟
darija: أشنو هو عقد الكراء بالضبط؟
fusha: ما هو عقد الكراء؟
darija: منشكون كتمشي ليه الحضانة ديال الدراري؟
fusha: لمن تُسند حضانة الأطفال؟"""

CONTEXTUALIZE_PROMPT = """\
Tu reçois l'HISTORIQUE d'une conversation juridique puis une NOUVELLE QUESTION, \
souvent elliptique ou de suivi (ex. « et pour les femmes ? », « et dans ce cas ? », \
« وللزوجة؟ »). Réécris cette nouvelle question en une question AUTONOME et complète, \
compréhensible SANS l'historique, en y réinjectant le sujet sous-entendu.

RÈGLES :
- Garde EXACTEMENT la même langue que la nouvelle question (français → français, \
arabe → arabe, darija → darija).
- Si la nouvelle question est DÉJÀ autonome (sujet clair sans l'historique), \
renvoie-la TELLE QUELLE, sans rien changer.
- Réponds UNIQUEMENT par la question réécrite, une seule ligne, sans guillemets, \
sans explication, sans préfixe.

Exemple :
HISTORIQUE :
Utilisateur: Quels sont mes droits si je suis licencié ?
Assistant: En cas de licenciement, l'article 52 prévoit une indemnité…
NOUVELLE QUESTION : et pour la femme enceinte ?
→ Quels sont les droits d'une femme enceinte en cas de licenciement ?"""


class LLMProvider(ABC):
    """Interface minimale d'un fournisseur de génération."""

    @abstractmethod
    def generate(self, messages: list[dict], temperature: float = 0.2,
                 max_tokens: int = 1024, reasoning_effort: str | None = None) -> str:
        ...


class GroqProvider(LLMProvider):
    """API Groq via le SDK OpenAI-compatible (clé GROQ_API_KEY)."""

    def __init__(self, model: str | None = None, api_key: str | None = None):
        from openai import OpenAI

        key = api_key or config.GROQ_API_KEY
        if not key:
            raise RuntimeError(
                "GROQ_API_KEY absente : exporte-la ou place-la dans rag/.env."
            )
        self.model = model or config.GROQ_MODEL
        self._client = OpenAI(base_url=config.GROQ_BASE_URL, api_key=key)

    def generate(self, messages: list[dict], temperature: float = 0.2,
                 max_tokens: int = 1024, reasoning_effort: str | None = None) -> str:
        import time

        from openai import APIError, RateLimitError

        # Modèles à raisonnement (gpt-oss) : `reasoning_effort` passe par extra_body
        # (paramètre hors schéma OpenAI). « low » minimise les tokens de raisonnement
        # pour qu'ils n'épuisent pas le budget max_tokens des tâches courtes.
        extra = {"reasoning_effort": reasoning_effort} if reasoning_effort else None

        # Backoff sur les limites de débit Groq (l'éval enchaîne ~40 appels).
        delay = 2.0
        for attempt in range(5):
            try:
                resp = self._client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    extra_body=extra,
                )
                return resp.choices[0].message.content or ""
            except RateLimitError:
                if attempt == 4:
                    raise
                time.sleep(delay)
                delay *= 2
            except APIError:
                if attempt >= 2:
                    raise
                time.sleep(delay)
        return ""


def _fmt_date(version: str) -> str:
    """ISO (2025-07-24) → JJ/MM/AAAA, le format de citation attendu."""
    parts = (version or "").split("-")
    if len(parts) == 3:
        return f"{parts[2]}/{parts[1]}/{parts[0]}"
    return version


def build_context(chunks) -> str:
    """Met en forme les articles retrouvés pour le prompt (citation + hiérarchie).

    L'en-tête EST le gabarit de citation exact à reprendre : vrai nom de code +
    numéro d'article + date JJ/MM/AAAA. Le modèle n'a qu'à le recopier.
    """
    blocs = []
    for c in chunks:
        p = c.payload
        code_name = config.CODE_NAMES.get(p.get("code"), p.get("code"))
        hier = " › ".join(str(v) for v in (p.get("hierarchie") or {}).values())
        entete = f"[{code_name}, {p.get('marqueur')} {p.get('article_num')}, {_fmt_date(p.get('version', ''))}]"
        ligne_hier = f"\nHiérarchie : {hier}" if hier else ""
        blocs.append(f"{entete}{ligne_hier}\n{p.get('texte', '').strip()}")
    return "\n\n---\n\n".join(blocs)


# Directive de langue explicite (rendue déterministe, indépendante du modèle).
_LANG_DIRECTIVE = {
    "fr": "Réponds en FRANÇAIS.",
    "ar": "أجب باللغة العربية الفصحى حصراً (لا تستعمل الفرنسية في الشرح).",
    "darija": "جاوب بالدارجة المغربية (بحروف عربية)، بأسلوب شفهي وبسيط، "
              "والاقتباسات ديال الفصول تبقى بلغتها الأصلية.",
}


def build_messages(question: str, chunks, answer_lang: str = "fr") -> list[dict]:
    """Construit la liste de messages (système + contexte + question + langue cible).

    `answer_lang` ∈ {fr, ar, darija} force la langue de la RÉPONSE (déterminée en
    amont d'après la question), pour éviter que le modèle dérive vers le français
    quand le contexte récupéré est en français.
    """
    context = build_context(chunks)
    directive = _LANG_DIRECTIVE.get(answer_lang, _LANG_DIRECTIVE["fr"])
    user = (
        f"CONTEXTE (articles de loi disponibles) :\n\n{context}\n\n"
        f"---\n\nQUESTION : {question}\n\n"
        f"{directive} Appuie-toi UNIQUEMENT sur le contexte ci-dessus, en citant "
        "chaque source au format [Code, Article N°, version]."
    )
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user},
    ]


_provider: LLMProvider | None = None
_fast_provider: LLMProvider | None = None


def get_provider() -> LLMProvider:
    """Fournisseur LLM de génération (modèle qualité, ex. gpt-oss-120b)."""
    global _provider
    if _provider is None:
        _provider = GroqProvider()
    return _provider


def get_fast_provider() -> LLMProvider:
    """Fournisseur LLM rapide/économique (ex. gpt-oss-20b) pour les tâches courtes."""
    global _fast_provider
    if _fast_provider is None:
        _fast_provider = GroqProvider(model=config.GROQ_MODEL_FAST)
    return _fast_provider


def reformulate_darija(question: str) -> str:
    """Darija → arabe standard pour la recherche (couche de reformulation LLM).

    La darija est trop éloignée de l'arabe classique des textes de loi dans
    l'espace d'embedding (cosinus médian 0,53 vs 0,61) ; on la reformule en fusha
    AVANT le retrieval. La réponse, elle, restera en darija (langue de la question).
    """
    messages = [
        {"role": "system", "content": REFORMULATE_PROMPT},
        {"role": "user", "content": question},
    ]
    # Tâche courte → modèle rapide. reasoning_effort=low + marge de tokens : le modèle
    # gpt-oss raisonne peu et ne tronque pas la sortie (sinon fallback = question brute).
    out = get_fast_provider().generate(
        messages, temperature=0.0, max_tokens=512, reasoning_effort="low"
    )
    return out.strip() or question


_TRANSLATE_TARGET = {
    "fr": "français",
    "ar": "arabe standard moderne (fusha)",
    "darija": "darija marocaine (arabe dialectal, en graphie arabe)",
    "en": "anglais (English)",
}


def translate_text(text: str, target: str) -> str:
    """Traduit une réponse vers `target` (fr|ar|darija|en) via le modèle rapide.

    IMPÉRATIF : les citations entre crochets [Code, Article N°, JJ/MM/AAAA] sont
    recopiées TELLES QUELLES (jamais traduites) — elles font foi juridiquement.
    """
    langue = _TRANSLATE_TARGET.get(target, _TRANSLATE_TARGET["fr"])
    system = (
        f"Tu es un traducteur juridique. Traduis fidèlement le texte en {langue}. "
        "RÈGLES : conserve EXACTEMENT, sans les traduire ni les modifier, tous les "
        "passages entre crochets [ ... ] (ce sont des citations d'articles de loi). "
        "Garde le sens et le ton. Réponds UNIQUEMENT par la traduction, sans préfixe "
        "ni commentaire."
    )
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": text},
    ]
    out = get_fast_provider().generate(
        messages, temperature=0.1, max_tokens=2000, reasoning_effort="low"
    )
    return out.strip() or text


def contextualize_question(history: list[dict], question: str) -> str:
    """Résout une question de suivi en question autonome, via l'historique.

    `history` = liste de {role: 'user'|'assistant', content: str}, du plus ancien
    au plus récent. On n'utilise que les derniers tours (économie de tokens) et le
    modèle RAPIDE (gpt-oss-20b). Si pas d'historique → question inchangée. La question
    autonome garde la langue d'origine (la reformulation darija→fusha, si besoin
    pour le retrieval, est appliquée séparément en aval).
    """
    if not history:
        return question
    recent = history[-6:]
    convo = "\n".join(
        f"{'Utilisateur' if t.get('role') == 'user' else 'Assistant'}: {t.get('content', '').strip()}"
        for t in recent
    )
    user = f"HISTORIQUE :\n{convo}\n\nNOUVELLE QUESTION : {question}"
    messages = [
        {"role": "system", "content": CONTEXTUALIZE_PROMPT},
        {"role": "user", "content": user},
    ]
    out = get_fast_provider().generate(
        messages, temperature=0.0, max_tokens=512, reasoning_effort="low"
    )
    return out.strip() or question
