from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from sqlite3 import Connection
from typing import Protocol

from app.courses.repository import utc_now
from app.courses.schemas import CourseDocumentResponse


@dataclass(frozen=True)
class MaterialChunk:
    chunkId: str
    documentId: str
    documentTitle: str
    sourceUrl: str
    page: int | None
    text: str
    score: float


class DocumentIndexProvider(Protocol):
    def create_course_index(self, course_id: str) -> str:
        ...

    def add_document(self, course_id: str, document: CourseDocumentResponse, text: str) -> str:
        ...

    def update_document(self, course_id: str, document: CourseDocumentResponse, text: str) -> str:
        ...

    def remove_document(self, course_id: str, document_id: str) -> None:
        ...

    def search_course_materials(self, course_id: str, query: str, limit: int = 8) -> list[MaterialChunk]:
        ...


class LocalKeywordIndexProvider:
    """A small SQLite-backed index for the MVP.

    It stores course-isolated text chunks and ranks them with simple keyword
    overlap. The protocol boundary lets a later vector provider replace it.
    """

    def __init__(self, conn: Connection):
        self.conn = conn

    def create_course_index(self, course_id: str) -> str:
        return f"local:{course_id}"

    def add_document(self, course_id: str, document: CourseDocumentResponse, text: str) -> str:
        return self._replace_document(course_id, document, text)

    def update_document(self, course_id: str, document: CourseDocumentResponse, text: str) -> str:
        return self._replace_document(course_id, document, text)

    def remove_document(self, course_id: str, document_id: str) -> None:
        self.conn.execute(
            "DELETE FROM document_chunks WHERE course_id = ? AND document_id = ?",
            (course_id, document_id),
        )

    def search_course_materials(self, course_id: str, query: str, limit: int = 8) -> list[MaterialChunk]:
        rows = self.conn.execute(
            """
            SELECT id, document_id, document_title, source_url, page, text
            FROM document_chunks
            WHERE course_id = ?
            """,
            (course_id,),
        ).fetchall()
        terms = _terms(query)
        ranked: list[MaterialChunk] = []
        for row in rows:
            score = _score(row["text"], terms)
            if score <= 0 and terms:
                continue
            ranked.append(
                MaterialChunk(
                    chunkId=row["id"],
                    documentId=row["document_id"],
                    documentTitle=row["document_title"],
                    sourceUrl=row["source_url"],
                    page=row["page"],
                    text=row["text"],
                    score=score,
                )
            )
        ranked.sort(key=lambda item: item.score, reverse=True)
        if not ranked:
            ranked = [
                MaterialChunk(
                    chunkId=row["id"],
                    documentId=row["document_id"],
                    documentTitle=row["document_title"],
                    sourceUrl=row["source_url"],
                    page=row["page"],
                    text=row["text"],
                    score=0,
                )
                for row in rows[:limit]
            ]
        return ranked[:limit]

    def _replace_document(self, course_id: str, document: CourseDocumentResponse, text: str) -> str:
        self.remove_document(course_id, document.id)
        vector_file_id = f"local:{document.id}"
        chunks = chunk_text(text or document.title or document.sourceUrl)
        now = utc_now()
        self.conn.executemany(
            """
            INSERT INTO document_chunks (
                id, course_id, document_id, chunk_index, document_title,
                source_url, page, text, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    f"chunk-{uuid.uuid4().hex}",
                    course_id,
                    document.id,
                    index,
                    document.title,
                    document.sourceUrl,
                    _page_from_chunk(chunk),
                    chunk,
                    now,
                )
                for index, chunk in enumerate(chunks)
            ],
        )
        return vector_file_id


def chunk_text(text: str, max_chars: int = 1400, overlap: int = 180) -> list[str]:
    cleaned = re.sub(r"\s+", " ", text).strip()
    if not cleaned:
        return []
    chunks: list[str] = []
    start = 0
    while start < len(cleaned):
        end = min(len(cleaned), start + max_chars)
        chunks.append(cleaned[start:end])
        if end == len(cleaned):
            break
        start = max(0, end - overlap)
    return chunks


def _terms(query: str) -> set[str]:
    words = {word.lower() for word in re.findall(r"[A-Za-z0-9_]{2,}", query)}
    chinese = {char for char in query if "\u4e00" <= char <= "\u9fff"}
    return words | chinese


def _score(text: str, terms: set[str]) -> float:
    if not terms:
        return 1.0
    lower = text.lower()
    return float(sum(lower.count(term.lower()) for term in terms))


def _page_from_chunk(chunk: str) -> int | None:
    match = re.search(r"\[page (\d+)\]", chunk)
    if not match:
        return None
    return int(match.group(1))
