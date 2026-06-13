from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

import httpx

from app.config import Settings


NON_THINKING_SAMPLING = {
    "temperature": 0.7,
    "top_p": 0.80,
    "presence_penalty": 1.5,
    "extra_body": {
        "top_k": 20,
        "min_p": 0.0,
        "repetition_penalty": 1.0,
        "chat_template_kwargs": {"enable_thinking": False},
    },
}


@dataclass(frozen=True)
class LLMJSONResult:
    parsed: dict[str, Any]
    raw: str


class VLLMChatClient:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client = None
        self._model: str | None = settings.vllm_model

    def _ensure_client(self):
        if not self.settings.vllm_api_key:
            raise RuntimeError("VLLM_API_KEY is not configured")
        if self._client is None:
            try:
                from openai import OpenAI
            except Exception as exc:
                raise RuntimeError("openai package is not installed") from exc
            self._client = OpenAI(
                base_url=self.settings.vllm_base_url,
                api_key=self.settings.vllm_api_key,
                http_client=httpx.Client(timeout=self.settings.llm_timeout_seconds, trust_env=False),
            )
        return self._client

    def model_id(self) -> str:
        if self._model:
            return self._model
        client = self._ensure_client()
        models = client.models.list()
        if not models.data:
            raise RuntimeError("vLLM /v1/models returned no models")
        self._model = models.data[0].id
        return self._model

    def generate_json(self, messages: list[dict[str, str]], max_tokens: int | None = None) -> LLMJSONResult:
        client = self._ensure_client()
        response = client.chat.completions.create(
            model=self.model_id(),
            messages=messages,
            max_tokens=max_tokens or self.settings.llm_max_tokens,
            response_format={"type": "json_object"},
            **NON_THINKING_SAMPLING,
        )
        choice = response.choices[0]
        raw = choice.message.content or ""
        if choice.finish_reason == "length":
            raise RuntimeError("model output was truncated; increase LLM_MAX_TOKENS or reduce mind-map breadth")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"model did not return valid JSON: {exc}") from exc
        if not isinstance(parsed, dict):
            raise RuntimeError("model JSON response must be an object")
        return LLMJSONResult(parsed=parsed, raw=raw)
