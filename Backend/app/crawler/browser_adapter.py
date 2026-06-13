from __future__ import annotations

import asyncio
from urllib.parse import urlsplit

from app.courses.schemas import CourseResponse
from app.crawler.auth import AuthContext
from app.crawler.domain_validator import DomainValidator
from app.crawler.pdf_link_extractor import extract_pdf_links
from app.crawler.static_html_adapter import DiscoveryResult
from app.crawler.url_normalizer import looks_like_pdf_url, normalize_url


class BrowserSourceAdapter:
    """Playwright-backed adapter for JavaScript-rendered resource pages."""

    def __init__(self, timeout_seconds: float = 20):
        self.timeout_ms = int(timeout_seconds * 1000)

    async def discover_pdf_links(self, course: CourseResponse, auth: AuthContext | None = None) -> DiscoveryResult:
        try:
            from playwright.async_api import async_playwright
        except Exception as exc:
            return DiscoveryResult(
                links=[],
                errors=[f"playwright is not installed or browsers are missing: {exc}"],
                titles={},
            )

        validator = DomainValidator(course.allowedDomains)
        discovered: list[str] = []
        errors: list[str] = []
        auth = auth or AuthContext()

        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=True)
            context = await browser.new_context(extra_http_headers=auth.request_headers())
            try:
                for page_url in course.sourcePages:
                    normalized_page = normalize_url(page_url)
                    try:
                        validator.validate_url(normalized_page)
                        host = urlsplit(normalized_page).hostname or ""
                        cookies = auth.playwright_cookies(host)
                        if cookies:
                            await context.add_cookies(cookies)
                        page = await context.new_page()
                        response_tasks: set[asyncio.Task] = set()

                        async def capture_response(response):
                            try:
                                url = normalize_url(response.url)
                                content_type = response.headers.get("content-type", "")
                                if looks_like_pdf_url(url) or "pdf" in content_type.lower():
                                    validator.validate_url(url)
                                    if url not in discovered:
                                        discovered.append(url)
                            except Exception:
                                return

                        def on_response(response):
                            task = asyncio.create_task(capture_response(response))
                            response_tasks.add(task)
                            task.add_done_callback(response_tasks.discard)

                        page.on("response", on_response)
                        await page.goto(normalized_page, wait_until="networkidle", timeout=self.timeout_ms)
                        if response_tasks:
                            await asyncio.gather(*response_tasks, return_exceptions=True)
                        html = await page.content()
                        for link in extract_pdf_links(html, normalized_page):
                            validator.validate_url(link)
                            if link not in discovered:
                                discovered.append(link)
                        await page.close()
                    except Exception as exc:
                        errors.append(f"{page_url}: {type(exc).__name__}: {exc}")
            finally:
                await context.close()
                await browser.close()

        return DiscoveryResult(links=discovered, errors=errors, titles={})
