# État des lieux de l'arsenal juridique marocain — référence corpus Chawerni

> Source : rapport de recherche (juin 2026) sur les codes fondamentaux et textes
> consolidés publiés par le SGG et le Ministère de la Justice (Adala).
> Rôle dans le projet : définir le **périmètre du corpus RAG** et sa priorisation.
> Les affirmations de ce document doivent être re-vérifiées contre la version
> consolidée la plus récente avant indexation (les lois citées sont amendées
> régulièrement — cf. registre de versions dans `corpus/registry.json`).

## 1. Droit constitutionnel et électoral

- **Constitution 2011** — socle de tout le corpus.
- **LO 27-11** (Chambre des Représentants, mod. LO 04-21 et 20-16) : 395 membres
  (305 circonscriptions locales + 90 régionales), scrutin proportionnel au plus
  fort reste ; listes régionales ≥ 2/3 de candidates, deux premières places
  réservées aux femmes ; inéligibilité des magistrats, gouverneurs, militaires ;
  cautionnement 5 000 DH (remboursé si ≥ 5 % des suffrages).
- **LO 28-11** (Chambre des Conseillers) : 120 membres (72 collectivités
  territoriales, 20 chambres professionnelles, 8 employeurs, 20 salariés) ;
  art. 13 bis : déchéance en cas de transhumance politique.
- **LO 59-11** (élections des collectivités territoriales) : mandat 6 ans,
  protocole de vote anti-fraude (double cadenas, isoloir, encre indélébile).
- **LO 64-14** (motions citoyennes) : comité de présentation ≥ 5 membres,
  irrecevabilité si atteinte aux constantes de la Nation.
- **LO 02-12** (nominations aux fonctions supérieures) : dichotomie Conseil des
  Ministres (établissements « stratégiques » : CDG, ANRT, ONEE, CNSS, AMMC…) /
  Conseil de Gouvernement (CRI, CMR, ambassadeurs…).

## 2. Organisation judiciaire et magistrature

