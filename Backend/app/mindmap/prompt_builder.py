from __future__ import annotations

import json
from pathlib import Path

from app.courses.schemas import CourseResponse
from app.indexing.provider import MaterialChunk
from app.mindmap.schemas import MindMapNode


MIND_MAP_JSON_SCHEMA = {
    "type": "object",
    "required": ["courseId", "title", "rootNodeId", "nodes", "edges"],
    "properties": {
        "courseId": {"type": "string"},
        "title": {"type": "string"},
        "rootNodeId": {"type": "string"},
        "nodes": {
            "type": "array",
            "items": {
                "type": "object",
                "required": [
                    "id",
                    "parentId",
                    "title",
                    "summary",
                    "type",
                    "depth",
                    "importance",
                    "hasMoreChildren",
                    "evidenceLevel",
                    "sourceRefs",
                ],
            },
        },
        "edges": {"type": "array"},
    },
}


class PromptBuilder:
    def __init__(self, prompt_path: Path):
        self.prompt_path = prompt_path
        self._system_prompt: str | None = None

    @property
    def system_prompt(self) -> str:
        if self._system_prompt is None:
            base = self.prompt_path.read_text(encoding="utf-8")
            self._system_prompt = (
                base
                + "\n\n"
                + "后端执行约束：你是课程思维导图生成 Agent。只返回 JSON object，不返回 Markdown、解释文字或代码。"
                + "所有节点必须严格依据用户消息中的 courseMaterials。"
            )
        return self._system_prompt

    def build_top_level_messages(
        self,
        *,
        course: CourseResponse,
        chunks: list[MaterialChunk],
    ) -> list[dict[str, str]]:
        payload = {
            "task": "generateTopLevelMindMap",
            "course": course.dict(),
            "requirements": [
                "生成课程根节点以及前 1 到 2 层直接知识结构。",
                "rootNodeId 必须是 node-root。",
                "根节点 parentId 必须是 null，title 使用课程名。",
                "每个非根节点 parentId 必须指向已有节点。",
                "每个节点都必须带 sourceRefs，sourceUrl/documentId 必须来自 courseMaterials。",
                "不要生成 UI 坐标，不要输出 Markdown。",
            ],
            "jsonSchema": MIND_MAP_JSON_SCHEMA,
            "courseMaterials": [chunk.__dict__ for chunk in chunks],
        }
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
        ]

    def build_expand_messages(
        self,
        *,
        course: CourseResponse,
        parent_node: MindMapNode,
        chunks: list[MaterialChunk],
        requested_depth: int,
    ) -> list[dict[str, str]]:
        payload = {
            "task": "expandMindMapNode",
            "course": course.dict(),
            "parentNode": parent_node.dict(by_alias=True),
            "requestedDepth": requested_depth,
            "requirements": [
                "只生成 parentNode 的直接子节点，nodes 中不要重复 parentNode。",
                "返回 JSON object，rootNodeId 必须等于 parentNode.id。",
                "每个新节点 parentId 必须等于 parentNode.id。",
                "每条边 from 必须等于 parentNode.id，to 必须指向新节点。",
                "只依据 courseMaterials，材料不足时 evidenceLevel=insufficient。",
            ],
            "jsonSchema": MIND_MAP_JSON_SCHEMA,
            "courseMaterials": [chunk.__dict__ for chunk in chunks],
        }
        return [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
        ]

    def build_repair_messages(
        self,
        *,
        previous_messages: list[dict[str, str]],
        raw_response: str,
        validation_errors: list[str],
    ) -> list[dict[str, str]]:
        repair_payload = {
            "task": "repairMindMapJson",
            "validationErrors": validation_errors,
            "previousResponse": raw_response,
            "requirements": [
                "修复为符合 JSON Schema 和校验规则的 JSON object。",
                "不要新增 courseMaterials 中没有依据的节点。",
                "只返回 JSON object。",
            ],
        }
        return previous_messages + [
            {"role": "assistant", "content": raw_response},
            {"role": "user", "content": json.dumps(repair_payload, ensure_ascii=False)},
        ]
