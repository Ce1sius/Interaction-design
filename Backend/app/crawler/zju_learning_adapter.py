from __future__ import annotations

import json
from dataclasses import dataclass
from urllib.parse import urlencode

import httpx

from app.courses.schemas import CourseResponse
from app.crawler.auth import AuthContext
from app.crawler.domain_validator import DomainValidator
from app.crawler.static_html_adapter import DiscoveryResult
from app.crawler.url_normalizer import normalize_url


BASE_URL = "https://courses.zju.edu.cn"


@dataclass(frozen=True)
class ZJULearningUpload:
    title: str
    url: str


class ZJULearningSourceAdapter:
    """Adapter matching the existing iOS ZJULearningMaterialService flow."""

    def __init__(self, timeout_seconds: float = 20):
        self.timeout_seconds = timeout_seconds

    async def discover_pdf_links(self, course: CourseResponse, auth: AuthContext) -> DiscoveryResult:
        validator = DomainValidator(course.allowedDomains)
        validator.validate_url(BASE_URL)
        headers = {
            "Accept": "application/json, text/plain, */*",
            **auth.request_headers(),
        }
        errors: list[str] = []
        uploads: list[ZJULearningUpload] = []
        async with httpx.AsyncClient(timeout=self.timeout_seconds, trust_env=False) as client:
            try:
                await self._warm_session(client, headers)
                remote_courses = await self._remote_courses(client, headers)
                remote = self._best_match(course.name, remote_courses)
                if remote is None:
                    return DiscoveryResult(links=[], errors=[f"no matching ZJU Learning course for {course.name}"], titles={})
                uploads.extend(await self._activity_uploads(client, remote["id"], headers))
                uploads.extend(await self._homework_uploads(client, remote["id"], headers))
            except Exception as exc:
                return DiscoveryResult(links=[], errors=[f"zjuLearning: {type(exc).__name__}: {exc}"], titles={})

        links: list[str] = []
        titles: dict[str, str] = {}
        seen: set[str] = set()
        for upload in uploads:
            if not upload.title.lower().endswith(".pdf"):
                continue
            normalized = normalize_url(upload.url)
            try:
                validator.validate_url(normalized)
            except Exception as exc:
                errors.append(f"{upload.title}: {exc}")
                continue
            if normalized in seen:
                continue
            seen.add(normalized)
            links.append(normalized)
            titles[normalized] = upload.title
        return DiscoveryResult(links=links, errors=errors, titles=titles)

    async def _warm_session(self, client: httpx.AsyncClient, headers: dict[str, str]) -> None:
        response = await client.get(f"{BASE_URL}/user/courses", headers=headers, follow_redirects=True)
        if response.status_code >= 400:
            raise RuntimeError(f"warm session failed: HTTP {response.status_code}")
        if "统一身份认证" in response.text or "cas/login" in response.text:
            raise RuntimeError("ZJU Learning session expired")

    async def _remote_courses(self, client: httpx.AsyncClient, headers: dict[str, str]) -> list[dict]:
        page = 1
        pages = 1
        results: list[dict] = []
        while page <= pages:
            params = {
                "conditions": json.dumps(
                    {
                        "status": ["ongoing", "notStarted"],
                        "keyword": "",
                        "classify_type": "recently_started",
                        "display_studio_list": False,
                    },
                    ensure_ascii=False,
                ),
                "fields": "id,name,academic_year_id,semester_id",
                "page": str(page),
                "page_size": "100",
                "showScorePassedStatus": "false",
            }
            data = await self._json(client, f"{BASE_URL}/api/my-courses?{urlencode(params)}", headers)
            courses = data.get("courses")
            if not isinstance(courses, list):
                raise RuntimeError("malformed my-courses response")
            results.extend(item for item in courses if isinstance(item, dict))
            pages = int(data.get("pages") or pages)
            page += 1
        return results

    async def _activity_uploads(self, client: httpx.AsyncClient, course_id: int, headers: dict[str, str]) -> list[ZJULearningUpload]:
        data = await self._json(client, f"{BASE_URL}/api/courses/{course_id}/activities", headers)
        activities = data.get("activities")
        if not isinstance(activities, list):
            raise RuntimeError("malformed activities response")
        uploads: list[ZJULearningUpload] = []
        for activity in activities:
            for upload in activity.get("uploads", []) if isinstance(activity, dict) else []:
                parsed = self._upload(upload)
                if parsed:
                    uploads.append(parsed)
        return uploads

    async def _homework_uploads(self, client: httpx.AsyncClient, course_id: int, headers: dict[str, str]) -> list[ZJULearningUpload]:
        uploads: list[ZJULearningUpload] = []
        page = 1
        pages = 1
        while page <= pages:
            params = {
                "conditions": json.dumps({"itemsSortBy": {"predicate": "module", "reverse": False}}, ensure_ascii=False),
                "page": str(page),
                "page_size": "20",
                "reloadPage": "false",
            }
            data = await self._json(client, f"{BASE_URL}/api/courses/{course_id}/homework-activities?{urlencode(params)}", headers)
            activities = data.get("homework_activities")
            if not isinstance(activities, list):
                raise RuntimeError("malformed homework response")
            for activity in activities:
                for upload in activity.get("uploads", []) if isinstance(activity, dict) else []:
                    parsed = self._upload(upload)
                    if parsed:
                        uploads.append(parsed)
            pages = int(data.get("pages") or pages)
            page += 1
        return uploads

    async def _json(self, client: httpx.AsyncClient, url: str, headers: dict[str, str]) -> dict:
        response = await client.get(url, headers=headers, follow_redirects=True)
        if response.status_code in {401, 403} or "统一身份认证" in response.text or "cas/login" in response.text:
            raise RuntimeError("ZJU Learning session expired")
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            raise RuntimeError("JSON response must be an object")
        return data

    @staticmethod
    def _upload(upload: dict) -> ZJULearningUpload | None:
        try:
            reference_id = int(upload["reference_id"])
            name = str(upload["name"])
        except Exception:
            return None
        return ZJULearningUpload(
            title=name,
            url=f"{BASE_URL}/api/uploads/reference/{reference_id}/blob",
        )

    @staticmethod
    def _best_match(local_name: str, remote_courses: list[dict]) -> dict | None:
        local = _normalized_course_name(local_name)
        exact = [
            course
            for course in remote_courses
            if _normalized_course_name(str(course.get("name", ""))) == local
        ]
        if exact:
            return exact[0]
        for course in remote_courses:
            remote = _normalized_course_name(str(course.get("name", "")))
            if remote and (remote in local or local in remote):
                return course
        return None


def _normalized_course_name(name: str) -> str:
    return name.replace(" ", "").replace("（", "(").replace("）", ")").lower()
