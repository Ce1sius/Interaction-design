from __future__ import annotations

from urllib.parse import quote, unquote, urldefrag, urljoin, urlsplit, urlunsplit


def normalize_url(raw_url: str, base_url: str | None = None) -> str:
    joined = urljoin(base_url or "", raw_url.strip())
    without_fragment, _ = urldefrag(joined)
    parts = urlsplit(without_fragment)
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()

    netloc = host
    if parts.port and not ((scheme == "http" and parts.port == 80) or (scheme == "https" and parts.port == 443)):
        netloc = f"{host}:{parts.port}"

    path = quote(unquote(parts.path or "/"), safe="/:@!$&'()*+,;=-._~")
    query = quote(unquote(parts.query), safe="=&?/:+,%.-_~")
    return urlunsplit((scheme, netloc, path, query, ""))


def looks_like_pdf_url(url: str) -> bool:
    parts = urlsplit(url)
    lower_path = unquote(parts.path).lower()
    lower_query = unquote(parts.query).lower()
    return lower_path.endswith(".pdf") or ".pdf?" in f"{lower_path}?{lower_query}" or "pdf" in lower_query
