## Cursor Cloud specific instructions

### Project overview

CloneAgent is a voice-driven AI coding assistant. The backend is a TypeScript/Hono API (`backend/`) that orchestrates Cursor SDK agents. The iOS/macOS Swift app is not buildable on Linux — only the backend is relevant in Cloud Agent VMs.

### Backend service

- **Location:** `backend/`
- **Runtime:** Node.js >=22 (check with `node --version`)
- **Package manager:** npm (lockfile: `package-lock.json`)
- **Framework:** Hono on `@hono/node-server`, port 8787

See `backend/README.md` for standard commands (`npm install`, `npm run dev`, `npm test`, `npm run build`).

### Non-obvious caveats

- **No dotenv**: The backend does **not** use `dotenv`. The `npm run dev` script uses bare `node --watch --import tsx`. To load `backend/.env`, start the server manually with `node --watch --env-file=.env --import tsx src/index.ts`, or export the vars in your shell before running `npm run dev`. The `CURSOR_API_KEY` env var is injected as a Cloud Agent secret.
- The dev server uses `node --watch` (not nodemon). It auto-restarts on `.ts` file changes but does **not** detect new npm packages — restart the server after `npm install`.
- `DEV_AUTH_BYPASS=1` is set in `.env.example` — bearer auth is skipped in dev mode. In production (`NODE_ENV=production`), `TASK_API_BEARER_TOKEN` is required.
- Without a valid `CURSOR_API_KEY`, task creation returns 201 but the task immediately transitions to `status: "failed"` with `errorMessage: "Server is not configured with CURSOR_API_KEY."`. Tests mock the SDK so they work without a key.
- The data store is in-memory (`Map`), so all tasks are lost on server restart.
- Type-check with `npx tsc --noEmit` (the `build` script emits to `dist/`).
- Health check: `GET /v1/tasks/<any-uuid>` returning 404 proves the server is running.
- Full task flow: `POST /v1/tasks` (Phase 1 summary) → `POST /v1/tasks/:id/confirm` (Phase 2 implement). Phase 2 can take ~50 seconds.
