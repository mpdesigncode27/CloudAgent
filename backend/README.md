# CloneAgent task API (TypeScript)

Node **22+** service that owns **`CURSOR_API_KEY`** and **`@cursor/sdk`** — the iOS app is a thin HTTPS client only.

## Run locally

```bash
cd backend
cp .env.example .env
# edit .env: set CURSOR_API_KEY, optional TASK_API_BEARER_TOKEN / CLOUD_REPO_URL / INTERNAL_PREVIEW_SECRET
npm install
npm run dev
```

Default port **8787** (`PORT`). Health via any `GET /v1/tasks/{uuid}` (404 proves server is up).

## Security

- **Never** commit `.env` or real keys. Production requires `CURSOR_API_KEY` and `TASK_API_BEARER_TOKEN`.
- Client auth: `Authorization: Bearer <TASK_API_BEARER_TOKEN>`. In dev, `DEV_AUTH_BYPASS=1` skips Bearer (or omit `TASK_API_BEARER_TOKEN` in non-production).
- Internal preview updates: `POST /v1/internal/tasks/:taskId/preview` with JSON `{ "previewUrl": "https://..." }` and header **`X-Clone-Agent-Internal: <INTERNAL_PREVIEW_SECRET>`** (set in CI).
- Logs avoid printing raw `Authorization` headers; use structured JSON logs only.

## Cursor SDK

- Phase 1 summary: `src/agent/runSummary.ts` — `Agent.create` → `send` → `wait` → dispose; local `cwd` is the **repository root** (parent of `backend/`).
- Phase 2 implement: `src/agent/runImplement.ts` — `Agent.resume` with explicit **`cloud: { repos: [...] }`** when `CLOUD_REPO_URL` / `CLOUD_REPOS_JSON` is set; otherwise local against the same repo root.

## Tests

```bash
npm test
```

Vitest mocks SDK calls in `tests/tasks.route.test.ts` so CI does not need a live Cursor key.
