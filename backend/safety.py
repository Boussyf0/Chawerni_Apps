"""Garde-fous Chawerni (loi 28-08 : information juridique, jamais conseil).

Deux passes encadrent le LLM :
  - PRÉ : détection d'enjeu personnel grave (pénal lourd, garde d'enfants,
    violence, divorce conflictuel) → on lève un drapeau pour afficher un bandeau
    « un avocat est indispensable » SANS bloquer l'information.
  - POST : vérification que chaque citation [Code, Article N°] présente dans la
    réponse existe bien dans les articles fournis au LLM. Une citation inventée
    est signalée (et la réponse dégradée vers « voir sources »).

Le disclaimer est systématique dans chaque réponse de l'API.
"""

from __future__ import annotations

import re

# Sujets à enjeu personnel grave → bandeau de redirection vers un professionnel.
_GRAVE_PATTERNS = [
    r"garde d['e]\s*enfant", r"حضانة", r"الحضانة",
    r"divorce", r"طلاق", r"تطليق",
    r"violence", r"viol\b", r"agress", r"عنف", r"اعتداء", r"اغتصاب",
    r"prison", r"سجن", r"حبس", r"معتقل",
    r"\bmeurtre\b", r"\bhomicide\b", r"قتل",
    r"pension aliment", r"نفقة",
    r"licenci", r"فصل تعسفي",  # licenciement : enjeu sérieux
]
_GRAVE_RE = re.compile("|".join(_GRAVE_PATTERNS), re.IGNORECASE)

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


def is_grave(question: str) -> bool:
    """Pré-gate : la question touche-t-elle un enjeu personnel grave ?"""
    return bool(_GRAVE_RE.search(question))


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
