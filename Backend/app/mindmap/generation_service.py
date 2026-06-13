from __future__ import annotations

import asyncio
import hashlib
from collections import defaultdict

from app.courses.repository import CourseRepository
from app.indexing.provider import LocalKeywordIndexProvider
from app.mindmap.llm_client import VLLMChatClient
from app.mindmap.prompt_builder import PromptBuilder
from app.mindmap.repository import MindMapRepository
from app.mindmap.schemas import MindMapResponse
from app.mindmap.validation_service import MindMapValidationService


class MindMapGenerationError(RuntimeError):
    def __init__(self, message: str, errors: list[str] | None = None):
        super().__init__(message)
        self.errors = errors or [message]


class MindMapGenerationService:
    _locks: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)

    def __init__(
        self,
        *,
        course_repository: CourseRepository,
        mindmap_repository: MindMapRepository,
        index_provider: LocalKeywordIndexProvider,
        prompt_builder: PromptBuilder,
        llm_client: VLLMChatClient,
        validation_service: MindMapValidationService,
    ):
        self.course_repository = course_repository
        self.mindmap_repository = mindmap_repository
        self.index_provider = index_provider
        self.prompt_builder = prompt_builder
        self.llm_client = llm_client
        self.validation_service = validation_service

    async def get_or_generate_top_level(self, course_id: str) -> MindMapResponse:
        document_version = self.course_repository.document_version(course_id)
        cached = self.mindmap_repository.get_map(course_id)
        if cached and cached[1] == document_version:
            return cached[0]
        return await self.regenerate_top_level(course_id)

    async def regenerate_top_level(self, course_id: str) -> MindMapResponse:
        lock = self._locks[f"{course_id}:root"]
        async with lock:
            course = self.course_repository.get_course(course_id)
            if course is None:
                raise KeyError("course not found")
            documents = self.course_repository.get_active_documents(course_id)
            indexed_documents = [doc for doc in documents if doc.status == "indexed"]
            if not indexed_documents:
                raise MindMapGenerationError("no indexed course materials; run sync-materials first")

            chunks = self.index_provider.search_course_materials(
                course_id,
                f"{course.name} 课程章节 目录 知识结构",
                limit=12,
            )
            if not chunks:
                raise MindMapGenerationError("no indexed chunks found for this course")
            messages = self.prompt_builder.build_top_level_messages(course=course, chunks=chunks)
            response = await asyncio.to_thread(self._call_and_validate_top_level, course_id, messages, documents)
            document_version = self.course_repository.document_version(course_id)
            return self.mindmap_repository.save_top_level(course_id, response, document_version)

    async def expand_node(self, course_id: str, node_id: str, requested_depth: int = 1) -> MindMapResponse:
        lock = self._locks[f"{course_id}:{node_id}"]
        async with lock:
            cached = self.mindmap_repository.get_children_response(course_id, node_id)
            if cached:
                return cached

            course = self.course_repository.get_course(course_id)
            if course is None:
                raise KeyError("course not found")
            parent_node = self.mindmap_repository.get_node(course_id, node_id)
            if parent_node is None:
                cached_map = self.mindmap_repository.get_map(course_id)
                if cached_map is None:
                    await self.get_or_generate_top_level(course_id)
                parent_node = self.mindmap_repository.get_node(course_id, node_id)
            if parent_node is None:
                raise KeyError("node not found")

            documents = self.course_repository.get_active_documents(course_id)
            chunks = self.index_provider.search_course_materials(
                course_id,
                f"{parent_node.title} {parent_node.summary}",
                limit=10,
            )
            if not chunks:
                raise MindMapGenerationError("no indexed chunks found for requested node")
            messages = self.prompt_builder.build_expand_messages(
                course=course,
                parent_node=parent_node,
                chunks=chunks,
                requested_depth=requested_depth,
            )
            response = await asyncio.to_thread(
                self._call_and_validate_expansion,
                course_id=course_id,
                messages=messages,
                documents=documents,
                parent_node=parent_node,
            )
            generation_version = self._generation_version(course_id, node_id)
            return self.mindmap_repository.save_expansion(course_id, response, generation_version)

    def _call_and_validate_top_level(self, course_id: str, messages: list[dict[str, str]], documents) -> MindMapResponse:
        result = self.llm_client.generate_json(messages)
        validation = self.validation_service.validate_top_level(
            course_id=course_id,
            payload=result.parsed,
            documents=documents,
        )
        if validation.valid and validation.response:
            return validation.response

        repair_messages = self.prompt_builder.build_repair_messages(
            previous_messages=messages,
            raw_response=result.raw,
            validation_errors=validation.errors,
        )
        repaired = self.llm_client.generate_json(repair_messages)
        repaired_validation = self.validation_service.validate_top_level(
            course_id=course_id,
            payload=repaired.parsed,
            documents=documents,
        )
        if repaired_validation.valid and repaired_validation.response:
            return repaired_validation.response
        raise MindMapGenerationError("model output failed validation", repaired_validation.errors)

    def _call_and_validate_expansion(self, *, course_id: str, messages, documents, parent_node) -> MindMapResponse:
        existing_node_ids = self.mindmap_repository.existing_node_ids(course_id)
        result = self.llm_client.generate_json(messages)
        validation = self.validation_service.validate_expansion(
            course_id=course_id,
            payload=result.parsed,
            documents=documents,
            parent_node=parent_node,
            existing_node_ids=existing_node_ids,
        )
        if validation.valid and validation.response:
            return validation.response

        repair_messages = self.prompt_builder.build_repair_messages(
            previous_messages=messages,
            raw_response=result.raw,
            validation_errors=validation.errors,
        )
        repaired = self.llm_client.generate_json(repair_messages)
        repaired_validation = self.validation_service.validate_expansion(
            course_id=course_id,
            payload=repaired.parsed,
            documents=documents,
            parent_node=parent_node,
            existing_node_ids=existing_node_ids,
        )
        if repaired_validation.valid and repaired_validation.response:
            return repaired_validation.response
        raise MindMapGenerationError("model output failed validation", repaired_validation.errors)

    def _generation_version(self, course_id: str, node_id: str) -> str:
        base = f"{course_id}:{node_id}:{self.course_repository.document_version(course_id)}"
        return hashlib.sha256(base.encode("utf-8")).hexdigest()
