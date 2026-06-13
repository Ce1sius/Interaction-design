from __future__ import annotations

import io


def ocr_pdf_pages(raw_pdf: bytes, *, language: str, max_pages: int) -> str:
    """Best-effort OCR for scanned PDFs.

    Requires external Tesseract plus Python packages `pymupdf`, `pillow`, and
    `pytesseract`. Missing OCR runtime returns an empty string so normal text
    extraction still works in lightweight environments.
    """

    try:
        import fitz
        import pytesseract
        from PIL import Image
    except Exception:
        return ""

    try:
        document = fitz.open(stream=raw_pdf, filetype="pdf")
        texts: list[str] = []
        for page_index in range(min(len(document), max_pages)):
            page = document.load_page(page_index)
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
            image = Image.open(io.BytesIO(pix.tobytes("png")))
            text = pytesseract.image_to_string(image, lang=language).strip()
            if text:
                texts.append(f"[page {page_index + 1}]\n{text}")
        return "\n\n".join(texts)
    except Exception:
        return ""
