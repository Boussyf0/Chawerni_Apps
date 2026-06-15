"""Évaluation chiffrée du cœur RAG — la gate avant la Phase 3.

Lit `dataset.jsonl` (50 questions FR + AR : exact / semantic / darija /
out_of_corpus) et mesure :

  RETRIEVER (sur les questions « in-corpus », expected non vide) :
    - success@5  : au moins un article attendu apparaît dans le top-5.
      ⚠ C'EST LA GATE. « precision@5 ≥ 0,8 » au sens du plan = au moins une
      source correcte dans le top-5 pour ≥ 80 % des questions. (La précision
      brute relevant/5 est bornée par le nombre d'articles pertinents — souvent
      1 — donc non pertinente comme gate ; on la rapporte quand même.)
    - precision@5 / recall@5 / MRR : rapportés pour information, par type.

  REFUS (questions out_of_corpus) :
    - refusal_accuracy : le retriever renvoie bien une liste vide.

  LLM (si GROQ_API_KEY ; sinon ignoré, ou --retriever-only) :
    - citation_rate : parmi les numéros d'articles cités dans la réponse,
      fraction qui existe réellement dans le contexte fourni (zéro invention).

Sortie : rapport lisible + code retour 1 si success@5 < SEUIL.

Usage :
  python3 -m rag.eval.eval                 # gate complète (retriever + LLM si clé)
  python3 -m rag.eval.eval --retriever-only
  python3 -m rag.eval.eval --llm-sample 12 # n'évalue le LLM que sur N questions
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

from .. import config
from ..pipeline import retrieve_smart

GATE_SUCCESS_AT_5 = 0.80
DATASET = Path(__file__).resolve().parent / "dataset.jsonl"

# Extraction des numéros d'article cités dans une réponse LLM.
_CITE_NUM = re.compile(r"(?:article|art\.?|المادة|الفصل)\s*([0-9٠-٩]+)", re.IGNORECASE)
_EASTERN = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def load_dataset() -> list[dict]:
    return [json.loads(l) for l in DATASET.read_text(encoding="utf-8").splitlines() if l.strip()]


def expected_set(item: dict) -> set[tuple[str, int]]:
    return {(e["code"], int(e["article"])) for e in item["expected"]}


def retrieved_pairs(hits) -> list[tuple[str, int]]:
    out = []
    for h in hits:
        p = h.payload
        try:
            out.append((p.get("code"), int(p.get("num_int"))))
        except (TypeError, ValueError):
            continue
    return out


def eval_retriever(data: list[dict]) -> dict:
    by_type: dict[str, list] = defaultdict(list)
    in_corpus_success: list[int] = []
    refusal_ok: list[int] = []
    failures: list[dict] = []

    for item in data:
        hits, _ = retrieve_smart(item["question"], langue=item.get("langue"))
        pairs = retrieved_pairs(hits)[: config.TOP_K]
        t = item["type"]

        if t == "out_of_corpus":
            ok = 1 if len(hits) == 0 else 0
            refusal_ok.append(ok)
            if not ok:
                failures.append({"id": item["id"], "type": t,
                                 "q": item["question"], "got": pairs})
            continue

        exp = expected_set(item)
        relevant_in_top = [p for p in pairs if p in exp]
        success = 1 if relevant_in_top else 0
        precision = len(relevant_in_top) / config.TOP_K
        recall = len({p for p in relevant_in_top}) / len(exp) if exp else 0.0
        # MRR : rang du premier pertinent.
        rr = 0.0
        for rank, p in enumerate(pairs, 1):
            if p in exp:
                rr = 1.0 / rank
                break

        by_type[t].append((success, precision, recall, rr))
        in_corpus_success.append(success)
        if not success:
            failures.append({"id": item["id"], "type": t, "q": item["question"],
                             "expected": sorted(exp), "got": pairs})

    return {
        "by_type": by_type,
        "success@5": _mean(in_corpus_success),
        "refusal_accuracy": _mean(refusal_ok),
        "n_in_corpus": len(in_corpus_success),
        "n_refusal": len(refusal_ok),
        "failures": failures,
    }


def eval_llm(data: list[dict], sample: int | None) -> dict | None:
    if not config.GROQ_API_KEY:
        return None
    from ..pipeline import ask

    in_corpus = [d for d in data if d["type"] != "out_of_corpus"]
    if sample:
        in_corpus = in_corpus[:sample]

    total_cites = 0
    valid_cites = 0
    answered = 0
    cited_expected = 0
    for item in in_corpus:
        res = ask(item["question"], langue=item.get("langue"))
        if res.refused:
            continue
        answered += 1
        context_nums = {int(s.payload.get("num_int")) for s in res.sources
                        if str(s.payload.get("num_int")).isdigit()}
        cited = {int(m.translate(_EASTERN)) for m in _CITE_NUM.findall(res.answer)
                 if m.translate(_EASTERN).isdigit()}
        for c in cited:
            total_cites += 1
            if c in context_nums:
                valid_cites += 1
        exp_nums = {a["article"] for a in item["expected"]}
        if cited & exp_nums:
            cited_expected += 1

    # Refus honnête de bout en bout sur le hors-corpus (retrieval vide OU sentinel
    # INSUFFISANT du LLM).
    ooc = [d for d in data if d["type"] == "out_of_corpus"]
    refused_ok = sum(1 for d in ooc if ask(d["question"], langue=d.get("langue")).refused)

    return {
        "answered": answered,
        "n": len(in_corpus),
        "citation_rate": (valid_cites / total_cites) if total_cites else None,
        "total_citations": total_cites,
        "answer_cites_expected_rate": (cited_expected / answered) if answered else None,
        "refusal_accuracy_pipeline": refused_ok / len(ooc) if ooc else None,
        "n_ooc": len(ooc),
    }


def _mean(xs: list[int]) -> float:
    return sum(xs) / len(xs) if xs else 0.0


def main() -> None:
    args = sys.argv[1:]
    retriever_only = "--retriever-only" in args
    sample = None
    if "--llm-sample" in args:
        sample = int(args[args.index("--llm-sample") + 1])

    data = load_dataset()
    print(f"Jeu d'évaluation : {len(data)} questions\n")

    r = eval_retriever(data)
    print("═══ RETRIEVER ═══")
    print(f"{'type':<14}{'n':>4}{'success@5':>11}{'prec@5':>9}{'recall@5':>10}{'MRR':>7}")
    for t in ("exact", "semantic", "darija"):
        rows = r["by_type"].get(t, [])
        if not rows:
            continue
        s = _mean([x[0] for x in rows])
        p = _mean([x[1] for x in rows])
        rc = _mean([x[2] for x in rows])
        mrr = _mean([x[3] for x in rows])
        print(f"{t:<14}{len(rows):>4}{s:>11.2f}{p:>9.2f}{rc:>10.2f}{mrr:>7.2f}")
    print(f"\nGLOBAL in-corpus ({r['n_in_corpus']} q) : success@5 = {r['success@5']:.3f}")
    print(f"REFUS out_of_corpus ({r['n_refusal']} q) : refusal_accuracy = {r['refusal_accuracy']:.3f}")

    if r["failures"]:
        print(f"\n  Échecs ({len(r['failures'])}) :")
        for f in r["failures"]:
            if f["type"] == "out_of_corpus":
                print(f"   #{f['id']} [{f['type']}] aurait dû refuser : {f['q'][:50]} → {f['got'][:3]}")
            else:
                print(f"   #{f['id']} [{f['type']}] {f['q'][:50]}")
                print(f"        attendu {f['expected']} · obtenu {f['got'][:5]}")

    if not retriever_only:
        llm = eval_llm(data, sample)
        print("\n═══ LLM (Groq) ═══")
        if llm is None:
            print("  (GROQ_API_KEY absente → évaluation LLM ignorée. "
                  "Exporte la clé ou utilise rag/.env.)")
        else:
            cr = llm["citation_rate"]
            ae = llm["answer_cites_expected_rate"]
            print(f"  réponses générées      : {llm['answered']}/{llm['n']}")
            print(f"  citations totales      : {llm['total_citations']}")
            print(f"  citation_rate (no hallu): {cr:.3f}" if cr is not None else
                  "  citation_rate          : n/a (aucune citation)")
            print(f"  réponse cite l'attendu  : {ae:.3f}" if ae is not None else "")
            rap = llm.get("refusal_accuracy_pipeline")
            if rap is not None:
                print(f"  refus hors-corpus (pipeline) : {rap:.3f} sur {llm['n_ooc']} q")

    # --- GATE ---
    # La darija n'est correctement servie qu'APRÈS reformulation LLM (décision du
    # plan : darija = couche LLM). Sans clé Groq, on ne peut pas la reformuler, donc
    # on évalue la gate du retriever sur FR/AR (exact + semantic) ; avec clé, la
    # darija reformulée entre dans le périmètre de la gate.
    def success_for(types: tuple[str, ...]) -> tuple[float, int]:
        rows = [x for t in types for x in r["by_type"].get(t, [])]
        return (_mean([x[0] for x in rows]), len(rows))

    has_key = bool(config.GROQ_API_KEY)
    gate_types = ("exact", "semantic", "darija") if has_key else ("exact", "semantic")
    gate_success, gate_n = success_for(gate_types)

    print("\n═══ GATE ═══")
    scope = "FR/AR + darija reformulée" if has_key else "FR/AR (darija nécessite la clé Groq)"
    passed = gate_success >= GATE_SUCCESS_AT_5
    verdict = "✅ PASS" if passed else "❌ FAIL"
    print(f"  périmètre : {scope} ({gate_n} questions)")
    print(f"  success@5 = {gate_success:.3f}  (seuil ≥ {GATE_SUCCESS_AT_5})  → {verdict}")
    if not has_key:
        print("  (darija hors gate : exporte GROQ_API_KEY pour l'inclure)")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
