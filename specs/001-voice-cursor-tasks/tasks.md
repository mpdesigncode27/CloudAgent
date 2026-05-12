---
description: "Task list for voice-driven remote agent tasks (001-voice-cursor-tasks)"
---

# Tasks: Voice-driven remote agent tasks

**Input**: Design documents from `specs/001-voice-cursor-tasks/` — backend **locked** to **TypeScript + `@cursor/sdk`** per [plan.md](./plan.md).

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/task-api.openapi.yaml](./contracts/task-api.openapi.yaml), [quickstart.md](./quickstart.md)

**Tests**: [Constitution II](../../.specify/memory/constitution.md) requires automated tests for HTTP contracts: **Vitest** tasks below are mandatory for backend routes; XCTest for Swift remains in polish / US phases as applicable.

**Organization**: Phases follow user stories P1 → P2 → P3 after shared setup and foundation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependency on incomplete tasks in the same wave)
- **[Story]**: `US1`, `US2`, `US3` for user-story phases only
- **Paths**: Repository root = directory containing `CloneAgent.xcodeproj`, folders `CloneAgent/` (iOS) and `backend/` (TypeScript).

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: TypeScript backend scaffold with **`@cursor/sdk`**; iOS folders for intents and API client. The iOS target uses a **synchronized file system group** — new files under `CloneAgent/` are picked up automatically (no manual `project.pbxproj` file lists for Swift sources).

- [x] T001 Create TypeScript backend scaffold: `backend/package.json` (`"type":"module"`, `engines.node >=22`, scripts `dev`/`build`/`test`), `backend/tsconfig.json` (strict, `moduleResolution: "nodenext"`), `backend/src/index.ts` bootstrapping **Hono** (recommended per [research.md](./research.md) R6) or Fastify — pick one and document in `backend/README.md` in T027
- [x] T002 [P] Add `backend/.env.example` with `CURSOR_API_KEY`, `PORT`, optional `CLOUD_REPO_URL` / repo list for phase 2 (no secrets committed)
- [x] T003 [P] Add dependency `@cursor/sdk` and generate `backend/package-lock.json` via `npm install` in `backend/`
- [x] T004 [P] Add `backend/vitest.config.ts`, `npm test` script, and stub `backend/tests/setup.ts` if needed
- [x] T005 [P] Implement `backend/src/agent/cursorConfig.ts` exporting typed config (`apiKey`, `model`, optional `cloudRepos`) read from `process.env`; fail fast in production when `CURSOR_API_KEY` missing

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Task store, HTTP handlers, Vitest coverage for contract shapes — **blocks all user stories**.

**Checkpoint**: `POST /v1/tasks` and `GET /v1/tasks/{id}` return JSON matching OpenAPI; `npm test` passes smoke tests.

- [x] T006 Implement task entity and in-memory store with status machine in `backend/src/store/tasks.ts` (fields per [data-model.md](./data-model.md))
- [x] T007 Implement HTTP app bootstrap and route mount in `backend/src/index.ts` delegating to `backend/src/routes/tasks.ts`
- [x] T008 Implement stub `POST /v1/tasks` and `GET /v1/tasks/:taskId` in `backend/src/routes/tasks.ts` per [contracts/task-api.openapi.yaml](./contracts/task-api.openapi.yaml) (no real SDK call yet; valid status transitions)
- [x] T009 [P] Add `backend/src/middleware/auth.ts` with dev bypass and production Bearer check (never log raw tokens)
- [x] T010 [P] Add Vitest route tests for request/response shapes in `backend/tests/tasks.route.test.ts` (assert status codes and JSON keys for create + get)
- [x] T011 [P] Define `Task` / `TaskStatus` enums matching OpenAPI in `CloneAgent/Services/TaskModels.swift`
- [x] T012 Implement `TaskAPIClient` (`createTask`, `getTask`) with URLSession in `CloneAgent/Services/TaskAPIClient.swift` plus `CloneAgent/Services/AppConfiguration.swift` for base URL (Info.plist or `xcconfig`)

**Checkpoint**: Foundation ready — user story work can begin.

---

## Phase 3: User Story 1 — Sprachauftrag mit Zusammenfassung (Priority: P1) MVP

**Goal**: Siri / App Intent → TypeScript `POST /v1/tasks` → **`runSummary.ts`** (`Agent.create` → `send` → `wait` → dispose) → persisted markdown → iOS UI.

**Independent Test**: Intent or client posts transcript; user sees summary without confirm.

- [x] T013 [US1] Implement phase-1 Cursor runner in `backend/src/agent/runSummary.ts`: summary-only system prompt, `Agent.create`, `send`, `await run.wait()`, dispose; map `CursorAgentError` vs `result.status === "error"` to typed errors for routes
- [x] T014 [US1] Wire `POST /v1/tasks` async flow in `backend/src/routes/tasks.ts`: call `runSummary`, persist `summaryMarkdown`, transition to `summary_ready`, log `agentId`/`runId`
- [x] T015 [P] [US1] Implement `SubmitVoiceTaskIntent` accepting `String` in `CloneAgent/AppIntents/SubmitVoiceTaskIntent.swift`
- [x] T016 [US1] Connect `TaskSummaryView` to `TaskAPIClient` for live data (loading / error / markdown) in `CloneAgent/TaskSummaryView.swift` (replace demo-only state where applicable)
- [x] T017 [US1] Route intent / deep link into navigation after `createTask` from `CloneAgent/ContentView.swift` (or dedicated coordinator file under `CloneAgent/`)

