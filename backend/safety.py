"""Garde-fous Chawerni (loi 28-08 : information juridique, jamais conseil).

Deux passes encadrent le LLM :
  - GRAVE : détection d'enjeu personnel grave (mort/violence, pénal, garde
    d'enfants, nafaqa) → on lève un drapeau pour afficher un bandeau « un avocat
    est indispensable » SANS bloquer l'information. Hybride : regex sur la question
    + signal issu du retrieval (matière pénale en tête des sources) — ce dernier
    rattrape les cas décrits sans le mot-clé exact (ex. « ...وهو مات » = homicide).
  - POST : vérification que chaque citation [Code, Article N°] présente dans la
    réponse existe bien dans les articles fournis au LLM. Une citation inventée
    est signalée (et la réponse dégradée vers « voir sources »).

Le disclaimer est systématique dans chaque réponse de l'API.
"""

from __future__ import annotations

import re

# Sujets à enjeu personnel grave → bandeau de redirection vers un professionnel.
# NB : `divorce` et `licenciement` retirés (souvent questions purement informatives
# → sur-déclenchaient le bandeau) ; l'enjeu réel garde d'enfants / nafaqa / violence
# reste couvert par ses propres motifs. La matière pénale est rattrapée par le
# signal des sources dans is_grave() (voir plus bas).
_GRAVE_PATTERNS = [
    r"garde d['e]\s*enfant", r"حضانة", r"الحضانة",
    r"violence", r"viol\b", r"agress", r"عنف", r"اعتداء", r"اغتصاب",
    r"prison", r"سجن", r"حبس", r"معتقل",
    r"\bmeurtre\b", r"\bhomicide\b", r"قتل",
    # Mort / décès : un homicide peut être décrit sans le verbe « tuer / قتل ».
    r"\btu[eé]", r"\bmort", r"décès",
    r"\bمات", r"ماتت", r"يموت", r"الموت", r"وفاة", r"توفّ?[يى]",
    r"pension aliment", r"نفقة",
]
_GRAVE_RE = re.compile("|".join(_GRAVE_PATTERNS), re.IGNORECASE)

# Matières où toute question personnelle justifie le bandeau avocat : si le meilleur
# résultat du retrieval en relève, on lève le drapeau même sans mot-clé (sur-inclusion
# = direction d'erreur sûre pour un sujet pénal / procédure pénale).
_GRAVE_CODES = {"code_penal", "procedure_penale"}

# Citations dans la réponse : [..., Article 446, ...] / [..., المادة 114, ...]
_CITATION_RE = re.compile(r"\[[^\]]*?(?:article|art\.?|المادة|الفصل)\s*([0-9٠-٩]+)[^\]]*?\]",
                          re.IGNORECASE)
_EASTERN = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

DISCLAIMER = {
    "fr": "Information juridique, pas un avis personnalisé. Pour une décision "
          "importante, consulte un avocat ou un professionnel agréé.",
    "ar": "معلومة قانونية، وليست استشارة شخصية. لقرار مهم، استشر محامياً أو مهنياً معتمداً.",
}

LAWYER_BANNER = {
    "fr": "Ce sujet est sensible. Pour ta situation précise, un avocat est indispensable.",
    "ar": "هذا الموضوع حساس. لوضعيتك بالذات، المحامي ضروري.",
}


def is_grave(question: str, sources=None) -> bool:
    """La question touche-t-elle un enjeu personnel grave ? (bandeau avocat)

    Hybride : (1) mots-clés dans la question, (2) matière pénale en tête des
    `sources` retrouvées (rattrape les cas paraphrasés sans mot-clé). `sources`
    est une liste de RetrievedChunk (payload["code"]) ; optionnel (rétro-compat :
    sur un refus, la liste est vide → seul le regex s'applique).
    """
    if _GRAVE_RE.search(question):
        return True
    if sources:
        top_code = sources[0].payload.get("code")
        if top_code in _GRAVE_CODES:
            return True
    return False


def verify_citations(answer: str, source_article_nums: set[int]) -> tuple[bool, list[int]]:
    """Post-gate : toutes les citations de la réponse sont-elles dans le contexte ?

    Renvoie (toutes_valides, liste_des_numéros_inventés).
    """
    invented: list[int] = []
    for m in _CITATION_RE.findall(answer):
        digits = m.translate(_EASTERN)
        if not digits.isdigit():
            continue
        if int(digits) not in source_article_nums:
            invented.append(int(digits))
    return (len(invented) == 0, invented)


def disclaimer_for(langue: str) -> str:
    return DISCLAIMER.get(langue, DISCLAIMER["ar"])


def lawyer_banner_for(langue: str) -> str:
    return LAWYER_BANNER.get(langue, LAWYER_BANNER["ar"])
