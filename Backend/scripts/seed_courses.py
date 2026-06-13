from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.config import get_settings
from app.courses.repository import CourseRepository
from app.courses.schemas import CourseCreate
from app.db import Database


def main() -> None:
    data_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data" / "seed_courses.example.json"
    settings = get_settings()
    database = Database(settings.database_path)
    courses = json.loads(data_path.read_text(encoding="utf-8"))
    with database.session() as conn:
        repo = CourseRepository(conn)
        for item in courses:
            course = repo.upsert_course(CourseCreate(**item))
            print(f"seeded {course.id}: {course.name}")


if __name__ == "__main__":
    main()
