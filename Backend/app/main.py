from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db import Database
from app.mindmap.llm_client import VLLMChatClient
from app.routes import router


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="PathMate Backend", version="0.1.0")
    app.state.settings = settings
    app.state.database = Database(settings.database_path)
    app.state.llm_client = VLLMChatClient(settings)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost", "http://127.0.0.1", "http://localhost:3000", "http://127.0.0.1:3000"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(router)
    return app


app = create_app()
