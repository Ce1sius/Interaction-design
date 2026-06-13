from __future__ import annotations

from pydantic import BaseModel, Field, validator


class MindMapSourceReference(BaseModel):
    documentId: str
    documentTitle: str
    sourceUrl: str
    page: int | None = None
    chunkId: str | None = None


class MindMapNode(BaseModel):
    id: str = Field(..., min_length=1)
    parentId: str | None = None
    title: str = Field(..., min_length=1, max_length=120)
    summary: str = Field(default="", max_length=600)
    type: str
    depth: int = Field(..., ge=0, le=12)
    importance: float = Field(..., ge=0, le=1)
    hasMoreChildren: bool = False
    evidenceLevel: str
    sourceRefs: list[MindMapSourceReference] = Field(default_factory=list)

    @validator("type")
    def validate_type(cls, value: str) -> str:
        allowed = {
            "course",
            "chapter",
            "concept",
            "definition",
            "theorem",
            "method",
            "example",
            "skill",
            "vocabulary",
            "grammar",
            "exercise",
        }
        if value not in allowed:
            raise ValueError("unsupported node type")
        return value

    @validator("evidenceLevel")
    def validate_evidence_level(cls, value: str) -> str:
        if value not in {"strong", "partial", "insufficient"}:
            raise ValueError("unsupported evidence level")
        return value


class MindMapEdge(BaseModel):
    id: str = Field(..., min_length=1)
    from_: str = Field(..., alias="from")
    to: str
    relation: str = "contains"


class MindMapResponse(BaseModel):
    courseId: str
    title: str
    rootNodeId: str
    nodes: list[MindMapNode]
    edges: list[MindMapEdge]


class MindMapExpansionRequest(BaseModel):
    nodeId: str
    requestedDepth: int = Field(default=1, ge=1, le=2)


class ValidationErrorResponse(BaseModel):
    errors: list[str]
