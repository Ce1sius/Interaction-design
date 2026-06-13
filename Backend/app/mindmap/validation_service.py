from __future__ import annotations

from dataclasses import dataclass

from pydantic import ValidationError

from app.courses.schemas import CourseDocumentResponse
from app.mindmap.schemas import MindMapNode, MindMapResponse


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    errors: list[str]
    response: MindMapResponse | None = None


class MindMapValidationService:
    def validate_top_level(
        self,
        *,
        course_id: str,
        payload: dict,
        documents: list[CourseDocumentResponse],
        max_nodes: int = 80,
    ) -> ValidationResult:
        try:
            response = MindMapResponse.parse_obj(payload)
        except ValidationError as exc:
            return ValidationResult(valid=False, errors=[str(exc)])
        errors = self._common_errors(course_id, response, documents, max_nodes=max_nodes)
        if response.rootNodeId not in {node.id for node in response.nodes}:
            errors.append("rootNodeId must point to a returned node")
        roots = [node for node in response.nodes if node.parentId is None]
        if len(roots) != 1:
            errors.append("top-level response must contain exactly one root node")
        elif roots[0].id != response.rootNodeId:
            errors.append("root node id must equal rootNodeId")
        errors.extend(self._depth_errors(response.nodes))
        errors.extend(self._cycle_errors(response.nodes))
        return ValidationResult(valid=not errors, errors=errors, response=response if not errors else None)

    def validate_expansion(
        self,
        *,
        course_id: str,
        payload: dict,
        documents: list[CourseDocumentResponse],
        parent_node: MindMapNode,
        existing_node_ids: set[str],
        max_nodes: int = 24,
    ) -> ValidationResult:
        try:
            response = MindMapResponse.parse_obj(payload)
        except ValidationError as exc:
            return ValidationResult(valid=False, errors=[str(exc)])
        errors = self._common_errors(
            course_id,
            response,
            documents,
            max_nodes=max_nodes,
            extra_known_node_ids=existing_node_ids,
        )
        if response.rootNodeId != parent_node.id:
            errors.append("expansion rootNodeId must equal the requested parent node id")
        for node in response.nodes:
            if node.id == parent_node.id:
                errors.append("expansion nodes must not repeat the parent node")
            if node.parentId != parent_node.id:
                errors.append(f"node {node.id} must be a direct child of {parent_node.id}")
            if node.depth != parent_node.depth + 1:
                errors.append(f"node {node.id} depth must be parent depth + 1")
        for edge in response.edges:
            if edge.from_ != parent_node.id:
                errors.append(f"edge {edge.id} must start from {parent_node.id}")
        return ValidationResult(valid=not errors, errors=errors, response=response if not errors else None)

    def _common_errors(
        self,
        course_id: str,
        response: MindMapResponse,
        documents: list[CourseDocumentResponse],
        *,
        max_nodes: int,
        extra_known_node_ids: set[str] | None = None,
    ) -> list[str]:
        errors: list[str] = []
        if response.courseId != course_id:
            errors.append("courseId mismatch")
        if len(response.nodes) > max_nodes:
            errors.append(f"node count exceeds limit {max_nodes}")

        node_ids = [node.id for node in response.nodes]
        edge_ids = [edge.id for edge in response.edges]
        if len(node_ids) != len(set(node_ids)):
            errors.append("node ids must be unique")
        if len(edge_ids) != len(set(edge_ids)):
            errors.append("edge ids must be unique")

        known_ids = set(node_ids) | (extra_known_node_ids or set())
        for edge in response.edges:
            if edge.from_ not in known_ids:
                errors.append(f"edge {edge.id} from points to missing node {edge.from_}")
            if edge.to not in known_ids:
                errors.append(f"edge {edge.id} to points to missing node {edge.to}")

        titles: set[str] = set()
        for node in response.nodes:
            title_key = node.title.strip().lower()
            if title_key in titles:
                errors.append(f"duplicate node title: {node.title}")
            titles.add(title_key)
            if not node.sourceRefs:
                errors.append(f"node {node.id} has no sourceRefs")
            if node.parentId and node.parentId not in known_ids:
                errors.append(f"node {node.id} parentId points to missing node {node.parentId}")

        doc_ids = {doc.id for doc in documents if doc.status != "removed"}
        source_urls = {doc.sourceUrl for doc in documents if doc.status != "removed"}
        source_urls |= {doc.normalizedUrl for doc in documents if doc.status != "removed"}
        for node in response.nodes:
            for ref in node.sourceRefs:
                if ref.documentId not in doc_ids:
                    errors.append(f"node {node.id} source documentId {ref.documentId} is not in this course")
                if ref.sourceUrl not in source_urls:
                    errors.append(f"node {node.id} sourceUrl is not registered for this course")
        return errors

    @staticmethod
    def _depth_errors(nodes: list[MindMapNode]) -> list[str]:
        errors: list[str] = []
        by_id = {node.id: node for node in nodes}
        for node in nodes:
            if node.parentId is None:
                if node.depth != 0:
                    errors.append(f"root node {node.id} depth must be 0")
                continue
            parent = by_id.get(node.parentId)
            if parent and node.depth != parent.depth + 1:
                errors.append(f"node {node.id} depth must be parent depth + 1")
        return errors

    @staticmethod
    def _cycle_errors(nodes: list[MindMapNode]) -> list[str]:
        errors: list[str] = []
        parent = {node.id: node.parentId for node in nodes}
        for node in nodes:
            seen: set[str] = set()
            current = node.id
            while current in parent and parent[current] is not None:
                if current in seen:
                    errors.append(f"cycle detected at node {node.id}")
                    break
                seen.add(current)
                current = parent[current]  # type: ignore[assignment]
        return errors