- **Loi 38-15** (organisation judiciaire, promulguée par dahir 1-22-38 du
  30/06/2022, B.O. AR 7108 du 14/07/2022 ; traduction FR au B.O. édition
  traduction officielle, à récupérer sur sgg.gov.ma) : unicité de la justice et
  indépendance (art. 4) ; trois degrés (art. 1) — TPI + tribunaux de
  commerce/administratifs ; cours d'appel en collégialité de 3 ; Cour de
  Cassation à Rabat. Art. 86 : sept chambres (✅ vérifié dans
  `corpus/raw/organisation_judiciaire_ar.pdf` : مدنية، الأحوال الشخصية والميراث،
  عقارية، تجارية، إدارية، اجتماعية، جنائية) ; art. 87 : formation de cinq
  conseillers en audience publique, présence du parquet obligatoire (✅ vérifié —
  le rapport ne donnait pas de n° d'article pour ce point). Art. 16 :
  délibérations secrètes, opinion dissidente sous pli scellé 10 ans ; art. 14 :
  langue arabe, caractère officiel de l'amazighe.
- **LO 106-13** (statut des magistrats) + **LO 100-13** (CSPJ) : 6 grades ;
  concours < 45 ans ou intégration directe < 55 ans (docteurs en droit, avocats
  10 ans…) ; retraite 65 ans prolongeable jusqu'à 73 ans ; révocation possible
  après abandon de poste (mise en demeure 7 jours).

## 3. Droit civil, foncier, famille

- **Moudawana (Code de la famille)** : éditée en 5 langues (AR, amazigh, FR, ES,
  EN). ⚠️ Réforme majeure en cours depuis 2024-2025 — surveiller le B.O.
  Articulations : art. 32 Code de la nationalité ; art. 264 Code des droits
  réels (successions/testaments soumis à la Moudawana).
- **Loi 39-08** (Code des droits réels) : Hiyaza (possession acquisitive) ;
  art. 261 : inaliénabilité (domaine public/privé de l'État, habous, terres
  collectives, immeubles immatriculés) ; art. 265 : Mogharassa.
- **Loi 18-00** : copropriété des immeubles bâtis.
- **DOC (Code des obligations et contrats)** modifié par la **loi 21-18**
  (sûretés mobilières) : Registre National Électronique des Sûretés Mobilières,
  réalisation extrajudiciaire des garanties.
- **Loi 31-08** : protection du consommateur (dispositions impératives,
  y compris en cas de cession de créance).

## 4. Droit pénal

- **Code pénal** + **Code de procédure pénale** (mises à jour : lois 12-18,
  32-18, 33-18). ⚠️ Réforme procédure pénale (loi 03-23) dans le circuit
  législatif — vérifier avant indexation.
- CPP art. 65 : dossier à disposition de la défense ≥ 3 jours avant chaque
  interrogatoire/confrontation.
- **Loi 46-19** : Instance nationale de la probité et de lutte contre la
  corruption.
- **Dahir 1-58-377 / loi 76-00** : rassemblements publics (attroupement non
  armé : 1 à 3 mois d'emprisonnement, 6 mois si dispersion par la force).

## 5. Droit social et protection sociale

- **Code du travail (loi 65-99)**, édition consolidée 2025 : 589 articles,
  7 livres. Art. 79 : les VRP sont salariés nonobstant toute clause contraire.
  Préavis en période d'essai : 2 jours (paie journalière/hebdo) ou 8 jours
  (paie mensuelle) ; après essai : 8 jours minimum.
- **Lois 98-15 / 99-15** (AMO + retraite des indépendants, consolidées 2024) :
  inscription d'office via ordres professionnels ; amendes 200–2 000 DH par
  cotisation impayée (affiliés), jusqu'à 50 000 DH (organismes) ; retraite par
  points, liquidation à 65 ans, contrôle ACAPS.
- **Loi 60-22** (personnes capables non actives) : carence 3 mois, majoration
  1 %/mois de retard, art. 14 bis : vérification des cotisations avant toute
  aide publique.

## 6. Droit des affaires et finance

- **Code de commerce (loi 15-95)**.
- **Loi 41-05** (OPCC, capital-risque) : multi-compartimentage étanche
  (art. 2.1), actif réglementé à 50 %, statut d'investisseur professionnel
  délivré par l'AMMC.
- **Loi 45-12** (prêt de titres, consolidée 30/07/2025) : exercice illégal puni
  de 6 mois à 2 ans et jusqu'à 500 000 DH.
- Chambres de compensation : capital minimum 100 M DH.

## 7. Environnement, énergie, urbanisme

- **Loi 13-09** (énergies renouvelables, consolidée 2025, mod. 40-19) : seuil
  autorisation ≥ 2 MW électriques / déclaration < 2 MW ou < 8 MW thermiques ;
  certificats d'origine, stockage ; amendes 50 000–100 000 DH + confiscation.
- **Loi 48-15** (ANRE) : commission de résolution des différends présidée par
  un magistrat ; sanctions jusqu'à 3 % du CA HT, interdiction d'accès réseau 1 an.
- **Loi 16-09** (AMEE, efficacité énergétique).
- **Loi 52-20** (ANEF, eaux et forêts) : intégration des fonctionnaires au
  1er janvier 2026, garantie de non-régression statutaire.
- **Loi 12-90** (urbanisme) : SDAU 25 ans (art. 10 : interdiction de lotir en
  violation) ; plan de zonage 2 ans ; arrêtés d'alignement valant DUP
  (effets 10 ans, 2 ans si expropriation).

## 8. Réglementations spécifiques

- **Code des douanes et impôts indirects** : droit de communication (art. 42),
  délits douaniers, valeur au jour de l'enregistrement de la déclaration.
- **Code de la route (loi 52-05, version AR consolidée — seule faisant foi,
  pas de FR consolidé en ligne)** : art. 7 : catégories AM, A1, A, B, C, D,
  E(B), E(C), E(D) (✅ vérifié dans `corpus/raw/code_route_ar.pdf`) ;
  **art. 23** (⚠️ le rapport disait art. 24) : période probatoire de 2 ans
  (catégories A1/A/B) avec capital initial de 20 points (✅ vérifié) ;
  art. 24 : annulation de plein droit à 0 point → carence 6 mois + formation ;
  art. 27 : capital permanent 30 points (✅ vérifié) ; carte de conducteur
  professionnel (art. 40, renouvelable 5 ans, formation continue art. 41) ;
  permis étrangers valables 1 an.
- **Loi 22-80** (patrimoine) : interdiction d'exportation des biens classés
  (3 mois–2 ans de prison, 200 000 DH, amende civile ×10, confiscation) ;
  droit de préemption de l'État.
- **Loi 01-09** (Fondation Nationale des Musées) : droit exclusif de
  reproduction commerciale, préemption en ventes publiques, restitution
  internationale.

---

## Implications pour le corpus Chawerni

**Tier 1 — MVP (les 10 codes du grand public)** : Constitution, Code pénal,
Code de procédure pénale, DOC, Moudawana, Code du travail, Code de commerce,
Code de la route, loi 39-08 (droits réels), loi 38-15 (organisation judiciaire).

**Tier 2 — protection du citoyen/entrepreneur** : loi 31-08 (consommateur),
loi 18-00 (copropriété), lois 98-15/99-15/60-22 (AMO/retraite), loi 21-18
(sûretés mobilières), Code de la nationalité, loi 09-08 (données personnelles).

**Tier 3 — sectoriel (à la demande)** : énergie (13-09, 16-09, 48-15), urbanisme
(12-90), douanes, patrimoine (22-80, 01-09), finance (41-05, 45-12), lois
organiques électorales et judiciaires.

**Contrainte technique découverte lors des vérifications (2026-06-11)** :
l'extraction texte des PDFs Adala en arabe (PyMuPDF) produit des artefacts de
ligatures — `الأحوال` ressort comme `األحوال` (lam-alef décomposé), les
parenthèses et chiffres sont parfois réordonnés (RTL/LTR). Le parser de
chunking devra normaliser les formes de présentation arabes (NFKC + table de
correction des ligatures lam-alef) AVANT tout pattern matching sur `المادة` /
`الفصل`, sinon la recherche par mot-clé échoue silencieusement.

**Points de veille actifs** (à surveiller dans le B.O. — cf. Phase 5 roadmap) :
1. Réforme de la Moudawana (en cours depuis 2024-2025).
2. Loi 03-23 réformant la procédure pénale (circuit législatif).
3. Projet de loi santé et sécurité au travail (refonte des normes d'hygiène).
4. Échéance ANEF : intégration des fonctionnaires au 01/01/2026 (passée — vérifier les textes d'application).
