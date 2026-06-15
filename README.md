# Chawerni (شاورني)

Assistant juridique IA pour le droit marocain — chatbot RAG qui répond en
citant les articles de loi exacts (FR / AR / darija), basé exclusivement sur
les textes officiels consolidés (Adala, SGG).

## Principes non négociables

1. **RAG, pas fine-tuning** : chaque réponse cite l'article source vérifiable.
   Si le retriever ne trouve rien (score < seuil), le bot dit « je ne trouve
   pas de texte applicable » au lieu d'inventer.
2. **Information juridique, jamais conseil juridique** (loi 28-08 sur la
   profession d'avocat) : disclaimer permanent + redirection vers un
   professionnel pour les enjeux personnels graves.
3. **Le texte arabe fait foi** ; le français sert le retrieval multilingue.
4. **Versionnage du corpus** : un consultant qui cite une loi abrogée est mort
   professionnellement. Chaque chunk porte sa date de consolidation.
5. **Loi 09-08** : pas de données personnelles dans les logs ; hébergement des
   données utilisateurs au Maroc.

## Structure

```
corpus/
  manifest.json            # source de vérité : les textes du corpus + URLs officielles
  registry.json            # SHA-256 par fichier — hash modifié = ré-indexer
  adala_inventory_fr.json  # inventaire complet Adala FR (557 fichiers)
  adala_inventory_ar.json  # inventaire complet Adala AR (4 254 fichiers)
  raw/                     # PDFs téléchargés (23 fichiers, ~106 Mo)
  chunks/                  # 1 chunk = 1 article (JSONL, ~11 000 chunks FR+AR)
  scripts/
    crawl_adala.py         # re-crawle l'arborescence Adala (URLs à timestamps changeants)
    download_corpus.py     # télécharge + valide %PDF + met à jour le registre
    normalize_ar.py        # normalisation arabe (ligatures lam-alef, chiffres, NFKC)
    chunk_codes.py         # chunking par article (chaîne monotone DP + raccordement)
    validate_chunks.py     # contrôle qualité (continuité, FR/AR, longueurs)
docs/                      # → voir docs/README.md (index)
  architecture.md          # diagrammes de tous les pipelines (Mermaid)
  plan.md                  # plan complet phases 1b → 5 + gates
  structure.md             # arborescence actuelle et cible
  etat_des_lieux_corpus_juridique.md  # périmètre du corpus, tiers, points de veille
```

## État du corpus (Tier 1 — 13 textes)

Les 10 codes + 3 annexes regroupées dans les livres imprimés équivalents :
immatriculation foncière (dahir 1913 / loi 14-07), travailleurs domestiques
(loi 19-12), accidents du travail (loi 18-12). AR complet (13/13, Adala
consolidé). FR : 10/13 ; manquent le code de la route FR consolidé, la loi
38-15 FR et la loi 18-12 FR (voir notes `A_COMPLETER` dans le manifeste).
Tous les PDFs ont une couche texte native — pas d'OCR nécessaire.

⚠️ Veille active : réforme Moudawana (2024-…), loi 03-23 (procédure pénale),
projet de loi santé/sécurité au travail.

## Workflow de mise à jour (Phase 5)

```bash
python3 corpus/scripts/crawl_adala.py 338 fr   # ré-inventorier (FR)
python3 corpus/scripts/crawl_adala.py 1 ar     # ré-inventorier (AR)
python3 corpus/scripts/download_corpus.py      # re-télécharger + comparer les hash
```

Un `⚠️ HASH MODIFIÉ` dans la sortie = nouvelle consolidation publiée → relancer
le chunking et la ré-indexation Qdrant pour ce texte.

## Chunking (Phase 1b) — pièges résolus, à connaître avant de modifier

1. **Sélection des en-têtes par plus longue chaîne croissante (DP)** : les
   références croisées (« المنصوص عليها في المادة 23 ») matchent le même
   pattern que les en-têtes ; seule la monotonie 1,2,3… les départage. Une
   approche gloutonne saute trop loin et tronque le document.
2. **Raccordement préfixe/suffixe** : une page déplacée dans le flux coupe la
   chaîne (DOC : articles 325-334 déplacés → 1-334 perdus sans le stitching).
3. **Appels de note collés aux numéros** (`Article 19⁷` → « 197 ») : chaque
   candidat numérique génère des variantes tronquées, la chaîne choisit.
4. **Jamais de suppression des lignes de chiffres nus** : l'extraction RTL
   isole des valeurs du texte (« رصيد من ⏎20⏎ نقطة ») sur leur propre ligne.
5. **PDF à couche texte en miroir** (ordre visuel) : fallback pdfminer avec
   réversion ligne par ligne au score de vraisemblance arabe.
6. **Le PDF Adala du Code du travail AR est inexploitable** (texte brouillé
   mixte) : remplacé par le PDF propre du ministère du travail (miepeec.gov.ma),
   cf. note dans manifest.json.
7. Trous légitimes (abrogations, identiques FR et AR) : pénal 19-23 et
   289-291 ; DOC 325-334 ; immatriculation 2-5. Documentés par
   validate_chunks.py.

## Roadmap

- [x] Phase 1a — Corpus Tier 1 téléchargé (FR+AR) avec registre de versions
- [x] Phase 1b — Chunking par article : 10 973 chunks, validation 0 erreur,
      spot-check 12/12 articles connus
- [ ] Phase 2 — Indexation Qdrant hybride (BGE-M3 dense + sparse + RRF)
- [ ] Phase 3 — Backend FastAPI + safety gates + disclaimers
- [ ] Phase 4 — App Flutter (chat, sources cliquables, RTL, mode hors-ligne)
- [ ] Phase 5 — Veille B.O. hebdomadaire + ré-indexation versionnée
