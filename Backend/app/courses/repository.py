from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from sqlite3 import Connection, Row
from urllib.parse import unquote, urlparse

from app.courses.schemas import CourseCreate, CourseDocumentResponse, CourseResponse


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def document_id_for(course_id: str, normalized_url: str) -> str:
    digest = hashlib.sha1(f"{course_id}:{normalized_url}".encode("utf-8")).hexdigest()[:18]
    return f"doc-{digest}"


def title_from_url(url: str) -> str:
    path = urlparse(url).path.rstrip("/")
    name = unquote(path.rsplit("/", 1)[-1]) or "course-document.pdf"
    return name


class CourseRepository:
    def __init__(self, conn: Connection):
        self.conn = conn

    def upsert_course(self, course: CourseCreate) -> CourseResponse:
        now = utc_now()
        existing = self.conn.execute("SELECT created_at FROM courses WHERE id = ?", (course.id,)).fetchone()
        created_at = existing["created_at"] if existing else now
        self.conn.execute(
            """
            INSERT INTO courses (
                id, name, semester, source_pages_json, allowed_domains_json,
                access_type, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name=excluded.name,
                semester=excluded.semester,
                source_pages_json=excluded.source_pages_json,
                allowed_domains_json=excluded.allowed_domains_json,
                access_type=excluded.access_type,
                updated_at=excluded.updated_at
            """,
            (
                course.id,
                course.name,
                course.semester,
                json.dumps(course.sourcePages, ensure_ascii=False),
                json.dumps(course.allowedDomains, ensure_ascii=False),
                course.accessType,
                created_at,
                now,
            ),
        )
        return self.get_course(course.id)  # type: ignore[return-value]

    def get_course(self, course_id: str) -> CourseResponse | None:
        row = self.conn.execute("SELECT * FROM courses WHERE id = ?", (course_id,)).fetchone()
        return self._course_from_row(row) if row else None

    def list_documents(self, course_id: str, include_removed: bool = True) -> list[CourseDocumentResponse]:
        if include_removed:
            rows = self.conn.execute(
                "SELECT * FROM course_documents WHERE course_id = ? ORDER BY title",
                (course_id,),
            ).fetchall()
        else:
            rows = self.conn.execute(
                "SELECT * FROM course_documents WHERE course_id = ? AND status != 'removed' ORDER BY title",
                (course_id,),
            ).fetchall()
        return [self._document_from_row(row) for row in rows]

    def get_document_by_url(self, course_id: str, normalized_url: str) -> CourseDocumentResponse | None:
        row = self.conn.execute(
            "SELECT * FROM course_documents WHERE course_id = ? AND normalized_url = ?",
            (course_id, normalized_url),
        ).fetchone()
        return self._document_from_row(row) if row else None

    def get_active_documents(self, course_id: str) -> list[CourseDocumentResponse]:
        return self.list_documents(course_id, include_removed=False)

    def upsert_document(
        self,
        *,
        course_id: str,
        source_url: str,
        normalized_url: str,
        title: str | None,
        content_type: str | None,
        file_size: int | None,
        etag: str | None,
        last_modified: str | None,
        content_hash: str | None,
        status: str,
        vector_file_id: str | None = None,
        indexed_at: str | None = None,
    ) -> CourseDocumentResponse:
        now = utc_now()
        document_id = document_id_for(course_id, normalized_url)
        existing = self.conn.execute(
            "SELECT created_at FROM course_documents WHERE id = ?",
            (document_id,),
        ).fetchone()
        created_at = existing["created_at"] if existing else now
        self.conn.execute(
            """
            INSERT INTO course_documents (
                id, course_id, title, source_url, normalized_url, content_type,
                file_size, etag, last_modified, content_hash, status, vector_file_id,
                indexed_at, last_checked_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(course_id, normalized_url) DO UPDATE SET
                title=excluded.title,
                source_url=excluded.source_url,
                content_type=excluded.content_type,
                file_size=excluded.file_size,
                etag=excluded.etag,
                last_modified=excluded.last_modified,
                content_hash=excluded.content_hash,
                status=excluded.status,
                vector_file_id=excluded.vector_file_id,
                indexed_at=excluded.indexed_at,
                last_checked_at=excluded.last_checked_at,
                updated_at=excluded.updated_at
            """,
            (
                document_id,
                course_id,
                title or title_from_url(source_url),
                source_url,
                normalized_url,
                content_type,
                file_size,
                etag,
                last_modified,
                content_hash,
                status,
                vector_file_id,
                indexed_at,
                now,
                created_at,
                now,
            ),
        )
        return self.get_document_by_url(course_id, normalized_url)  # type: ignore[return-value]

    def touch_document_checked(self, course_id: str, normalized_url: str) -> None:
        self.conn.execute(
            "UPDATE course_documents SET last_checked_at = ?, updated_at = ? WHERE course_id = ? AND normalized_url = ?",
            (utc_now(), utc_now(), course_id, normalized_url),
        )

    def mark_removed_missing(self, course_id: str, discovered_urls: set[str]) -> int:
        rows = self.conn.execute(
            "SELECT normalized_url FROM course_documents WHERE course_id = ? AND status != 'removed'",
            (course_id,),
        ).fetchall()
        missing = [row["normalized_url"] for row in rows if row["normalized_url"] not in discovered_urls]
        if not missing:
            return 0
        now = utc_now()
        self.conn.executemany(
            "UPDATE course_documents SET status = 'removed', updated_at = ? WHERE course_id = ? AND normalized_url = ?",
            [(now, course_id, url) for url in missing],
        )
        return len(missing)

    def document_version(self, course_id: str) -> str:
        docs = self.get_active_documents(course_id)
        payload = [
            {
                "id": doc.id,
                "hash": doc.contentHash,
                "etag": doc.etag,
                "lastModified": doc.lastModified,
                "size": doc.fileSize,
            }
            for doc in docs
            if doc.status == "indexed"
        ]
        raw = json.dumps(payload, sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    @staticmethod
    def _course_from_row(row: Row) -> CourseResponse:
        return CourseResponse(
            id=row["id"],
            name=row["name"],
            semester=row["semester"],
            sourcePages=json.loads(row["source_pages_json"]),
            allowedDomains=json.loads(row["allowed_domains_json"]),
            accessType=row["access_type"],
            createdAt=row["created_at"],
            updatedAt=row["updated_at"],
        )

    @staticmethod
    def _document_from_row(row: Row) -> CourseDocumentResponse:
        return CourseDocumentResponse(
            id=row["id"],
            courseId=row["course_id"],
            title=row["title"],
            sourceUrl=row["source_url"],
            normalizedUrl=row["normalized_url"],
            contentType=row["content_type"],
            fileSize=row["file_size"],
            etag=row["etag"],
            lastModified=row["last_modified"],
            contentHash=row["content_hash"],
            status=row["status"],
            vectorFileId=row["vector_file_id"],
            indexedAt=row["indexed_at"],
            lastCheckedAt=row["last_checked_at"],
            createdAt=row["created_at"],
            updatedAt=row["updated_at"],
        )
