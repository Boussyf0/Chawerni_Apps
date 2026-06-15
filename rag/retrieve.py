"""Retriever hybride Chawerni.

Trois étages, dans l'ordre :
  1. Court-circuit lexical — si la requête nomme un article précis (« article 446 »,
     « الفصل 490 », « المادة 114 »), on va le chercher directement par payload
     (num_int + code éventuel). Une référence exacte ne doit jamais dépendre du
     hasard vectoriel.
  2. Hybride dense + sparse, fusion RRF (Qdrant Query API) — pour les questions
     sémantiques.
  3. Gate de pertinence — la similarité cosinus dense du meilleur résultat doit
     dépasser DENSE_SCORE_MIN, sinon on renvoie [] (le bot dira « je ne trouve pas
     de texte applicable » plutôt que d'inventer).

Filtre par langue (déduite de la requête : graphie arabe → ar, sinon fr), par code
et par version minimale.

Usage :
  python3 -m rag.retrieve "article 446 du code pénal"
  python3 -m rag.retrieve "ما حقوقي عند الفصل من العمل؟" --code code_travail
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass

from qdrant_client import models

from . import config, embedding
from .store import get_client

# --- détection de langue / d'article / de code -----------------------------

_ARABIC = re.compile(r"[؀-ۿ]")
_EASTERN = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

# « article 446 », « art. 19-1 », « المادة 114 », « الفصل 490 » (+ chiffres ar)
_ARTICLE_RE = re.compile(
    r"(?:article|art\.?|المادة|الفصل|الفصل\s+رقم|المادة\s+رقم)\s*"
    r"([0-9٠-٩]+(?:-[0-9٠-٩]+)?)",
    re.IGNORECASE,
)

# Mots-clés → code du manifeste, pour scoper une recherche.
_CODE_KEYWORDS: list[tuple[str, str]] = [
    ("code_penal", "pénal"), ("code_penal", "penal"), ("code_penal", "جنائي"),
    ("procedure_penale", "procédure pénale"), ("procedure_penale", "المسطرة الجنائية"),
    ("code_travail", "travail"), ("code_travail", "شغل"), ("code_travail", "الشغل"),
    ("moudawana", "famille"), ("moudawana", "moudawana"), ("moudawana", "الأسرة"),
    ("moudawana", "مدونة الأسرة"),
    ("doc", "obligations"), ("doc", "contrats"), ("doc", "الالتزامات"), ("doc", "العقود"),
    ("code_commerce", "commerce"), ("code_commerce", "التجارة"),
    ("constitution_2011", "constitution"), ("constitution_2011", "الدستور"),
    ("code_route", "route"), ("code_route", "السير"), ("code_route", "الطرق"),
    ("droits_reels", "droits réels"), ("droits_reels", "الحقوق العينية"),
    ("immatriculation_fonciere", "immatriculation"),
    ("immatriculation_fonciere", "التحفيظ العقاري"),
    ("organisation_judiciaire", "organisation judiciaire"),
    ("organisation_judiciaire", "التنظيم القضائي"),
    ("accidents_travail", "accidents du travail"),
    ("accidents_travail", "حوادث الشغل"),
    ("travailleurs_domestiques", "domestiques"),
    ("travailleurs_domestiques", "المنزليين"),
]


@dataclass
class RetrievedChunk:
    """Un article retrouvé : payload du chunk + score + provenance du match."""

    payload: dict
    score: float
    via: str  # "lexical" | "hybride"

    @property
    def citation(self) -> str:
        p = self.payload
        return f"[{p.get('code')}, {p.get('marqueur')} {p.get('article_num')}, {p.get('version')}]"


def detect_langue(query: str) -> str:
    return "ar" if _ARABIC.search(query) else "fr"


# Marqueurs distinctifs de la darija (graphie arabe) — déclenchent la
# reformulation vers l'arabe standard avant retrieval.
_DARIJA_MARKERS = (
    "شنو", "أشنو", "اشنو", "كيفاش", "واش", "ديال", "اللي", "بغيت", "علاش",
    "شحال", "منين", "كاين", "بزاف", "خصني", "دابا", "فين", "كيدير", "كيتدار",
    "كياخد", "كتمشي", "نبداو", "بحال بحال",
)


def detect_darija(query: str) -> bool:
    """Heuristique : présence d'un marqueur dialectal marocain."""
    return any(m in query for m in _DARIJA_MARKERS)


def detect_code(query: str) -> str | None:
    q = query.lower()
    for code, kw in _CODE_KEYWORDS:
        if kw.lower() in q:
            return code
    return None


_BARE_NUM = re.compile(r"^\s*([0-9٠-٩]+(?:-[0-9٠-٩]+)?)\s*$")


