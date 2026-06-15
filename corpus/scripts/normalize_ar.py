"""Normalisation du texte arabe extrait des PDFs Adala.

L'extraction PyMuPDF des PDFs gouvernementaux produit des artefacts vérifiés
sur le corpus réel (session du 2026-06-11) :
  - ligatures lam-alef décomposées en ordre inversé : الأحوال -> األحوال
  - chiffres arabes-orientaux mêlés aux chiffres ASCII
  - formes de présentation arabes (U+FE70-U+FEFF) au lieu des lettres standard

Sans cette passe, tout pattern matching sur المادة / الفصل ou toute recherche
lexicale échoue silencieusement. À appliquer AVANT le chunking et l'indexation.

Limite connue : les ligatures lam-alef inversées en MILIEU de mot (خلال ->
خال ل) sont ambiguës et ne sont pas corrigées — bruit résiduel acceptable pour
le retrieval, documenté dans docs/etat_des_lieux_corpus_juridique.md.
"""

import re
import unicodedata

# Article défini + lam-alef inversé : la séquence alef + alef-hamza + lam
# n'existe pas en arabe légitime -> correction sans ambiguïté.
LAM_ALEF_FIXES = [
    ("اال", "الا"),
    ("األ", "الأ"),
    ("اإل", "الإ"),
    ("اآل", "الآ"),
]

EASTERN_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

# Numéro de page entouré de tirets (`- 24 -`) ou ligne de ponctuation pure.
# ATTENTION : ne JAMAIS supprimer les lignes de chiffres nus — l'extraction
# RTL isole souvent sur leur propre ligne des nombres qui appartiennent au
# texte de loi (montants, durées, « رصيد من ⏎20⏎ نقطة ») ; les supprimer
# corrompt silencieusement le contenu (bug constaté sur l'art. 23 du code de
# la route).
_JUNK_LINE = re.compile(r"^\s*(?:[-–—_.()]+|[-–—]\s*\d+\s*[-–—])\s*$")


def normalize_ar(text: str) -> str:
    """Normalise un texte arabe extrait d'un PDF (idempotent)."""
    t = unicodedata.normalize("NFKC", text)
    for broken, fixed in LAM_ALEF_FIXES:
        t = t.replace(broken, fixed)
    t = t.replace("ـ", "")  # tatweel ـ
    t = t.translate(EASTERN_DIGITS)
    return t


def strip_junk_lines(text: str) -> str:
    """Supprime les lignes de pagination (`- 24 -`) et de ponctuation pure.
    Les lignes de chiffres nus sont conservées (cf. _JUNK_LINE)."""
    return "\n".join(l for l in text.split("\n") if not _JUNK_LINE.match(l))


if __name__ == "__main__":
    # Cas réels relevés dans le corpus (38-15, code de la route)
    assert normalize_ar("غرفة األحوال الشخصية") == "غرفة الأحوال الشخصية"
    assert normalize_ar("الفترة االختبارية") == "الفترة الاختبارية"
    assert normalize_ar("القانون اإلداري") == "القانون الإداري"
    assert normalize_ar("٢٠ نقطة") == "20 نقطة"
    assert normalize_ar("المـــادة") == "المادة"  # tatweel
    # NFKC : forme de présentation isolée -> standard
    assert normalize_ar("ﻟﺎ") == "لا"
    # idempotence
    s = "غرفة األحوال ٢٠"
    assert normalize_ar(normalize_ar(s)) == normalize_ar(s)
    assert strip_junk_lines("المادة 5\n- 31 -\nنص") == "المادة 5\nنص"
    # les chiffres nus restent : ce sont souvent des valeurs du texte de loi
    assert strip_junk_lines("رصيد من\n20\nنقطة") == "رصيد من\n20\nنقطة"
    print("normalize_ar : tous les tests passent ✓")
