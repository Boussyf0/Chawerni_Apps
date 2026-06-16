"""Orchestrateur RAG — retrieve → contexte → LLM, avec refus honnête.

`ask()` enchaîne le retriever hybride et le LLM Groq, et renvoie la réponse + les
sources structurées (pour les cartes cliquables de l'app). Si le retriever ne
trouve rien d'applicable, on NE PROMPTE PAS le LLM : on renvoie un refus honnête
dans la langue de la question (« je préfère te le dire que d'inventer »).

C'est l'entrée utilisée par l'éval et le test manuel. La vraie orchestration
HTTP + safety gates pré/post viendra dans le backend (Phase 3).

Usage :
  python3 -m rag.pipeline "Mes droits si je suis licencié ?"
  python3 -m rag.pipeline "شنو حقوقي إلا تفصلت من الخدمة؟"
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field

from . import config, llm
from .retrieve import RetrievedChunk, detect_darija, detect_langue, retrieve

# Refus honnête, par langue (la darija réutilise l'arabe dialectal).
_REFUSAL = {
    "fr": "Je n'ai pas trouvé de texte applicable à ta question dans mon corpus — "
          "je préfère te le dire que d'inventer. Reformule ou précise le domaine "
          "(travail, famille, pénal…).",
    "ar": "لم أجد نصاً قانونياً واضحاً على سؤالك في النصوص المتوفرة لدي — "
          "أفضّل أن أقول لك ذلك على أن أخترع. حاول إعادة الصياغة أو حدّد المجال.",
}


@dataclass
class Answer:
    """Réponse complète : texte + sources structurées + drapeau de refus."""

    answer: str
    sources: list[RetrievedChunk] = field(default_factory=list)
    refused: bool = False
    langue: str = "fr"

    def source_cards(self) -> list[dict]:
        """Métadonnées des cartes sources (pour l'app / l'API)."""
        return [
            {
                "code": s.payload.get("code"),
                "article_num": s.payload.get("article_num"),
                "marqueur": s.payload.get("marqueur"),
                "version": s.payload.get("version"),
                "langue": s.payload.get("langue"),
                "citation": s.citation,
            }
            for s in self.sources
        ]


def retrieve_smart(question: str, langue: str | None = None, code: str | None = None,
                   reformulate: bool = True,
                   history: list[dict] | None = None) -> tuple[list[RetrievedChunk], str]:
    """Retrieval avec mémoire de conversation + reformulation darija→fusha (LLM).

    Renvoie (chunks, question_autonome). Étapes :
      1. Si `history`, on résout la question de suivi en question AUTONOME (8B).
      2. En darija, on reformule cette question autonome en fusha pour le retrieval.
    La question autonome (langue d'origine) sert ensuite à la génération.
    Sans clé LLM, on retombe proprement sur la question brute.
    """
    langue = langue or detect_langue(question)
    standalone = question
    if history and config.GROQ_API_KEY:
        standalone = llm.contextualize_question(history, question)
    search_q = standalone
    if reformulate and detect_darija(question) and config.GROQ_API_KEY:
        search_q = llm.reformulate_darija(standalone)
    chunks = retrieve(search_q, langue="ar" if detect_langue(search_q) == "ar" else langue,
                      code=code)
    return chunks, standalone


def ask(question: str, langue: str | None = None, code: str | None = None,
        history: list[dict] | None = None) -> Answer:
    """Question → réponse sourcée, ou refus honnête si rien d'applicable.

    `history` (tours {role, content}) permet de résoudre les questions de suivi.
    """
    langue = langue or detect_langue(question)
    chunks, standalone = retrieve_smart(question, langue=langue, code=code, history=history)

    if not chunks:
        return Answer(answer=_REFUSAL.get(langue, _REFUSAL["ar"]),
                      sources=[], refused=True, langue=langue)

    # On génère sur la question AUTONOME (suivi résolu), dans la langue d'origine.
    messages = llm.build_messages(standalone, chunks)
    text = llm.get_provider().generate(messages).strip()

    # Sentinel : le LLM juge le contexte hors-sujet → refus honnête.
    if llm.INSUFFICIENT in text:
        return Answer(answer=_REFUSAL.get(langue, _REFUSAL["ar"]),
                      sources=[], refused=True, langue=langue)

    return Answer(answer=text, sources=chunks, refused=False, langue=langue)


def _cli() -> None:
    if len(sys.argv) < 2:
        sys.exit('Usage : python3 -m rag.pipeline "<question>"')
    question = " ".join(sys.argv[1:])
    res = ask(question)
    print(f"\n[{'REFUS' if res.refused else 'RÉPONSE'} · langue={res.langue}]\n")
    print(res.answer)
    if res.sources:
        print("\nSources :")
        for s in res.sources:
            print(f"  · {s.citation}  (score={s.score:.3f}, via={s.via})")


if __name__ == "__main__":
    _cli()