def detect_article_num(query: str) -> int | None:
    # Requête = juste un numéro (« 446 ») → c'est un numéro d'article.
    bare = _BARE_NUM.match(query)
    m = bare or _ARTICLE_RE.search(query)
    if not m:
        return None
    raw = m.group(1).translate(_EASTERN)
    # On gate sur l'entier de base (num_int) ; « 19-1 » → 19.
    base = raw.split("-")[0]
    try:
        return int(base)
    except ValueError:
        return None


def _build_filter(langue: str | None, code: str | None, min_version: str | None):
    must: list = []
    if langue:
        must.append(models.FieldCondition(key="langue", match=models.MatchValue(value=langue)))
    if code:
        must.append(models.FieldCondition(key="code", match=models.MatchValue(value=code)))
    if min_version:
        from datetime import date

        must.append(
            models.FieldCondition(
                key="version",
                range=models.DatetimeRange(gte=date.fromisoformat(min_version)),
            )
        )
    return models.Filter(must=must) if must else None


# --- étages ----------------------------------------------------------------


def _lexical(client, num_int: int, langue: str, code: str | None) -> list[RetrievedChunk]:
    flt = _build_filter(langue, code, None)
    conds = list(flt.must) if flt else []
    conds.append(models.FieldCondition(key="num_int", match=models.MatchValue(value=num_int)))
    points, _ = client.scroll(
        collection_name=config.COLLECTION,
        scroll_filter=models.Filter(must=conds),
        limit=10,
        with_payload=True,
    )
    return [RetrievedChunk(payload=p.payload, score=1.0, via="lexical") for p in points]


def _hybrid(client, query: str, langue: str, code: str | None, min_version: str | None,
            top_k: int) -> tuple[list[RetrievedChunk], float]:
    emb = embedding.embed_one(query)
    flt = _build_filter(langue, code, min_version)
    sparse = models.SparseVector(indices=emb.sparse_indices, values=emb.sparse_values)

    # Classement final : fusion RRF des deux branches.
    fused = client.query_points(
        collection_name=config.COLLECTION,
        prefetch=[
            models.Prefetch(query=emb.dense, using=config.DENSE_VECTOR,
                            limit=config.PREFETCH_K, filter=flt),
            models.Prefetch(query=sparse, using=config.SPARSE_VECTOR,
                            limit=config.PREFETCH_K, filter=flt),
        ],
        query=models.FusionQuery(fusion=models.Fusion.RRF),
        limit=top_k,
        with_payload=True,
    ).points

    # Gate de pertinence : meilleure similarité cosinus dense (score borné [0,1]).
    dense_hits = client.query_points(
        collection_name=config.COLLECTION,
        query=emb.dense,
        using=config.DENSE_VECTOR,
        query_filter=flt,
        limit=1,
        with_payload=False,
    ).points
    best_cosine = dense_hits[0].score if dense_hits else 0.0

    results = [RetrievedChunk(payload=p.payload, score=p.score, via="hybride") for p in fused]
    return results, best_cosine


def retrieve(query: str, langue: str | None = None, code: str | None = None,
             min_version: str | None = None, top_k: int = config.TOP_K) -> list[RetrievedChunk]:
    """Retrouve les articles pertinents pour une question. [] si rien d'applicable."""
    client = get_client()
    langue = langue or detect_langue(query)
    code = code or detect_code(query)

    # 1. Court-circuit lexical sur numéro d'article explicite.
    num = detect_article_num(query)
    if num is not None:
        hits = _lexical(client, num, langue, code)
        if hits:
            return hits[:top_k]

    # 2. Hybride + 3. gate de pertinence.
    results, best_cosine = _hybrid(client, query, langue, code, min_version, top_k)
    if best_cosine < config.DENSE_SCORE_MIN:
        return []
    return results


def _cli() -> None:
    args = sys.argv[1:]
    if not args:
        sys.exit('Usage : python3 -m rag.retrieve "<question>" [--code <code>] [--lang fr|ar]')
    code = None
    langue = None
    if "--code" in args:
        i = args.index("--code"); code = args[i + 1]; del args[i : i + 2]
    if "--lang" in args:
        i = args.index("--lang"); langue = args[i + 1]; del args[i : i + 2]
    query = " ".join(args)
    hits = retrieve(query, langue=langue, code=code)
    if not hits:
        print("∅  Aucun texte applicable trouvé (le bot répondrait par un refus honnête).")
        return
    print(f"{len(hits)} résultat(s) pour : {query}\n")
    for i, h in enumerate(hits, 1):
        p = h.payload
        texte = p.get("texte", "")[:160].replace("\n", " ")
        print(f"{i}. {h.citation}  (score={h.score:.3f}, via={h.via})")
        print(f"   {texte}…\n")


if __name__ == "__main__":
    _cli()
