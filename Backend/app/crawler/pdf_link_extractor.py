from __future__ import annotations

import re
from html.parser import HTMLParser

from app.crawler.url_normalizer import looks_like_pdf_url, normalize_url


class _LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name.lower() in {"href", "src"} and value:
                self.links.append(value)


PDF_URL_RE = re.compile(r"https?://[^\s\"'<>]+?\.pdf(?:\?[^\s\"'<>]*)?", re.IGNORECASE)


def extract_pdf_links(html: str, base_url: str) -> list[str]:
    parser = _LinkParser()
    parser.feed(html)
    raw_links = parser.links + PDF_URL_RE.findall(html)
    normalized: list[str] = []
    seen: set[str] = set()
    for raw in raw_links:
        try:
            url = normalize_url(raw, base_url)
        except Exception:
            continue
        if not looks_like_pdf_url(url):
            continue
        if url not in seen:
            seen.add(url)
            normalized.append(url)
    return normalized
