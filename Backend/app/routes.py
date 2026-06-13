from __future__ import annotations

from sqlite3 import Connection
from typing import Iterator

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.config import Settings
from app.courses.repository import CourseRepository, utc_now
import hashlib

from app.courses.schemas import (
    CourseCreate,
    CourseDocumentResponse,
    CourseResponse,
    ImportedCoursesRequest,
    SyncMaterialsRequest,
    SyncStats,
)
from app.crawler.browser_adapter import BrowserSourceAdapter
from app.crawler.static_html_adapter import StaticHTMLSourceAdapter
from app.crawler.zju_learning_adapter import ZJULearningSourceAdapter
from app.crawler.url_normalizer import normalize_url
from app.documents.remote_fetcher import RemoteDocumentFetcher
from app.documents.remote_fetcher import extract_pdf_text
from app.indexing.material_sync_service import CourseMaterialSyncService
from app.indexing.provider import LocalKeywordIndexProvider
from app.mindmap.generation_service import MindMapGenerationError, MindMapGenerationService
from app.mindmap.prompt_builder import PromptBuilder
from app.mindmap.repository import MindMapRepository
from app.mindmap.schemas import MindMapExpansionRequest, MindMapNode, MindMapResponse, MindMapSourceReference
from app.mindmap.validation_service import MindMapValidationService


router = APIRouter()


def get_conn(request: Request) -> Iterator[Connection]:
    with request.app.state.database.session() as conn:
        yield conn


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


@router.get("/health")
def health(request: Request) -> dict[str, str]:
    return {
        "status": "ok",
        "database": str(request.app.state.settings.database_path),
        "vllmBaseUrl": request.app.state.settings.vllm_base_url,
    }


