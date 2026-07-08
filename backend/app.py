"""API HTTP Chawerni (FastAPI) — sert le cœur RAG aux clients mobiles.

Endpoints :
  GET  /health                      état + modèle + nombre d'articles indexés
  POST /ask                         question → réponse sourcée (+ gates de sécurité)
  GET  /sources/{code}/{article}    texte intégral d'un article (carte cliquable)
  POST /feedback                    signal anonyme (loi 09-08 : aucun contenu)

Journalisation loi 09-08 : on ne loggue JAMAIS le contenu des questions, seulement
des compteurs et latences. Disclaimer systématique (loi 28-08).
"""

from __future__ import annotations

import hashlib
import logging
import threading
import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, PlainTextResponse

from rag import config, embedding, llm, pipeline
from rag.retrieve import detect_langue, retrieve
from rag.store import get_client
from qdrant_client import models

from . import safety
from .schemas import (
    AskRequest,
    AskResponse,
    ArticleListItem,
    ArticleListResponse,
    ArticleResponse,
    CodeInfo,
    FeedbackRequest,
    HealthResponse,
    SourceCard,
    TranslateRequest,
    TranslateResponse,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("chawerni")


class _RateLimiter:
    """Limiteur par IP, en mémoire (process unique = un seul conteneur).

    Deux fenêtres : par jour (budget IA) et par minute (anti-burst/scraping). La
    clé est un HACHAGE de l'IP — on ne stocke ni ne loggue l'IP en clair (loi 09-08).
    L'état est volatile (reset au redémarrage), ce qui est acceptable ici.
    """

    def __init__(self, per_day: int, per_min: int):
        self.per_day = per_day
        self.per_min = per_min
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    @staticmethod
    def _key(ip: str) -> str:
        return hashlib.sha256(ip.encode()).hexdigest()[:16]

    def check(self, ip: str) -> tuple[bool, int]:
        """Retourne (autorisé, retry_after_secondes)."""
        now = time.time()
        key = self._key(ip)
        with self._lock:
            dq = self._hits[key]
            # purge > 24 h
            day_ago = now - 86400
            while dq and dq[0] < day_ago:
                dq.popleft()
            last_min = sum(1 for t in dq if t > now - 60)
            if last_min >= self.per_min:
                return False, 60
            if len(dq) >= self.per_day:
                return False, int(dq[0] + 86400 - now)
            dq.append(now)
            # garde la table bornée
            if len(self._hits) > 50000:
                for k in [k for k, v in self._hits.items() if not v]:
                    self._hits.pop(k, None)
            return True, 0


_ask_limiter = _RateLimiter(config.ASK_MAX_PER_DAY, config.ASK_MAX_PER_MIN)


def _client_ip(request: Request) -> str:
    """IP réelle du client, en tenant compte du reverse-proxy Caddy (XFF)."""
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Charge BGE-M3 au démarrage pour éviter la latence du 1er appel.
    log.info("Préchauffage BGE-M3…")
    embedding.embed_one("préchauffage")
    log.info("Modèle prêt. Collection=%s", config.COLLECTION)
    yield


app = FastAPI(title="Chawerni API", version="1.0",
              description="Assistant juridique RAG (droit marocain)", lifespan=lifespan)

# Mobile : pas d'origine web fixe → CORS ouvert (l'app native n'envoie pas d'Origin).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


import re

_PUNCT_SPACE = re.compile(r"\s+([،؛.,:!؟»])")
_OPEN_SPACE = re.compile(r"([«])\s+")


def _clean(texte: str) -> str:
    """Nettoyage d'affichage SÛR (sans toucher aux lettres) : espaces multiples
    réduits, espace avant ponctuation retiré. Les artefacts intra-mot et lam-alef
    de l'extraction AR relèvent d'un re-chunking (Phase 1), pas de l'affichage."""
    t = " ".join(texte.split())
    t = _PUNCT_SPACE.sub(r"\1", t)
    t = _OPEN_SPACE.sub(r"\1", t)
    return t.strip()


def _excerpt(texte: str, n: int = 180) -> str:
    t = _clean(texte)
    return t[:n] + ("…" if len(t) > n else "")


@app.get("/app-ads.txt", response_class=PlainTextResponse)
def app_ads_txt() -> str:
    """Fichier app-ads.txt AdMob (anti-fraude). Doit être servi à la racine du
    domaine « site développeur » déclaré sur le store. Sert ici via l'API au cas
    où ce domaine pointe vers le backend."""
    return "google.com, pub-8986402840311549, DIRECT, f08c47fec0942fa0\n"


_PRIVACY_HTML = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Chawerni — Politique de confidentialité / سياسة الخصوصية</title>
<style>body{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;max-width:760px;
margin:24px auto;padding:0 16px;line-height:1.6;color:#1a1a2e}h1{font-size:1.5rem}
h2{font-size:1.1rem;margin-top:1.6rem}.ar{direction:rtl;text-align:right}
small{color:#666}hr{margin:2rem 0;border:none;border-top:1px solid #ddd}</style></head><body>

<h1>Politique de confidentialité — Chawerni (شاورني)</h1>
<small>Dernière mise à jour : 16 juin 2026 · Contact : boussyf0@gmail.com</small>

<p>Chawerni est une application d'<strong>information juridique</strong> sur le droit
marocain. Elle ne fournit pas de conseil juridique personnalisé et ne remplace pas un
avocat.</p>

<h2>Données que nous NE collectons PAS</h2>
<p>L'application ne demande aucun compte. Nous ne collectons ni votre nom, ni votre
e-mail, ni votre numéro de téléphone, ni votre localisation précise.</p>

<h2>Vos questions</h2>
<p>Le texte de vos questions est envoyé à nos serveurs et à un prestataire d'IA tiers
uniquement pour générer la réponse. <strong>Nous ne stockons pas le contenu de vos
questions</strong> lié à votre identité ; nous ne conservons que des compteurs anonymes
(nombre de requêtes, latence) à des fins techniques.</p>

<h2>Données stockées sur votre appareil</h2>
<p>Vos préférences (langue, nombre de questions gratuites du jour) sont enregistrées
localement sur votre téléphone, et jamais transmises.</p>

<h2>Publicité</h2>
<p>Nous utilisons <strong>Google AdMob</strong> pour afficher des publicités. AdMob
peut collecter votre identifiant publicitaire et des informations sur votre appareil
pour diffuser des annonces. Voir la politique de Google :
<a href="https://policies.google.com/privacy">policies.google.com/privacy</a>. Vous
pouvez réinitialiser ou limiter la personnalisation des annonces dans les réglages
Android (Confidentialité → Annonces).</p>

<h2>Partage</h2>
<p>Nous ne vendons aucune donnée. Les seuls tiers impliqués sont nos prestataires
techniques (hébergement, IA, régie publicitaire) cités ci-dessus.</p>

<h2>Vos droits</h2>
<p>Pour toute question ou demande, écrivez à <strong>boussyf0@gmail.com</strong>.</p>

<hr>

<div class="ar">
<h1>سياسة الخصوصية — شاورني</h1>
<small>آخر تحديث: 16 يونيو 2026 · للتواصل: boussyf0@gmail.com</small>
<p>«شاورني» تطبيق <strong>للمعلومة القانونية</strong> حول القانون المغربي. لا يقدّم
استشارة قانونية شخصية ولا يعوّض المحامي.</p>
<h2>بيانات لا نجمعها</h2>
<p>لا يتطلب التطبيق أي حساب. لا نجمع اسمك ولا بريدك الإلكتروني ولا رقم هاتفك ولا
موقعك الدقيق.</p>
<h2>أسئلتك</h2>
<p>يُرسَل نص أسئلتك إلى خوادمنا وإلى مزوّد ذكاء اصطناعي خارجي فقط لإنشاء الجواب.
<strong>لا نخزّن محتوى أسئلتك</strong> مرتبطاً بهويتك؛ نحتفظ فقط بعدّادات مجهولة
(عدد الطلبات، زمن الاستجابة) لأغراض تقنية.</p>
<h2>بيانات على جهازك</h2>
<p>تُحفظ تفضيلاتك (اللغة، عدد الأسئلة المجانية اليومية) محلياً على هاتفك ولا تُرسَل
أبداً.</p>
<h2>الإعلانات</h2>
<p>نستعمل <strong>Google AdMob</strong> لعرض الإعلانات. قد يجمع AdMob معرّفك الإعلاني
ومعلومات عن جهازك لعرض الإعلانات. راجع سياسة Google. يمكنك إعادة ضبط أو تقييد تخصيص
الإعلانات من إعدادات أندرويد.</p>
<h2>المشاركة</h2>
<p>لا نبيع أي بيانات. الأطراف الوحيدة المعنية هي مزوّدو الخدمات التقنية المذكورون
أعلاه.</p>
<h2>حقوقك</h2>
<p>لأي سؤال أو طلب، راسلنا على <strong>boussyf0@gmail.com</strong>.</p>
</div>

</body></html>"""


@app.get("/privacy", response_class=HTMLResponse)
def privacy() -> str:
    """Politique de confidentialité (FR + AR) — URL requise par le Play Store."""
    return _PRIVACY_HTML


@app.get("/")
def root() -> dict:
    """Page racine amicale (la racine n'a pas de logique métier)."""
    return {
        "service": "Chawerni API",
        "status": "ok",
        "endpoints": ["/health", "/ask", "/codes",
                      "/codes/{code}/articles", "/sources/{code}/{article}", "/search"],
    }


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    try:
        count = get_client().count(collection_name=config.COLLECTION, exact=True).count
    except Exception as e:  # collection absente / Qdrant injoignable
        raise HTTPException(status_code=503, detail=f"Qdrant indisponible: {e}")
    return HealthResponse(status="ok", model=config.GROQ_MODEL,
                          collection=config.COLLECTION, points=count)


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest, request: Request) -> AskResponse:
    t0 = time.time()
    # Limite de débit par IP (protège le budget IA). 429 propre si dépassée.
    allowed, retry = _ask_limiter.check(_client_ip(request))
    if not allowed:
        log.info("rate-limit /ask atteint (retry=%ds)", retry)
        raise HTTPException(
            status_code=429,
            detail="Trop de questions pour aujourd'hui. Réessaie plus tard. "
                   "كثرت الأسئلة اليوم، عاود المحاولة لاحقاً.",
            headers={"Retry-After": str(max(retry, 1))},
        )
    # La langue de la QUESTION fait foi (disclaimer/refus/bandeau dans CETTE langue),
    # pas celle de l'UI envoyée par l'app — sinon une question AR a un disclaimer FR.
    langue = detect_langue(req.question)

    history = [{"role": t.role, "content": t.content} for t in req.history]
    result = pipeline.ask(req.question, langue=langue, code=req.code, history=history)

    # Enjeu grave : mots-clés + matière pénale en tête des sources (d'où l'appel
    # APRÈS pipeline.ask, quand result.sources est disponible).
    grave = safety.is_grave(req.question, result.sources)

    # Post-gate : aucune citation inventée hors des sources fournies.
    source_nums = {
        int(s.payload["num_int"])
        for s in result.sources
        if str(s.payload.get("num_int", "")).isdigit()
    }
    citations_ok, invented = safety.verify_citations(result.answer, source_nums)
    if invented:
        log.warning("citations inventées détectées: %s (sources réelles=%s)",
                    invented, sorted(source_nums))

    cards = [
        SourceCard(
            code=s.payload.get("code", ""),
            article_num=str(s.payload.get("article_num", "")),
            marqueur=s.payload.get("marqueur", ""),
            version=s.payload.get("version", ""),
            langue=s.payload.get("langue", ""),
            citation=s.citation,
            excerpt=_excerpt(s.payload.get("texte", "")),
        )
        for s in result.sources
    ]

    latency_ms = int((time.time() - t0) * 1000)
    # Loi 09-08 : compteurs/latence uniquement, jamais le texte de la question.
    log.info("ask lang=%s grave=%s refused=%s sources=%d citations_ok=%s latency=%dms",
             langue, grave, result.refused, len(cards), citations_ok, latency_ms)

    return AskResponse(
        answer=result.answer,
        sources=cards,
        refused=result.refused,
        grave=grave and not result.refused,
        lawyer_banner=safety.lawyer_banner_for(langue) if grave else None,
        disclaimer=safety.disclaimer_for(langue),
        langue=langue,
    )


@app.post("/translate", response_model=TranslateResponse)
def translate(req: TranslateRequest) -> TranslateResponse:
    """Traduit un texte (typiquement une réponse) vers fr|ar|darija|en.

    Les citations [Code, Article N°, date] sont préservées telles quelles. Aucun
    contenu n'est journalisé (loi 09-08), seulement la langue cible et la latence.
    """
    t0 = time.time()
    out = llm.translate_text(req.text, req.target)
    log.info("translate target=%s latency=%dms", req.target, int((time.time() - t0) * 1000))
    return TranslateResponse(text=out, target=req.target)


def _fetch_article(code: str, article: str, langue: str):
    """Récupère un article par son numéro EXACT (« 52 », « premier », « 19-1 »)."""
    conds = [
        models.FieldCondition(key="code", match=models.MatchValue(value=code)),
        models.FieldCondition(key="langue", match=models.MatchValue(value=langue)),
        models.FieldCondition(key="article_num", match=models.MatchValue(value=article)),
    ]
    points, _ = get_client().scroll(
        collection_name=config.COLLECTION,
        scroll_filter=models.Filter(must=conds), limit=1, with_payload=True)
    if points:
        return points[0].payload
    # Repli : match numérique (« 19-1 » → num_int 19) si le n° exact n'existe pas.
    base = str(article).split("-")[0]
    if base.isdigit():
        conds[-1] = models.FieldCondition(
            key="num_int", match=models.MatchValue(value=int(base)))
        points, _ = get_client().scroll(
            collection_name=config.COLLECTION,
            scroll_filter=models.Filter(must=conds), limit=1, with_payload=True)
        if points:
            return points[0].payload
    return None


@app.get("/sources/{code}/{article}", response_model=ArticleResponse)
def get_source(code: str, article: str, langue: str = "ar") -> ArticleResponse:
    """Texte intégral d'un article (carte source cliquable de l'app).

    Repli de langue : un code AR-only (code de la route, organisation judiciaire,
    accidents du travail) reste consultable même si l'app demande le FR.
    """
    other = "ar" if langue == "fr" else "fr"
    p = _fetch_article(code, article, langue) or _fetch_article(code, article, other)
    if not p:
        raise HTTPException(status_code=404, detail="Article introuvable")
    return ArticleResponse(
        code=p.get("code", ""),
        article_num=str(p.get("article_num", "")),
        marqueur=p.get("marqueur", ""),
        hierarchie=p.get("hierarchie", {}) or {},
        texte=_clean(p.get("texte", "")),
        version=p.get("version", ""),
        langue=p.get("langue", ""),
    )


_codes_cache: list[CodeInfo] | None = None


def _code_filter(code: str, langue: str) -> models.Filter:
    return models.Filter(must=[
        models.FieldCondition(key="code", match=models.MatchValue(value=code)),
        models.FieldCondition(key="langue", match=models.MatchValue(value=langue)),
    ])


@app.get("/codes", response_model=list[CodeInfo])
def list_codes() -> list[CodeInfo]:
    """Liste des 13 codes officiels (Bibliothèque) avec version et nb d'articles."""
    global _codes_cache
    if _codes_cache is not None:
        return _codes_cache
    client = get_client()
    out: list[CodeInfo] = []
    for code in config.CODES:
        # La version AR fait foi ; on lit une version + le nombre d'articles AR.
        pts, _ = client.scroll(collection_name=config.COLLECTION,
                               scroll_filter=_code_filter(code, "ar"),
                               limit=1, with_payload=True)
        if not pts:  # code AR absent (improbable) → essaie FR
            pts, _ = client.scroll(collection_name=config.COLLECTION,
                                   scroll_filter=_code_filter(code, "fr"),
                                   limit=1, with_payload=True)
        if not pts:
            continue
        langue = pts[0].payload.get("langue", "ar")
        version = pts[0].payload.get("version", "")
        count = client.count(collection_name=config.COLLECTION,
                             count_filter=_code_filter(code, langue), exact=True).count
        out.append(CodeInfo(
            code=code,
            titleFr=config.CODE_NAMES.get(code, code),
            titleAr=config.CODE_NAMES_AR.get(code, code),
            accent=config.CODE_ACCENT.get(code, "civil"),
            version=version,
            articles=count,
        ))
    _codes_cache = out
    return out


@app.get("/codes/{code}/articles", response_model=ArticleListResponse)
def list_articles(code: str, langue: str = "fr", offset: int = 0,
                  limit: int = 30) -> ArticleListResponse:
    """Parcours paginé des articles d'un code, triés par numéro."""
    limit = max(1, min(limit, 100))
    client = get_client()
    points, _ = client.scroll(collection_name=config.COLLECTION,
                              scroll_filter=_code_filter(code, langue),
                              limit=5000, with_payload=True)
    if not points:
        # Repli langue (codes AR-only consultables même en mode FR).
        langue = "ar" if langue == "fr" else "fr"
        points, _ = client.scroll(collection_name=config.COLLECTION,
                                  scroll_filter=_code_filter(code, langue),
                                  limit=5000, with_payload=True)
    if not points:
        raise HTTPException(status_code=404, detail="Code introuvable")
    points.sort(key=lambda p: p.payload.get("num_int") or 0)
    total = len(points)
    page = points[offset:offset + limit]
    items = [
        ArticleListItem(
            article_num=str(p.payload.get("article_num", "")),
            marqueur=p.payload.get("marqueur", ""),
            excerpt=_excerpt(p.payload.get("texte", ""), 140),
            version=p.payload.get("version", ""),
        )
        for p in page
    ]
    return ArticleListResponse(code=code, langue=langue, total=total,
                               offset=offset, limit=limit, articles=items)


@app.get("/search", response_model=list[SourceCard])
def search(q: str, code: str | None = None, langue: str | None = None,
           k: int = 8) -> list[SourceCard]:
    """Recherche d'articles (hybride RRF + court-circuit n°) dans un code ou global."""
    lang = langue or detect_langue(q)
    # Code AR-only (route, organisation judiciaire, accidents) : si la langue
    # demandée n'existe pas pour ce code, basculer sur la langue disponible.
    if code:
        pts, _ = get_client().scroll(collection_name=config.COLLECTION,
                                     scroll_filter=_code_filter(code, lang),
                                     limit=1, with_payload=False)
        if not pts:
            lang = "ar" if lang == "fr" else "fr"
    hits = retrieve(q, langue=lang, code=code, top_k=max(1, min(k, 20)))
    return [
        SourceCard(
            code=s.payload.get("code", ""),
            article_num=str(s.payload.get("article_num", "")),
            marqueur=s.payload.get("marqueur", ""),
            version=s.payload.get("version", ""),
            langue=s.payload.get("langue", ""),
            citation=s.citation,
            excerpt=_excerpt(s.payload.get("texte", "")),
        )
        for s in hits
    ]


@app.post("/feedback")
def feedback(req: FeedbackRequest) -> dict:
    # Aucun contenu : juste un compteur utile/inutile.
    log.info("feedback helpful=%s", req.helpful)
    return {"ok": True}
