from __future__ import annotations

import hashlib
import io
import re
import zipfile
from dataclasses import dataclass
from html import unescape
from urllib.parse import urljoin
from urllib.parse import urlsplit

import httpx

from app.crawler.domain_validator import DomainValidator, UnsafeURL
from app.crawler.url_normalizer import normalize_url


@dataclass(frozen=True)
class DocumentProbe:
    final_url: str
    content_type: str | None
    file_size: int | None
    etag: str | None
    last_modified: str | None


@dataclass(frozen=True)
class FetchedDocument:
    final_url: str
    content_type: str | None
    file_size: int
    etag: str | None
    last_modified: str | None
    content_hash: str
    text: str


class RemoteDocumentFetcher:
    def __init__(
        self,
        *,
        max_bytes: int,
        timeout_seconds: float,
        enable_ocr: bool = False,
        ocr_language: str = "chi_sim+eng",
        ocr_max_pages: int = 6,
    ):
        self.max_bytes = max_bytes
        self.timeout_seconds = timeout_seconds
        self.enable_ocr = enable_ocr
        self.ocr_language = ocr_language
        self.ocr_max_pages = ocr_max_pages

    async def probe(
        self,
        url: str,
        allowed_domains: list[str],
        auth_headers: dict[str, str] | None = None,
        allow_private_resolved_hosts: list[str] | tuple[str, ...] = (),
    ) -> DocumentProbe:
        validator = DomainValidator(allowed_domains, allow_private_resolved_hosts=allow_private_resolved_hosts)
        async with httpx.AsyncClient(timeout=self.timeout_seconds, trust_env=False) as client:
            response = await self._request_with_validated_redirects(
                client,
                method="HEAD",
                    url=url,
                    validator=validator,
                    headers=auth_headers,
                )
            if response.status_code in {405, 403}:
                response = await self._request_with_validated_redirects(
                    client,
                    method="GET",
                    url=url,
                    validator=validator,
                    headers={**(auth_headers or {}), "Range": "bytes=0-0"},
                )
            file_size = _parse_content_length(response.headers.get("content-length"))
            if file_size is not None and file_size > self.max_bytes:
                raise ValueError("PDF exceeds configured size limit")
            return DocumentProbe(
                final_url=normalize_url(str(response.url)),
                content_type=response.headers.get("content-type"),
                file_size=file_size,
                etag=response.headers.get("etag"),
                last_modified=response.headers.get("last-modified"),
            )

    async def fetch_pdf(
        self,
        url: str,
        allowed_domains: list[str],
        auth_headers: dict[str, str] | None = None,
        allow_private_resolved_hosts: list[str] | tuple[str, ...] = (),
    ) -> FetchedDocument:
        validator = DomainValidator(allowed_domains, allow_private_resolved_hosts=allow_private_resolved_hosts)
        async with httpx.AsyncClient(timeout=self.timeout_seconds, trust_env=False) as client:
            response = await self._request_with_validated_redirects(
                client,
                method="GET",
                url=url,
                validator=validator,
                headers=auth_headers,
            )
            content_type = response.headers.get("content-type")
            expected_size = _parse_content_length(response.headers.get("content-length"))
            if expected_size is not None and expected_size > self.max_bytes:
                raise ValueError("PDF exceeds configured size limit")

            data = bytearray()
            async for chunk in response.aiter_bytes():
                data.extend(chunk)
                if len(data) > self.max_bytes:
                    raise ValueError("PDF exceeds configured size limit")
            raw = bytes(data)

            content_hash = hashlib.sha256(raw).hexdigest()
            text = extract_course_document_text(
                raw,
                content_type=content_type,
                source_url=str(response.url),
                enable_ocr=self.enable_ocr,
                ocr_language=self.ocr_language,
                ocr_max_pages=self.ocr_max_pages,
            )
            return FetchedDocument(
                final_url=normalize_url(str(response.url)),
                content_type=content_type,
                file_size=len(raw),
                etag=response.headers.get("etag"),
                last_modified=response.headers.get("last-modified"),
                content_hash=content_hash,
                text=text,
            )

    async def _request_with_validated_redirects(
        self,
        client: httpx.AsyncClient,
        *,
        method: str,
        url: str,
        validator: DomainValidator,
        headers: dict[str, str] | None = None,
        max_redirects: int = 5,
    ) -> httpx.Response:
        current = normalize_url(url)
        for _ in range(max_redirects + 1):
            validator.validate_url(current)
            response = await client.request(method, current, headers=headers, follow_redirects=False)
            if response.status_code in {301, 302, 303, 307, 308}:
                location = response.headers.get("location")
                if not location:
                    response.raise_for_status()
                current = normalize_url(urljoin(current, location))
                validator.validate_url(current)
                continue
            response.raise_for_status()
            validator.validate_url(normalize_url(str(response.url)))
            return response
        raise UnsafeURL("too many redirects while fetching document")