**Checkpoint**: User Story 1 end-to-end against running backend.

---

## Phase 4: User Story 2 — Bestätigung und Hintergrundausführung (Priority: P2)

**Goal**: `POST /v1/tasks/:id/confirm` → **`runImplement.ts`** (cloud `repos` config, `Agent.resume` or second `send`) → persisted run ids + status; iOS confirm + polling + optional notification.

**Independent Test**: Confirm transitions to `executing` then terminal state; survives app relaunch via `GET`.

- [x] T018 [US2] Implement `POST /v1/tasks/:taskId/confirm` in `backend/src/routes/tasks.ts` with valid state gating (`summary_ready` / `awaiting_confirmation` → `executing`)
- [x] T019 [US2] Implement `backend/src/agent/runImplement.ts` with explicit `cloud: { repos: [...] }` when configured; same dispose + error mapping rules as phase 1
- [x] T020 [US2] Extend `backend/src/store/tasks.ts` and GET JSON for `remoteAgentId`, `remoteRunIdPhase1`, `remoteRunIdPhase2`
- [x] T021 [P] [US2] Add `confirmTask(taskId:)` to `CloneAgent/Services/TaskAPIClient.swift`
- [x] T022 [P] [US2] Add confirm UI + status polling (timer or pull-to-refresh) in `CloneAgent/TaskSummaryView.swift`
- [x] T023 [US2] Add `CloneAgent/TaskNotifications.swift` and request authorization; post local notification on terminal status from `TaskSummaryView.swift`

**Checkpoint**: User Stories 1 and 2 independently demonstrable.

---

## Phase 5: User Story 3 — Ergebnis (Preview-URL / Web) (Priority: P3)

**Goal**: `previewUrl` on task; secured setter for CI; in-app Safari / WebKit.

**Independent Test**: Completed task with `previewUrl` opens in viewer.

- [x] T024 [US3] Extend `backend/src/store/tasks.ts` and GET responses for nullable `previewUrl`
- [x] T025 [P] [US3] Add secured `PATCH /v1/tasks/:taskId` (or `POST /v1/internal/tasks/:taskId/preview`) in `backend/src/routes/tasks.ts`; document CI auth in `backend/README.md`
- [x] T026 [US3] Add `CloneAgent/PreviewWebView.swift` and integrate link/button in `CloneAgent/TaskSummaryView.swift`
- [x] T027 [US3] Map SDK/route failures to user-safe `errorMessage` in `backend/src/routes/tasks.ts` (no stack traces in API JSON per FR-008)

**Checkpoint**: All three user stories covered.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T028 [P] Complete `backend/README.md` (env, `npm run dev`, Cursor SDK notes, security)
- [x] T029 [P] Redact `Authorization` / secrets in structured logs in `backend/src/index.ts`
- [x] T030 [P] Add XCTest or UI test stub for `TaskAPIClient` decode in `CloneAgentTests/TaskModelsTests.swift` (create test target if missing) and run through [quickstart.md](./quickstart.md); update [checklists/requirements.md](./checklists/requirements.md) if gaps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1** → **Phase 2** → **Phases 3–5 (US1 → US2 → US3)** → **Phase 6**
- **US2** depends on **US1** (confirm requires summary).
- **US3** depends on **US2** (preview attaches to completed work).

### User Story Dependencies

- **US1**: After Phase 2.
- **US2**: After US1.
- **US3**: After US2.

### Parallel Opportunities

- **T002–T005** parallel after T001 started.
- **T009–T012** parallel once `tasks.ts` shapes stable.
- **T015** parallel with **T013–T014** (Swift intent vs backend agent).
- **T021–T022** parallel once confirm API exists.

### Parallel Example: User Story 1

```bash
# Backend Cursor SDK module while iOS intent is authored:
Task: "Implement runSummary.ts in backend/src/agent/runSummary.ts"
Task: "Implement SubmitVoiceTaskIntent in CloneAgent/AppIntents/SubmitVoiceTaskIntent.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Complete Phases 1–2.
2. Complete Phase 3 (US1).
3. **Stop and validate** against spec SC-001 / SC-002 (manual + `npm test`).

### Incremental Delivery

1. Ship US1 (summary-only).
2. Add US2 (confirm + cloud agent).
3. Add US3 (preview URL + web surface).

### Suggested MVP Scope

- **Tasks T001–T017** align with [plan.md](./plan.md) MVP row (TypeScript + Cursor SDK phase 1 + iOS client).

---

## Notes

- Total tasks: **30** (T001–T030).
- Counts: Setup 5, Foundational 7, US1 5, US2 6, US3 4, Polish 3.
- Re-run `setup-tasks.sh --json` if `.specify/feature.json` changes.
