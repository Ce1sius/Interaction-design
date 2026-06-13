from __future__ import annotations

from pydantic import BaseModel, Field, validator


class CourseCreate(BaseModel):
    id: str = Field(..., min_length=1, max_length=80)
    name: str = Field(..., min_length=1, max_length=120)
    semester: str = Field(default="2026-spring", min_length=1, max_length=80)
    sourcePages: list[str] = Field(default_factory=list)
    allowedDomains: list[str] = Field(default_factory=list)
    accessType: str = "publicWeb"

    @validator("id")
    def validate_id(cls, value: str) -> str:
        cleaned = value.strip()
        allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        if not cleaned or any(ch not in allowed for ch in cleaned):
            raise ValueError("course id may only contain letters, numbers, '-' and '_'")
        return cleaned

    @validator("sourcePages", "allowedDomains")
    def validate_non_empty_items(cls, value: list[str]) -> list[str]:
        cleaned = [item.strip() for item in value if item and item.strip()]
        return cleaned

    @validator("accessType")
    def validate_access_type(cls, value: str) -> str:
        if value not in {"publicWeb", "officialAPI", "authenticated"}:
            raise ValueError("unsupported accessType")
        return value


class CourseResponse(BaseModel):
    id: str
    name: str
    semester: str
    sourcePages: list[str]
    allowedDomains: list[str]
    accessType: str
    createdAt: str
    updatedAt: str


class ImportedCourseConfig(BaseModel):
    id: str | None = None
    name: str = Field(..., min_length=1, max_length=120)
    semester: str = "2026-spring"


class ImportedCoursesRequest(BaseModel):
    courses: list[ImportedCourseConfig]


class CourseDocumentResponse(BaseModel):
    id: str
    courseId: str
    title: str
    sourceUrl: str
    normalizedUrl: str
    contentType: str | None = None
    fileSize: int | None = None
    etag: str | None = None
    lastModified: str | None = None
    contentHash: str | None = None
    status: str
    vectorFileId: str | None = None
    indexedAt: str | None = None
    lastCheckedAt: str | None = None
    createdAt: str
    updatedAt: str


class SyncStats(BaseModel):
    courseId: str
    discovered: int = 0
    added: int = 0
    updated: int = 0
    unchanged: int = 0
    removed: int = 0
    failed: int = 0


class AuthSession(BaseModel):
    cookieHeader: str | None = None
    headers: dict[str, str] = Field(default_factory=dict)

    @validator("headers")
    def validate_headers(cls, value: dict[str, str]) -> dict[str, str]:
        blocked = {"host", "content-length", "connection"}
        cleaned: dict[str, str] = {}
        for key, header_value in value.items():
            normalized = key.strip()
            if not normalized or normalized.lower() in blocked:
                continue
            cleaned[normalized] = header_value
        return cleaned


class SyncMaterialsRequest(BaseModel):
    adapter: str = "auto"
    auth: AuthSession | None = None
    useBrowserFallback: bool = True

    @validator("adapter")
    def validate_adapter(cls, value: str) -> str:
        if value not in {"auto", "staticHtml", "browser", "zjuLearning"}:
            raise ValueError("unsupported sync adapter")
        return value
