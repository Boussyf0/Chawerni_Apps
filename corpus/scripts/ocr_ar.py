"""Re-OCR des PDFs arabes — la couche texte d'Adala est corrompue.

L'extraction PyMuPDF de la couche texte des PDFs AR produit des artefacts
irréparables et AMBIGUS (espaces intra-mot « ال مادة », ligatures lam-alef
inversées « العلاقة → العالقة », et surtout « لا » ↔ « ال » indistinguables sans
dictionnaire). On contourne en OCRisant les pages RENDUES (les glyphes sont
corrects à l'écran) avec Tesseract (modèle `ara`).

Vérifié : sur la page 21 de la Moudawana, la couche texte donne « ال مادة44 …
العالقة » tandis que l'OCR donne « المادة 44 … أجل لا يتعدى » (mots intacts,
négation « لا » correcte).

Le résultat est mis en cache dans `corpus/ocr/{code}_ar.txt` (pages séparées par
form-feed \\f) puis consommé par chunk_codes.extract_text. OCR lent → cache.

Usage :
  python3 ocr_ar.py moudawana      # un code
  python3 ocr_ar.py                # tous les PDFs *_ar.pdf
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw"
OCR = ROOT / "ocr"
DPI_MATRIX = fitz.Matrix(4, 4)  # ~288 dpi : bon compromis qualité/vitesse


def ocr_page(page: fitz.Page, tmpdir: str) -> str:
    """Rendu de la page + OCR Tesseract (arabe)."""
    png = Path(tmpdir) / "page.png"
    page.get_pixmap(matrix=DPI_MATRIX).save(str(png))
    out = subprocess.run(
        ["tesseract", str(png), "stdout", "-l", "ara", "--psm", "4"],
        capture_output=True, text=True,
    )
    return out.stdout


def ocr_pdf(pdf_path: Path) -> str:
    """OCRise tout un PDF ; pages séparées par form-feed (pour la détection
    d'en-têtes courants côté chunker)."""
    doc = fitz.open(pdf_path)
    pages = []
    with tempfile.TemporaryDirectory() as tmp:
        for i in range(doc.page_count):
            pages.append(ocr_page(doc[i], tmp))
            if (i + 1) % 20 == 0:
                print(f"    … {i + 1}/{doc.page_count} pages", flush=True)
    doc.close()
    return "\f".join(pages)


def main() -> None:
    OCR.mkdir(exist_ok=True)
    code = sys.argv[1] if len(sys.argv) > 1 else None
    pdfs = (
        sorted(RAW.glob(f"{code}_ar.pdf")) if code else sorted(RAW.glob("*_ar.pdf"))
    )
    if not pdfs:
        sys.exit(f"Aucun PDF AR pour « {code} » dans {RAW}")
    for pdf in pdfs:
        out_path = OCR / f"{pdf.stem}.txt"
        if out_path.exists() and "--force" not in sys.argv:
            print(f"↷ {pdf.name} déjà OCRisé ({out_path.name}) — sauté", flush=True)
            continue
        print(f"OCR {pdf.name} ({fitz.open(pdf).page_count} pages)…", flush=True)
        text = ocr_pdf(pdf)
        out_path.write_text(text, encoding="utf-8")
        print(f"  ✓ {out_path.name} ({len(text)} caractères)")


if __name__ == "__main__":
    main()
