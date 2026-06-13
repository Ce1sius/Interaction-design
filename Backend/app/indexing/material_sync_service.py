from __future__ import annotations

from dataclasses import dataclass

from app.courses.repository import CourseRepository, title_from_url, utc_now
from app.courses.schemas import SyncMaterialsRequest, SyncStats
from app.crawler.auth import AuthContext
from app.crawler.browser_adapter import BrowserSourceAdapter
from app.crawler.static_html_adapter import DiscoveryResult
from app.crawler.static_html_adapter import StaticHTMLSourceAdapter
from app.crawler.zju_learning_adapter import ZJULearningSourceAdapter
from app.crawler.url_normalizer import normalize_url
from app.documents.remote_fetcher import RemoteDocumentFetcher
from app.indexing.provider import LocalKeywordIndexProvider


@dataclass(frozen=True)
class MaterialSyncResult:
    stats: SyncStats
    errors: list[str]


class CourseMaterialSyncService:
    def __init__(
        self,
        course_repository: CourseRepository,
        index_provider: LocalKeywordIndexProvider,
        source_adapter: StaticHTMLSourceAdapter,
        browser_adapter: BrowserSourceAdapter | None,
        zju_learning_adapter: ZJULearningSourceAdapter | None,
        fetcher: RemoteDocumentFetcher,
        server_cookie_fallback: str | None = None,
    ):
        self.course_repository = course_repository
        self.index_provider = index_provider
        self.source_adapter = source_adapter
        self.browser_adapter = browser_adapter
        self.zju_learning_adapter = zju_learning_adapter
        self.fetcher = fetcher
        self.server_cookie_fallback = server_cookie_fallback

    async def sync_course(self, course_id: str, request: SyncMaterialsRequest | None = None) -> MaterialSyncResult:
        course = self.course_repository.get_course(course_id)
        if course is None:
            raise KeyError("course not found")
        request = request or SyncMaterialsRequest()
        if course.accessType not in {"publicWeb", "authenticated"}:
            raise ValueError("officialAPI courses need a custom adapter before sync")
        if not course.allowedDomains:
            raise ValueError("course allowedDomains must be configured before sync")
        if not course.sourcePages and request.adapter not in {"zjuLearning", "auto"}:
            raise ValueError("course sourcePages must be configured before static/browser sync")

        auth = AuthContext.from_request(request.auth, fallback_cookie=self.server_cookie_fallback)
        discovery = await self._discover(course, request, auth)
        stats = SyncStats(courseId=course_id, discovered=len(discovery.links), failed=len(discovery.errors))
        errors = list(discovery.errors)
        discovered_urls = {normalize_url(link) for link in discovery.links}

        self.index_provider.create_course_index(course_id)
        allow_private_resolved_hosts = _private_dns_allowed_hosts(course, request)
        for link in discovery.links:
            normalized = normalize_url(link)
            existing = self.course_repository.get_document_by_url(course_id, normalized)
            try:
                auth_headers = auth.request_headers()
                probe = await self.fetcher.probe(
                    normalized,
                    course.allowedDomains,
                    auth_headers=auth_headers,
                    allow_private_resolved_hosts=allow_private_resolved_hosts,
                )
                if existing and _metadata_unchanged(existing, probe.etag, probe.last_modified, probe.file_size):
                    self.course_repository.touch_document_checked(course_id, normalized)
                    stats.unchanged += 1
                    continue

                fetched = await self.fetcher.fetch_pdf(
                    normalized,
                    course.allowedDomains,
                    auth_headers=auth_headers,
                    allow_private_resolved_hosts=allow_private_resolved_hosts,
                )
                title = (discovery.titles or {}).get(normalized)
                document = self.course_repository.upsert_document(
                    course_id=course_id,
                    source_url=fetched.final_url,
                    normalized_url=normalized,
                    title=existing.title if existing else (title or title_from_url(fetched.final_url)),
                    content_type=fetched.content_type,
                    file_size=fetched.file_size,
                    etag=fetched.etag,
                    last_modified=fetched.last_modified,
                    content_hash=fetched.content_hash,
                    status="indexed",
                    indexed_at=utc_now(),
                )
                vector_file_id = self.index_provider.update_document(course_id, document, fetched.text)
                self.course_repository.upsert_document(
                    course_id=course_id,
                    source_url=fetched.final_url,
                    normalized_url=normalized,
                    title=document.title,
                    content_type=fetched.content_type,
                    file_size=fetched.file_size,
                    etag=fetched.etag,
                    last_modified=fetched.last_modified,
                    content_hash=fetched.content_hash,
                    status="indexed",
                    vector_file_id=vector_file_id,
                    indexed_at=utc_now(),
                )
                if existing:
                    stats.updated += 1
                else:
                    stats.added += 1
            except Exception as exc:
                stats.failed += 1
                errors.append(f"{normalized}: {type(exc).__name__}: {exc}")
                self.course_repository.upsert_document(
                    course_id=course_id,
                    source_url=normalized,
                    normalized_url=normalized,
                    title=existing.title if existing else title_from_url(normalized),
                    content_type=None,
                    file_size=None,
                    etag=None,
                    last_modified=None,
                    content_hash=existing.contentHash if existing else None,
                    status="failed",
                )

        stats.removed = self.course_repository.mark_removed_missing(course_id, discovered_urls)
        for document in self.course_repository.list_documents(course_id, include_removed=True):
            if document.status == "removed":
                self.index_provider.remove_document(course_id, document.id)
        return MaterialSyncResult(stats=stats, errors=errors)

    async def _discover(self, course, request: SyncMaterialsRequest, auth: AuthContext) -> DiscoveryResult:
        if request.adapter == "zjuLearning" or (
            request.adapter == "auto"
            and course.accessType == "authenticated"
            and _allowed_domains_cover("courses.zju.edu.cn", course.allowedDomains)
        ):
            if self.zju_learning_adapter is None:
                raise ValueError("ZJU Learning adapter is not configured")
            if not auth.cookie_header:
                raise ValueError("authenticated ZJU Learning sync requires cookieHeader or ZJU_LEARNING_COOKIE")
            return await self.zju_learning_adapter.discover_pdf_links(course, auth)

        if request.adapter == "browser":
            if self.browser_adapter is None:
                raise ValueError("browser adapter is not configured")
            return await self.browser_adapter.discover_pdf_links(course, auth)

        discovery = await self.source_adapter.discover_pdf_links(course, auth)
        if request.adapter == "auto" and request.useBrowserFallback and not discovery.links and self.browser_adapter is not None:
            browser_discovery = await self.browser_adapter.discover_pdf_links(course, auth)
            browser_discovery.errors = discovery.errors + browser_discovery.errors
            return browser_discovery
        return discovery


def _metadata_unchanged(existing, etag: str | None, last_modified: str | None, file_size: int | None) -> bool:
    if not existing.contentHash:
        return False
    if etag and existing.etag and etag == existing.etag:
        return True
    if last_modified and existing.lastModified and file_size and existing.fileSize:
        return last_modified == existing.lastModified and file_size == existing.fileSize
    return False


def _allowed_domains_cover(host: str, domains: list[str]) -> bool:
    normalized_host = host.lower()
    return any(normalized_host == domain.lower() or normalized_host.endswith(f".{domain.lower()}") for domain in domains)


def _private_dns_allowed_hosts(course, request: SyncMaterialsRequest) -> tuple[str, ...]:
    if request.adapter in {"zjuLearning", "auto"} and _allowed_domains_cover("courses.zju.edu.cn", course.allowedDomains):
        return ("courses.zju.edu.cn",)
    return ()
