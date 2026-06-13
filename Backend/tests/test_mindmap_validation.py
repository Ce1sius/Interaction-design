from app.courses.schemas import CourseDocumentResponse
from app.mindmap.validation_service import MindMapValidationService


def _doc():
    return CourseDocumentResponse(
        id="doc-1",
        courseId="data-structure",
        title="chapter01.pdf",
        sourceUrl="https://school.example.edu/chapter01.pdf",
        normalizedUrl="https://school.example.edu/chapter01.pdf",
        contentType="application/pdf",
        fileSize=128,
        etag=None,
        lastModified=None,
        contentHash="abc",
        status="indexed",
        vectorFileId="local:doc-1",
        indexedAt="2026-06-13T00:00:00+00:00",
        lastCheckedAt="2026-06-13T00:00:00+00:00",
        createdAt="2026-06-13T00:00:00+00:00",
        updatedAt="2026-06-13T00:00:00+00:00",
    )


def _valid_payload():
    ref = {
        "documentId": "doc-1",
        "documentTitle": "chapter01.pdf",
        "sourceUrl": "https://school.example.edu/chapter01.pdf",
        "page": 1,
        "chunkId": "chunk-1",
    }
    return {
        "courseId": "data-structure",
        "title": "数据结构知识地图",
        "rootNodeId": "node-root",
        "nodes": [
            {
                "id": "node-root",
                "parentId": None,
                "title": "数据结构",
                "summary": "课程根节点。",
                "type": "course",
                "depth": 0,
                "importance": 1.0,
                "hasMoreChildren": True,
                "evidenceLevel": "strong",
                "sourceRefs": [ref],
            },
            {
                "id": "node-list",
                "parentId": "node-root",
                "title": "线性表",
                "summary": "来自课程材料的章节。",
                "type": "chapter",
                "depth": 1,
                "importance": 0.8,
                "hasMoreChildren": True,
                "evidenceLevel": "strong",
                "sourceRefs": [ref],
            },
        ],
        "edges": [{"id": "edge-root-list", "from": "node-root", "to": "node-list", "relation": "contains"}],
    }


def test_valid_top_level_payload_passes():
    result = MindMapValidationService().validate_top_level(
        course_id="data-structure",
        payload=_valid_payload(),
        documents=[_doc()],
    )

    assert result.valid
    assert result.response is not None


def test_source_from_other_course_fails():
    payload = _valid_payload()
    payload["nodes"][1]["sourceRefs"][0]["documentId"] = "doc-other"

    result = MindMapValidationService().validate_top_level(
        course_id="data-structure",
        payload=payload,
        documents=[_doc()],
    )

    assert not result.valid
    assert any("not in this course" in error for error in result.errors)