@router.post("/courses", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
def create_course(course: CourseCreate, conn: Connection = Depends(get_conn)) -> CourseResponse:
    return CourseRepository(conn).upsert_course(course)


@router.post("/courses/imported/zju-learning", response_model=list[CourseResponse])
def configure_imported_zju_courses(
    body: ImportedCoursesRequest,
    conn: Connection = Depends(get_conn),
) -> list[CourseResponse]:
    repo = CourseRepository(conn)
    configured: list[CourseResponse] = []
    for imported in body.courses:
        course_id = _safe_course_id(imported.id or imported.name)
        configured.append(
            repo.upsert_course(
                CourseCreate(
                    id=course_id,
                    name=imported.name,
                    semester=imported.semester,
                    sourcePages=["https://courses.zju.edu.cn/user/courses"],
                    allowedDomains=["courses.zju.edu.cn"],
                    accessType="authenticated",
                )
            )
        )
    return configured


@router.get("/courses/{course_id}", response_model=CourseResponse)
def get_course(course_id: str, conn: Connection = Depends(get_conn)) -> CourseResponse:
    course = CourseRepository(conn).get_course(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="course not found")
    return course


@router.post("/courses/{course_id}/sync-materials", response_model=SyncStats)
async def sync_materials(
    course_id: str,
    body: SyncMaterialsRequest | None = None,
    conn: Connection = Depends(get_conn),
    settings: Settings = Depends(get_settings_dep),
) -> SyncStats:
    repo = CourseRepository(conn)
    service = CourseMaterialSyncService(
        course_repository=repo,
        index_provider=LocalKeywordIndexProvider(conn),
        source_adapter=StaticHTMLSourceAdapter(timeout_seconds=settings.request_timeout_seconds),
        browser_adapter=BrowserSourceAdapter(timeout_seconds=settings.request_timeout_seconds),
        zju_learning_adapter=ZJULearningSourceAdapter(timeout_seconds=settings.request_timeout_seconds),
        fetcher=RemoteDocumentFetcher(
            max_bytes=settings.max_pdf_bytes,
            timeout_seconds=settings.request_timeout_seconds,
            enable_ocr=settings.enable_ocr,
            ocr_language=settings.ocr_language,
            ocr_max_pages=settings.ocr_max_pages,
        ),
        server_cookie_fallback=settings.zju_learning_cookie,
    )
    try:
        result = await service.sync_course(course_id, body)
    except KeyError:
        raise HTTPException(status_code=404, detail="course not found")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return result.stats


@router.put("/courses/{course_id}/documents/imported", response_model=CourseDocumentResponse)
async def import_downloaded_document(
    course_id: str,
    request: Request,
    title: str,
    sourceUrl: str,
    conn: Connection = Depends(get_conn),
    settings: Settings = Depends(get_settings_dep),
) -> CourseDocumentResponse:
    repo = CourseRepository(conn)
    if repo.get_course(course_id) is None:
        raise HTTPException(status_code=404, detail="course not found")

    raw = await request.body()
    if len(raw) > settings.max_pdf_bytes:
        raise HTTPException(status_code=413, detail="PDF exceeds configured size limit")
    if not raw.startswith(b"%PDF"):
        raise HTTPException(status_code=400, detail="uploaded document is not a PDF")

    normalized_url = normalize_url(sourceUrl)
    content_hash = hashlib.sha256(raw).hexdigest()
    text = extract_pdf_text(
        raw,
        enable_ocr=settings.enable_ocr,
        ocr_language=settings.ocr_language,
        ocr_max_pages=settings.ocr_max_pages,
    )
    document = repo.upsert_document(
        course_id=course_id,
        source_url=normalized_url,
        normalized_url=normalized_url,
        title=title,
        content_type="application/pdf",
        file_size=len(raw),
        etag=None,
        last_modified=None,
        content_hash=content_hash,
        status="indexed",
        indexed_at=utc_now(),
    )
    vector_file_id = LocalKeywordIndexProvider(conn).update_document(course_id, document, text)
    return repo.upsert_document(
        course_id=course_id,
        source_url=normalized_url,
        normalized_url=normalized_url,
        title=document.title,
        content_type="application/pdf",
        file_size=len(raw),
        etag=None,
        last_modified=None,
        content_hash=content_hash,
        status="indexed",
        vector_file_id=vector_file_id,
        indexed_at=utc_now(),
    )


@router.get("/courses/{course_id}/documents", response_model=list[CourseDocumentResponse])
def list_documents(course_id: str, conn: Connection = Depends(get_conn)) -> list[CourseDocumentResponse]:
    repo = CourseRepository(conn)
    if repo.get_course(course_id) is None:
        raise HTTPException(status_code=404, detail="course not found")
    return repo.list_documents(course_id)


@router.get("/courses/{course_id}/mind-map", response_model=MindMapResponse)
async def get_mind_map(
    request: Request,
    course_id: str,
    conn: Connection = Depends(get_conn),
) -> MindMapResponse:
    service = _generation_service(request, conn)
    try:
        return await service.get_or_generate_top_level(course_id)
    except KeyError:
        raise HTTPException(status_code=404, detail="course not found")
    except MindMapGenerationError as exc:
        raise HTTPException(status_code=422, detail={"message": str(exc), "errors": exc.errors})
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.post("/courses/{course_id}/mind-map/regenerate", response_model=MindMapResponse)
async def regenerate_mind_map(
    request: Request,
    course_id: str,
    conn: Connection = Depends(get_conn),
) -> MindMapResponse:
    service = _generation_service(request, conn)
    try:
        return await service.regenerate_top_level(course_id)
    except KeyError:
        raise HTTPException(status_code=404, detail="course not found")
    except MindMapGenerationError as exc:
        raise HTTPException(status_code=422, detail={"message": str(exc), "errors": exc.errors})
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.post("/courses/{course_id}/mind-map/expand", response_model=MindMapResponse)
async def expand_mind_map(
    request: Request,
    course_id: str,
    body: MindMapExpansionRequest,
    conn: Connection = Depends(get_conn),
) -> MindMapResponse:
    service = _generation_service(request, conn)
    try:
        return await service.expand_node(course_id, body.nodeId, body.requestedDepth)
    except KeyError as exc:
        detail = str(exc).strip("'") or "not found"
        raise HTTPException(status_code=404, detail=detail)
    except MindMapGenerationError as exc:
        raise HTTPException(status_code=422, detail={"message": str(exc), "errors": exc.errors})
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.get("/courses/{course_id}/mind-map/nodes/{node_id}", response_model=MindMapNode)
def get_node(course_id: str, node_id: str, conn: Connection = Depends(get_conn)) -> MindMapNode:
    node = MindMapRepository(conn).get_node(course_id, node_id)
    if node is None:
        raise HTTPException(status_code=404, detail="node not found")
    return node


@router.get("/courses/{course_id}/mind-map/nodes/{node_id}/sources", response_model=list[MindMapSourceReference])
def get_node_sources(course_id: str, node_id: str, conn: Connection = Depends(get_conn)) -> list[MindMapSourceReference]:
    repo = MindMapRepository(conn)
    if repo.get_node(course_id, node_id) is None:
        raise HTTPException(status_code=404, detail="node not found")
    return repo.get_node_sources(course_id, node_id)


def _generation_service(request: Request, conn: Connection) -> MindMapGenerationService:
    return MindMapGenerationService(
        course_repository=CourseRepository(conn),
        mindmap_repository=MindMapRepository(conn),
        index_provider=LocalKeywordIndexProvider(conn),
        prompt_builder=PromptBuilder(request.app.state.settings.prompt_path),
        llm_client=request.app.state.llm_client,
        validation_service=MindMapValidationService(),
    )


def _safe_course_id(value: str) -> str:
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
    cleaned = "".join(ch if ch in allowed else "-" for ch in value.strip())
    cleaned = "-".join(part for part in cleaned.split("-") if part)
    if cleaned:
        return cleaned[:80]
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:16]
    return f"course-{digest}"
