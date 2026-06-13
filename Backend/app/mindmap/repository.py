from __future__ import annotations

import uuid
from sqlite3 import Connection

from app.courses.repository import utc_now
from app.mindmap.schemas import MindMapEdge, MindMapNode, MindMapResponse, MindMapSourceReference


class MindMapRepository:
    def __init__(self, conn: Connection):
        self.conn = conn

    def get_map(self, course_id: str) -> tuple[MindMapResponse, str] | None:
        row = self.conn.execute("SELECT * FROM mind_maps WHERE course_id = ?", (course_id,)).fetchone()
        if not row:
            return None
        return self._load_response(row), row["document_version"]

    def get_node(self, course_id: str, node_id: str) -> MindMapNode | None:
        row = self.conn.execute(
            "SELECT * FROM mind_map_nodes WHERE course_id = ? AND id = ?",
            (course_id, node_id),
        ).fetchone()
        if not row:
            return None
        sources = self.get_node_sources(course_id, node_id)
        return self._node_from_row(row, sources)

    def get_node_sources(self, course_id: str, node_id: str) -> list[MindMapSourceReference]:
        rows = self.conn.execute(
            """
            SELECT * FROM mind_map_sources
            WHERE course_id = ? AND node_id = ?
            ORDER BY document_title, page
            """,
            (course_id, node_id),
        ).fetchall()
        return [
            MindMapSourceReference(
                documentId=row["document_id"],
                documentTitle=row["document_title"],
                sourceUrl=row["source_url"],
                page=row["page"],
                chunkId=row["chunk_id"],
            )
            for row in rows
        ]

    def has_children(self, course_id: str, node_id: str) -> bool:
        row = self.conn.execute(
            "SELECT 1 FROM mind_map_nodes WHERE course_id = ? AND parent_id = ? LIMIT 1",
            (course_id, node_id),
        ).fetchone()
        return row is not None

    def get_children_response(self, course_id: str, node_id: str) -> MindMapResponse | None:
        parent = self.get_node(course_id, node_id)
        if parent is None:
            return None
        node_rows = self.conn.execute(
            "SELECT * FROM mind_map_nodes WHERE course_id = ? AND parent_id = ? ORDER BY title",
            (course_id, node_id),
        ).fetchall()
        if not node_rows:
            return None
        nodes = [self._node_from_row(row, self.get_node_sources(course_id, row["id"])) for row in node_rows]
        child_ids = {node.id for node in nodes}
        edge_rows = self.conn.execute(
            """
            SELECT * FROM mind_map_edges
            WHERE course_id = ? AND from_node = ? AND to_node IN (%s)
            """
            % ",".join("?" for _ in child_ids),
            (course_id, node_id, *child_ids),
        ).fetchall()
        edges = [
            MindMapEdge(**{"id": row["id"], "from": row["from_node"], "to": row["to_node"], "relation": row["relation"]})
            for row in edge_rows
        ]
        return MindMapResponse(
            courseId=course_id,
            title=f"{parent.title} 展开",
            rootNodeId=node_id,
            nodes=nodes,
            edges=edges,
        )

    def save_top_level(self, course_id: str, response: MindMapResponse, document_version: str) -> MindMapResponse:
        now = utc_now()
        mind_map_id = f"map-{uuid.uuid4().hex}"
        self.conn.execute("DELETE FROM mind_maps WHERE course_id = ?", (course_id,))
        self.conn.execute(
            """
            INSERT INTO mind_maps (
                id, course_id, title, root_node_id, document_version, generated_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (mind_map_id, course_id, response.title, response.rootNodeId, document_version, now, now),
        )
        self._insert_nodes_edges_sources(course_id, mind_map_id, response, generation_version=document_version)
        return response

    def save_expansion(self, course_id: str, response: MindMapResponse, generation_version: str) -> MindMapResponse:
        row = self.conn.execute("SELECT * FROM mind_maps WHERE course_id = ?", (course_id,)).fetchone()
        if not row:
            raise ValueError("top-level mind map must exist before expansion")
        self._insert_nodes_edges_sources(course_id, row["id"], response, generation_version=generation_version)
        self.conn.execute(
            "UPDATE mind_maps SET updated_at = ? WHERE course_id = ?",
            (utc_now(), course_id),
        )
        return response

    def existing_node_ids(self, course_id: str) -> set[str]:
        rows = self.conn.execute("SELECT id FROM mind_map_nodes WHERE course_id = ?", (course_id,)).fetchall()
        return {row["id"] for row in rows}

    def _load_response(self, map_row) -> MindMapResponse:
        course_id = map_row["course_id"]
        node_rows = self.conn.execute(
            "SELECT * FROM mind_map_nodes WHERE course_id = ? ORDER BY depth, title",
            (course_id,),
        ).fetchall()
        edge_rows = self.conn.execute(
            "SELECT * FROM mind_map_edges WHERE course_id = ? ORDER BY id",
            (course_id,),
        ).fetchall()
        nodes = [self._node_from_row(row, self.get_node_sources(course_id, row["id"])) for row in node_rows]
        edges = [
            MindMapEdge(**{"id": row["id"], "from": row["from_node"], "to": row["to_node"], "relation": row["relation"]})
            for row in edge_rows
        ]
        return MindMapResponse(
            courseId=course_id,
            title=map_row["title"],
            rootNodeId=map_row["root_node_id"],
            nodes=nodes,
            edges=edges,
        )

    def _insert_nodes_edges_sources(
        self,
        course_id: str,
        mind_map_id: str,
        response: MindMapResponse,
        *,
        generation_version: str,
    ) -> None:
        now = utc_now()
        for node in response.nodes:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO mind_map_nodes (
                    id, course_id, mind_map_id, parent_id, title, summary, type, depth,
                    importance, has_more_children, evidence_level, generation_version,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    node.id,
                    course_id,
                    mind_map_id,
                    node.parentId,
                    node.title,
                    node.summary,
                    node.type,
                    node.depth,
                    node.importance,
                    1 if node.hasMoreChildren else 0,
                    node.evidenceLevel,
                    generation_version,
                    now,
                    now,
                ),
            )
            self.conn.execute(
                "DELETE FROM mind_map_sources WHERE course_id = ? AND node_id = ?",
                (course_id, node.id),
            )
            self.conn.executemany(
                """
                INSERT INTO mind_map_sources (
                    id, course_id, node_id, document_id, document_title, source_url,
                    page, chunk_id, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        f"src-{uuid.uuid4().hex}",
                        course_id,
                        node.id,
                        ref.documentId,
                        ref.documentTitle,
                        ref.sourceUrl,
                        ref.page,
                        ref.chunkId,
                        now,
                    )
                    for ref in node.sourceRefs
                ],
            )
        for edge in response.edges:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO mind_map_edges (
                    id, course_id, mind_map_id, from_node, to_node, relation
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (edge.id, course_id, mind_map_id, edge.from_, edge.to, edge.relation),
            )

    @staticmethod
    def _node_from_row(row, sources: list[MindMapSourceReference]) -> MindMapNode:
        return MindMapNode(
            id=row["id"],
            parentId=row["parent_id"],
            title=row["title"],
            summary=row["summary"],
            type=row["type"],
            depth=row["depth"],
            importance=row["importance"],
            hasMoreChildren=bool(row["has_more_children"]),
            evidenceLevel=row["evidence_level"],
            sourceRefs=sources,
        )
