from __future__ import annotations

from dataclasses import dataclass
from urllib.parse import urljoin

import httpx

from app.courses.schemas import CourseResponse
from app.crawler.auth import AuthContext
from app.crawler.domain_validator import DomainValidator, UnsafeURL
from app.crawler.pdf_link_extractor import extract_pdf_links
from app.crawler.url_normalizer import normalize_url


@dataclass
class DiscoveryResult:
    links: list[str]
    errors: list[str]
    titles: dict[str, str] | None = None


class StaticHTMLSourceAdapter:
    def __init__(self, timeout_seconds: float = 20):
        self.timeout_seconds = timeout_seconds

    async def discover_pdf_links(self, course: CourseResponse, auth: AuthContext | None = None) -> DiscoveryResult:
        validator = DomainValidator(course.allowedDomains)
        links: list[str] = []
        errors: list[str] = []
        headers = (auth or AuthContext()).request_headers()
        async with httpx.AsyncClient(timeout=self.timeout_seconds, trust_env=False) as client:
            for page in course.sourcePages:
                try:
                    normalized_page = normalize_url(page)
                    validator.validate_url(normalized_page)
                    response = await self._get_with_validated_redirects(client, normalized_page, validator, headers=headers)
                    content_type = response.headers.get("content-type", "")
                    if "text/html" not in content_type and "application/xhtml" not in content_type and content_type:
                        errors.append(f"{page}: non-HTML content-type {content_type}")
                    page_links = extract_pdf_links(response.text, str(response.url))
                    for link in page_links:
                        normalized_link = normalize_url(link, str(response.url))
                        validator.validate_url(normalized_link)
                        if normalized_link not in links:
                            links.append(normalized_link)
                except Exception as exc:
                    errors.append(f"{page}: {type(exc).__name__}: {exc}")
        return DiscoveryResult(links=links, errors=errors, titles={})

    async def _get_with_validated_redirects(
        self,
        client: httpx.AsyncClient,
        url: str,
        validator: DomainValidator,
        headers: dict[str, str] | None = None,
        max_redirects: int = 5,
    ) -> httpx.Response:
        current = url
        for _ in range(max_redirects + 1):
            validator.validate_url(current)
            response = await client.get(current, headers=headers, follow_redirects=False)
            if response.status_code in {301, 302, 303, 307, 308}:
                location = response.headers.get("location")
                if not location:
                    response.raise_for_status()
                current = normalize_url(urljoin(current, location))
                validator.validate_url(current)
                continue
            response.raise_for_status()
            return response
        raise UnsafeURL("too many redirects while fetching source page")