def _parse_content_length(value: str | None) -> int | None:
    if not value:
        return None
    try:
        parsed = int(value)
    except ValueError:
        return None
    return parsed if parsed >= 0 else None


def extract_pdf_text(
    raw_pdf: bytes,
    max_pages: int = 30,
    max_chars: int = 80_000,
    *,
    enable_ocr: bool = False,
    ocr_language: str = "chi_sim+eng",
    ocr_max_pages: int = 6,
) -> str:
    try:
        from pypdf import PdfReader
    except Exception:
        if enable_ocr:
            from app.documents.ocr import ocr_pdf_pages

            return ocr_pdf_pages(raw_pdf, language=ocr_language, max_pages=ocr_max_pages)[:max_chars]
        return ""

    try:
        reader = PdfReader(io.BytesIO(raw_pdf))
        pieces: list[str] = []
        for page_index, page in enumerate(reader.pages[:max_pages], start=1):
            text = page.extract_text() or ""
            text = text.strip()
            if text:
                pieces.append(f"[page {page_index}]\n{text}")
            if sum(len(piece) for piece in pieces) >= max_chars:
                break
        extracted = "\n\n".join(pieces)[:max_chars]
        if extracted.strip() or not enable_ocr:
            return extracted
        from app.documents.ocr import ocr_pdf_pages

        return ocr_pdf_pages(raw_pdf, language=ocr_language, max_pages=ocr_max_pages)[:max_chars]
    except Exception:
        if not enable_ocr:
            return ""
        from app.documents.ocr import ocr_pdf_pages

        return ocr_pdf_pages(raw_pdf, language=ocr_language, max_pages=ocr_max_pages)[:max_chars]


def extract_course_document_text(
    raw: bytes,
    *,
    content_type: str | None = None,
    source_url: str = "",
    enable_ocr: bool = False,
    ocr_language: str = "chi_sim+eng",
    ocr_max_pages: int = 6,
) -> str:
    if raw.startswith(b"%PDF") or _looks_like_pdf(content_type, source_url):
        return extract_pdf_text(
            raw,
            enable_ocr=enable_ocr,
            ocr_language=ocr_language,
            ocr_max_pages=ocr_max_pages,
        )
    if _looks_like_openxml(raw, content_type, source_url):
        return extract_openxml_text(raw)
    return ""


def extract_openxml_text(raw: bytes, max_chars: int = 80_000) -> str:
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            names = archive.namelist()
            if any(name.startswith("ppt/slides/slide") and name.endswith(".xml") for name in names):
                slide_names = sorted(
                    name for name in names if name.startswith("ppt/slides/slide") and name.endswith(".xml")
                )
                pieces = []
                for index, name in enumerate(slide_names, start=1):
                    text = _xml_text(archive.read(name).decode("utf-8", errors="ignore"))
                    if text:
                        pieces.append(f"[slide {index}]\n{text}")
                return "\n\n".join(pieces)[:max_chars]
            if "word/document.xml" in names:
                return _xml_text(archive.read("word/document.xml").decode("utf-8", errors="ignore"))[:max_chars]
    except zipfile.BadZipFile:
        pass
    raise ValueError("remote content is not a supported course document")


def _xml_text(xml: str) -> str:
    text = re.sub(r"<[^>]+>", " ", xml)
    text = unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def _looks_like_pdf(content_type: str | None, source_url: str) -> bool:
    lowered = f"{content_type or ''} {urlsplit(source_url).path}".lower()
    return "pdf" in lowered


def _looks_like_openxml(raw: bytes, content_type: str | None, source_url: str) -> bool:
    lowered = f"{content_type or ''} {urlsplit(source_url).path}".lower()
    return raw.startswith(b"PK") or any(token in lowered for token in ("officedocument", "pptx", "docx"))
