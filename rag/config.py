"""Configuration centrale du cœur RAG Chawerni.

Chemins, variables d'environnement et constantes partagées par l'indexation,
le retrieval et le LLM. Aucune logique métier ici — juste les réglages.

Variables d'environnement (toutes optionnelles sauf la clé Groq pour le LLM) :
  QDRANT_URL    — si défini, on parle à un serveur Qdrant ; sinon mode local disque
  GROQ_API_KEY  — clé API Groq (requise pour rag.llm / rag.pipeline)
  GROQ_MODEL    — modèle Groq (défaut: llama-3.3-70b-versatile)
  BGE_MODEL     — modèle d'embedding (défaut: BAAI/bge-m3)

Un fichier `rag/.env` (git-ignoré) est chargé automatiquement s'il existe.
"""

import os
from pathlib import Path

# --- Chemins ---------------------------------------------------------------
ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
CHUNKS_DIR = PROJECT_ROOT / "corpus" / "chunks"
MANIFEST_PATH = PROJECT_ROOT / "corpus" / "manifest.json"
QDRANT_PATH = ROOT / ".qdrant"  # base Qdrant locale sur disque (mode dev)


def _load_dotenv() -> None:
    """Charge rag/.env (KEY=VALUE par ligne) dans os.environ sans dépendance."""
    env_file = ROOT / ".env"
    if not env_file.exists():
        return
    for raw in env_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        # L'environnement réel a priorité sur le fichier.
        os.environ.setdefault(key, value)


_load_dotenv()

# --- Qdrant ----------------------------------------------------------------
QDRANT_URL = os.environ.get("QDRANT_URL")  # None => mode local disque
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY")  # requis pour Qdrant Cloud
COLLECTION = "chawerni_articles"
DENSE_DIM = 1024  # dimension de sortie de BGE-M3
DENSE_VECTOR = "dense"
SPARSE_VECTOR = "sparse"

# --- Embedding -------------------------------------------------------------
BGE_MODEL = os.environ.get("BGE_MODEL", "BAAI/bge-m3")
EMBED_BATCH = 16
# Device d'inférence. Un seul device forcé => FlagEmbedding n'ouvre PAS de pool
# multiprocessing (qui deadlock sur macOS/MPS). Défaut « cpu » (lent mais stable) ;
# « mps » possible si l'inférence GPU Apple ne se bloque pas.
EMBED_DEVICE = os.environ.get("CHAWERNI_DEVICE", "cpu")
EMBED_MAX_LEN = 2048  # articles courts ; cap les rares très longs (ex. DOC)

# --- Retrieval -------------------------------------------------------------
TOP_K = 5  # nombre de résultats renvoyés par défaut (et k de precision@k)
PREFETCH_K = 20  # candidats par branche (dense / sparse) avant fusion RRF
# Le classement final vient de la fusion RRF (dense + sparse). Mais pour décider
# « aucun texte applicable » (question hors corpus), le score RRF est inadapté :
# la recherche dense renvoie toujours des voisins. On gate donc sur la similarité
# cosinus dense du meilleur résultat — sous ce seuil, on renvoie une liste vide.
# Calibré sur le jeu d'éval : la darija reformulée et le sémantique FR/AR vivent
# au-dessus de ~0,55 ; on place un plancher bas (0,50) qui n'écarte que le bruit
# évident. Le refus fin du hors-corpus est confié au LLM (sentinel INSUFFISANT),
# car cosinus darija (~0,53) et hors-corpus (~0,54) se recouvrent — aucun seuil
# ne les sépare proprement.
DENSE_SCORE_MIN = 0.50

# --- LLM (Groq) ------------------------------------------------------------
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
GROQ_BASE_URL = "https://api.groq.com/openai/v1"
# Modèle de génération des réponses (qualité) — défaut 70B.
GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
# Modèle « rapide » pour les tâches courtes (reformulation darija→fusha). Mesuré :
# le 8B reformule MIEUX pour le retrieval que le 70B (darija success@5 0,80 vs 0,60)
# et économise le quota quotidien du 70B (100k tokens/jour en free tier).
GROQ_MODEL_FAST = os.environ.get("GROQ_MODEL_FAST", "llama-3.1-8b-instant")

# --- Limite de débit /ask (protège le budget IA) ---------------------------
# Plafonds PAR IP. Volontairement plus hauts que le quota freemium de l'app
# (5/jour + bonus rewarded), pour qu'un utilisateur légitime ne soit jamais
# bloqué — seuls les abus / appels directs à l'API sont coupés.
ASK_MAX_PER_DAY = int(os.environ.get("ASK_MAX_PER_DAY", "60"))
ASK_MAX_PER_MIN = int(os.environ.get("ASK_MAX_PER_MIN", "12"))

# Noms présentables des codes (les citations doivent afficher le vrai nom, pas la
# clé interne « doc »). Utilisé par build_context.
CODE_NAMES = {
    "accidents_travail": "Loi sur les accidents du travail",
    "code_commerce": "Code de commerce",
    "code_penal": "Code pénal",
    "code_route": "Code de la route",
    "code_travail": "Code du travail",
    "constitution_2011": "Constitution 2011",
    "doc": "Code des obligations et des contrats",
    "droits_reels": "Code des droits réels",
    "immatriculation_fonciere": "Loi sur l'immatriculation foncière",
    "moudawana": "Moudawana (Code de la famille)",
    "organisation_judiciaire": "Loi sur l'organisation judiciaire",
    "procedure_penale": "Code de procédure pénale",
    "travailleurs_domestiques": "Loi sur les travailleurs domestiques",
}

# Noms arabes des codes (la version AR fait foi).
CODE_NAMES_AR = {
    "accidents_travail": "قانون حوادث الشغل",
    "code_commerce": "مدونة التجارة",
    "code_penal": "مجموعة القانون الجنائي",
    "code_route": "مدونة السير",
    "code_travail": "مدونة الشغل",
    "constitution_2011": "دستور المملكة 2011",
    "doc": "قانون الالتزامات والعقود",
    "droits_reels": "مدونة الحقوق العينية",
    "immatriculation_fonciere": "قانون التحفيظ العقاري",
    "moudawana": "مدونة الأسرة",
    "organisation_judiciaire": "قانون التنظيم القضائي",
    "procedure_penale": "قانون المسطرة الجنائية",
    "travailleurs_domestiques": "قانون العمال المنزليين",
}

# Accent par matière (couleurs de la Bibliothèque) : penal / famille / travail / civil.
CODE_ACCENT = {
    "accidents_travail": "travail",
    "code_commerce": "civil",
    "code_penal": "penal",
    "code_route": "civil",
    "code_travail": "travail",
    "constitution_2011": "civil",
    "doc": "civil",
    "droits_reels": "civil",
    "immatriculation_fonciere": "civil",
    "moudawana": "famille",
    "organisation_judiciaire": "civil",
    "procedure_penale": "penal",
    "travailleurs_domestiques": "travail",
}

# Tous les codes du corpus (clés du manifeste), pour la détection lexicale.
CODES = [
    "accidents_travail",
    "code_commerce",
    "code_penal",
    "code_route",
    "code_travail",
    "constitution_2011",
    "doc",
    "droits_reels",
    "immatriculation_fonciere",
    "moudawana",
    "organisation_judiciaire",
    "procedure_penale",
    "travailleurs_domestiques",
]
