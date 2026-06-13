# PathMate Backend

FastAPI MVP for dynamic course-material mind maps.

## What This Implements

- Course CRUD for configured public course resource pages.
- Static HTML resource discovery for PDF links only, without recursive crawling.
- Authenticated ZJU Learning material sync using the same API flow as the current iOS app.
- Optional Playwright browser rendering for JavaScript-loaded resource pages.
- Optional OCR fallback for scanned PDFs.
- Domain allow-list and SSRF checks for source pages, redirects, and PDF downloads.
- Temporary server-side PDF fetch, SHA-256 versioning, text extraction with `pypdf`, and SQLite chunk indexing.
- vLLM/OpenAI-compatible JSON generation using `prompt.md` as the system prompt.
- Mind map validation, repair-once flow, cache reuse, and per-node expansion locks.

## Setup

```powershell
cd Backend
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `Backend/.env`:

```text
VLLM_BASE_URL=http://221.12.22.187:30964/v1
VLLM_API_KEY=<your key>
VLLM_MODEL=
BACKEND_DB_PATH=Backend/data/pathmate.db
ENABLE_OCR=true
OCR_LANGUAGE=chi_sim+eng
OCR_MAX_PAGES=6
ZJU_LEARNING_COOKIE=
```

Do not put the model API key in iOS code.

## Run

```powershell
cd Backend
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Health check:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

## Database

The backend uses SQLite by default. The file path is configured by `BACKEND_DB_PATH`.
Tables are created automatically on app startup.

## Seed Courses

Copy `Backend/data/seed_courses.example.json` to your own JSON file and adjust course names to match the names imported from the timetable. The default sample targets ZJU Learning (`courses.zju.edu.cn`) and requires a logged-in cookie header.

```powershell
cd Backend
python .\scripts\seed_courses.py .\data\seed_courses.example.json
```

You can also create/update one course directly:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/courses `
  -ContentType "application/json" `
  -Body '{
    "id":"data-structure",
    "name":"数据结构",
    "semester":"2026-spring",
    "sourcePages":["https://courses.zju.edu.cn/user/courses"],
    "allowedDomains":["courses.zju.edu.cn"],
    "accessType":"authenticated"
}'
```

If iOS has already imported the timetable, configure those course names for ZJU Learning in one request:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/courses/imported/zju-learning `
  -ContentType "application/json" `
  -Body '{"courses":[{"id":"data-structure","name":"数据结构","semester":"2026-spring"}]}'
```

## Main Flow

Sync remote course PDFs:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/courses/data-structure/sync-materials `
  -ContentType "application/json" `
  -Body '{"adapter":"zjuLearning","auth":{"cookieHeader":"<WKWebView Cookie header>"}}'
```

For public static resource pages, use `{"adapter":"staticHtml"}`. For JavaScript-loaded pages, use `{"adapter":"browser"}` after installing Playwright browsers:

```powershell
python -m playwright install chromium
```

List discovered documents:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/courses/data-structure/documents
```

Generate or read cached top-level mind map:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/courses/data-structure/mind-map
```

Force regenerate top-level map:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/courses/data-structure/mind-map/regenerate
```

Expand one node:

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/courses/data-structure/mind-map/expand `
  -ContentType "application/json" `
  -Body '{"nodeId":"node-tree","requestedDepth":1}'
```

Node detail and sources:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/courses/data-structure/mind-map/nodes/node-tree
Invoke-RestMethod http://127.0.0.1:8000/courses/data-structure/mind-map/nodes/node-tree/sources
```

## iOS Integration

Use `courseId` from the course card and call:

- `GET /courses/{courseId}/mind-map`
- `POST /courses/{courseId}/mind-map/expand`

The backend returns `courseId`, `title`, `rootNodeId`, `nodes`, and `edges`. It does not return layout coordinates; SwiftUI keeps layout responsibility.

For logged-in ZJU Learning sync, reuse the existing `WKWebsiteDataStore.default().httpCookieStore.getAllCookies` flow from `ZJULearningMaterialService`, build a standard `Cookie` header, and pass it as `auth.cookieHeader` to `POST /courses/{courseId}/sync-materials`. The backend does not need or store the user's password.

## Replacing the Index Provider

The MVP uses `LocalKeywordIndexProvider` in `app/indexing/provider.py`.
To replace it with OpenAI Vector Store, Pinecone, Supabase Vector, or another provider, implement the same `DocumentIndexProvider` methods and swap the provider construction in `app/routes.py`.

## Future Authenticated Course Websites

Authenticated sites are supported through source adapters and caller-provided session headers. Add new adapters beside `ZJULearningSourceAdapter` for other schools. Store long-lived tokens in server-side secret storage, not in the app, prompt, database rows, or logs.

## Current Limits

- Browser automation requires a local Chromium install through Playwright.
- No login or captcha bypass; users must authenticate normally in the web view.
- OCR requires Tesseract language data such as `chi_sim` and `eng` installed on the server.
- Local keyword search is an MVP placeholder, not semantic retrieval.
- LLM calls require `VLLM_API_KEY`; if it is missing, mind-map generation returns HTTP 503.
