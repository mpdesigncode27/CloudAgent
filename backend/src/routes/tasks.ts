import { Hono } from "hono";
import type { AppVariables } from "../types/app-variables.js";
import { authMiddleware } from "../middleware/auth.js";
import { internalPreviewGuard } from "../middleware/auth.js";
import { taskStore, toPublicTask } from "../store/tasks.js";
import { runPhase1Summary } from "../agent/runSummary.js";
import { runPhase2Implement } from "../agent/runImplement.js";
import { loadCursorServiceConfig } from "../agent/cursorConfig.js";
import { logServerError, userSafeAgentError } from "../util/errors.js";

const tasks = new Hono<{ Variables: AppVariables }>();

tasks.use("*", authMiddleware);

tasks.post("/tasks", async (c) => {
  let body: { transcript?: string };
  try {
    body = (await c.req.json()) as { transcript?: string };
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const transcript = typeof body.transcript === "string" ? body.transcript.trim() : "";
  if (!transcript) {
    return c.json({ error: "transcript is required" }, 400);
  }

  const userId = c.get("userId");
  const row = taskStore.create({ userId, rawTranscript: transcript });

  const { apiKey } = loadCursorServiceConfig();
  if (!apiKey) {
    taskStore.update(row.id, {
      status: "failed",
      errorMessage: "Server is not configured with CURSOR_API_KEY.",
    });
    const failed = taskStore.get(row.id)!;
    return c.json(toPublicTask(failed), 201);
  }

  try {
    const summary = await runPhase1Summary(transcript);
    const updated = taskStore.update(row.id, {
      status: "summary_ready",
      summaryMarkdown: summary.markdown,
      remoteAgentId: summary.agentId,
      remoteRunIdPhase1: summary.runId,
      errorMessage: null,
    });
    console.log(
      JSON.stringify({
        level: "info",
        scope: "phase1",
        taskId: row.id,
        agentId: summary.agentId,
        runId: summary.runId,
      }),
    );
    return c.json(toPublicTask(updated!), 201);
  } catch (err) {
    logServerError("phase1", err);
    const msg = userSafeAgentError(err);
    const updated = taskStore.update(row.id, {
      status: "failed",
      errorMessage: msg,
    });
    return c.json(toPublicTask(updated!), 201);
  }
});

tasks.get("/tasks/:taskId", (c) => {
  const id = c.req.param("taskId");
  const row = taskStore.get(id);
  if (!row) return c.json({ error: "Not found" }, 404);
  return c.json(toPublicTask(row));
});

tasks.post("/tasks/:taskId/confirm", async (c) => {
  const id = c.req.param("taskId");
  const row = taskStore.get(id);
  if (!row) return c.json({ error: "Not found" }, 404);
  if (row.status !== "summary_ready" && row.status !== "awaiting_confirmation") {
    return c.json({ error: "Task is not in a confirmable state" }, 409);
  }
  if (!row.remoteAgentId || !row.summaryMarkdown) {
    return c.json({ error: "Task is not in a confirmable state" }, 409);
  }

  const { apiKey } = loadCursorServiceConfig();
  if (!apiKey) {
    taskStore.update(id, { status: "failed", errorMessage: "Server is not configured with CURSOR_API_KEY." });
    return c.json(toPublicTask(taskStore.get(id)!), 409);
  }

  taskStore.update(id, { status: "executing", errorMessage: null });
  try {
    const impl = await runPhase2Implement(row.remoteAgentId, row.summaryMarkdown);
    const updated = taskStore.update(id, {
      status: "completed",
      remoteRunIdPhase2: impl.runId,
      errorMessage: null,
    });
    console.log(
      JSON.stringify({
        level: "info",
        scope: "phase2",
        taskId: id,
        agentId: impl.agentId,
        runId: impl.runId,
      }),
    );
    return c.json(toPublicTask(updated!), 200);
  } catch (err) {
    logServerError("phase2", err);
    const msg = userSafeAgentError(err);
    const updated = taskStore.update(id, {
      status: "failed",
      errorMessage: msg,
    });
    return c.json(toPublicTask(updated!), 200);
  }
});

const internal = new Hono();
internal.use("*", internalPreviewGuard);

internal.post("/tasks/:taskId/preview", async (c) => {
  const id = c.req.param("taskId");
  const row = taskStore.get(id);
  if (!row) return c.json({ error: "Not found" }, 404);
  let body: { previewUrl?: string };
  try {
    body = (await c.req.json()) as { previewUrl?: string };
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const previewUrl = typeof body.previewUrl === "string" ? body.previewUrl.trim() : "";
  if (!previewUrl) {
    return c.json({ error: "previewUrl is required" }, 400);
  }
  try {
    const u = new URL(previewUrl);
    if (u.protocol !== "http:" && u.protocol !== "https:") {
      return c.json({ error: "previewUrl must be http(s)" }, 400);
    }
  } catch {
    return c.json({ error: "previewUrl must be a valid URL" }, 400);
  }
  const updated = taskStore.setPreviewUrl(id, previewUrl);
  return c.json(toPublicTask(updated!), 200);
});

export const tasksRoutes = tasks;
export const internalRoutes = internal;
