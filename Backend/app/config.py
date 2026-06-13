from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


@dataclass(frozen=True)
class Settings:
    project_root: Path
    backend_dir: Path
    database_path: Path
    prompt_path: Path
    vllm_base_url: str
    vllm_api_key: str | None
    vllm_model: str | None
    max_pdf_bytes: int
    request_timeout_seconds: float
    llm_timeout_seconds: float
    llm_max_tokens: int
    enable_ocr: bool
    ocr_language: str
    ocr_max_pages: int
    zju_learning_cookie: str | None


@lru_cache
def get_settings() -> Settings:
    backend_dir = Path(__file__).resolve().parents[1]
    project_root = backend_dir.parent
    _load_env_file(backend_dir / ".env")

    db_path = Path(os.getenv("BACKEND_DB_PATH", str(backend_dir / "data" / "pathmate.db")))
    if not db_path.is_absolute():
        db_path = project_root / db_path

    return Settings(
        project_root=project_root,
        backend_dir=backend_dir,
        database_path=db_path,
        prompt_path=project_root / "prompt.md",
        vllm_base_url=os.getenv("VLLM_BASE_URL", "http://221.12.22.187:30964/v1").rstrip("/"),
        vllm_api_key=os.getenv("VLLM_API_KEY") or None,
        vllm_model=os.getenv("VLLM_MODEL") or None,
        max_pdf_bytes=int(os.getenv("MAX_PDF_BYTES", str(50 * 1024 * 1024))),
        request_timeout_seconds=float(os.getenv("REQUEST_TIMEOUT_SECONDS", "20")),
        llm_timeout_seconds=float(os.getenv("LLM_TIMEOUT_SECONDS", "120")),
        llm_max_tokens=int(os.getenv("LLM_MAX_TOKENS", "8192")),
        enable_ocr=os.getenv("ENABLE_OCR", "false").strip().lower() in {"1", "true", "yes", "on"},
        ocr_language=os.getenv("OCR_LANGUAGE", "chi_sim+eng"),
        ocr_max_pages=int(os.getenv("OCR_MAX_PAGES", "6")),
        zju_learning_cookie=os.getenv("ZJU_LEARNING_COOKIE") or None,
    )
