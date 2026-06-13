from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS courses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    semester TEXT NOT NULL,
    source_pages_json TEXT NOT NULL,
    allowed_domains_json TEXT NOT NULL,
    access_type TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS course_documents (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    source_url TEXT NOT NULL,
    normalized_url TEXT NOT NULL,
    content_type TEXT,
    file_size INTEGER,
    etag TEXT,
    last_modified TEXT,
    content_hash TEXT,
    status TEXT NOT NULL,
    vector_file_id TEXT,
    indexed_at TEXT,
    last_checked_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(course_id, normalized_url)
);

CREATE TABLE IF NOT EXISTS document_chunks (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL REFERENCES course_documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    document_title TEXT NOT NULL,
    source_url TEXT NOT NULL,
    page INTEGER,
    text TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_document_chunks_course ON document_chunks(course_id);
CREATE INDEX IF NOT EXISTS idx_course_documents_course ON course_documents(course_id);

CREATE TABLE IF NOT EXISTS mind_maps (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL UNIQUE REFERENCES courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    root_node_id TEXT NOT NULL,
    document_version TEXT NOT NULL,
    generated_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mind_map_nodes (
    id TEXT NOT NULL,
    course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    mind_map_id TEXT NOT NULL REFERENCES mind_maps(id) ON DELETE CASCADE,
    parent_id TEXT,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    type TEXT NOT NULL,
    depth INTEGER NOT NULL,
    importance REAL NOT NULL,
    has_more_children INTEGER NOT NULL,
    evidence_level TEXT NOT NULL,
    generation_version TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(course_id, id)
);

CREATE TABLE IF NOT EXISTS mind_map_edges (
    id TEXT NOT NULL,
    course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    mind_map_id TEXT NOT NULL REFERENCES mind_maps(id) ON DELETE CASCADE,
    from_node TEXT NOT NULL,
    to_node TEXT NOT NULL,
    relation TEXT NOT NULL,
    PRIMARY KEY(course_id, id)
);

CREATE TABLE IF NOT EXISTS mind_map_sources (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    node_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    document_title TEXT NOT NULL,
    source_url TEXT NOT NULL,
    page INTEGER,
    chunk_id TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mind_map_sources_node ON mind_map_sources(course_id, node_id);
"""


class Database:
    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.init_schema()

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def init_schema(self) -> None:
        with self.connect() as conn:
            conn.executescript(SCHEMA)

    @contextmanager
    def session(self) -> Iterator[sqlite3.Connection]:
        conn = self.connect()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
