import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createApp } from "../src/app.js";
import { taskStore } from "../src/store/tasks.js";

vi.mock("../src/agent/runSummary.js", () => ({
  runPhase1Summary: vi.fn().mockResolvedValue({
    markdown: "## Summary\n\nOK",
    agentId: "agent-test-1",
    runId: "run-test-1",
  }),
}));

vi.mock("../src/agent/runImplement.js", () => ({
  runPhase2Implement: vi.fn().mockResolvedValue({
    agentId: "agent-test-1",
    runId: "run-test-2",
    recapMarkdown: "Done",
  }),
}));

import { runPhase1Summary } from "../src/agent/runSummary.js";
import { runPhase2Implement } from "../src/agent/runImplement.js";

describe("Task API routes", () => {
  beforeEach(() => {
    taskStore.clearAll();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("POST /v1/tasks returns 201 with Task shape", async () => {
    const app = createApp();
    const res = await app.request("/v1/tasks", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ transcript: "Hello from test" }),
    });
    expect(res.status).toBe(201);
    const json = (await res.json()) as Record<string, unknown>;
    expect(typeof json.id).toBe("string");
    expect(json.status).toBe("summary_ready");
    expect(json.summaryMarkdown).toBeTruthy();
    expect(json.createdAt).toBeTruthy();
    expect(json.updatedAt).toBeTruthy();
    expect(runPhase1Summary).toHaveBeenCalledOnce();
  });

  it("POST /v1/tasks rejects empty transcript", async () => {
    const app = createApp();
    const res = await app.request("/v1/tasks", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ transcript: "   " }),
    });
    expect(res.status).toBe(400);
  });

  it("GET /v1/tasks/:id returns 404 for unknown id", async () => {
    const app = createApp();
    const res = await app.request("/v1/tasks/00000000-0000-4000-8000-000000000000");
    expect(res.status).toBe(404);
  });

  it("GET /v1/tasks/:id returns persisted task", async () => {
    const app = createApp();
    const created = await app.request("/v1/tasks", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ transcript: "Ping" }),
    });
    const body = (await created.json()) as { id: string };
    const res = await app.request(`/v1/tasks/${body.id}`);
    expect(res.status).toBe(200);
    const json = (await res.json()) as Record<string, unknown>;
    expect(json.id).toBe(body.id);
    expect(json.remoteAgentId).toBe("agent-test-1");
    expect(json.remoteRunIdPhase1).toBe("run-test-1");
  });

  it("POST /v1/tasks/:id/confirm succeeds after summary_ready", async () => {
    const app = createApp();
    const created = await app.request("/v1/tasks", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ transcript: "Build feature X" }),
    });
    const { id } = (await created.json()) as { id: string };
    const res = await app.request(`/v1/tasks/${id}/confirm`, { method: "POST" });
    expect(res.status).toBe(200);
    const json = (await res.json()) as Record<string, unknown>;
    expect(json.status).toBe("completed");
    expect(json.remoteRunIdPhase2).toBe("run-test-2");
    expect(runPhase2Implement).toHaveBeenCalledOnce();
  });

  it("POST /v1/internal/tasks/:id/preview sets previewUrl", async () => {
    const prev = process.env.INTERNAL_PREVIEW_SECRET;
    process.env.INTERNAL_PREVIEW_SECRET = "secret-preview";
    try {
      const app = createApp();
      const created = await app.request("/v1/tasks", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ transcript: "x" }),
      });
      const { id } = (await created.json()) as { id: string };
      const res = await app.request(`/v1/internal/tasks/${id}/preview`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-clone-agent-internal": "secret-preview",
        },
        body: JSON.stringify({ previewUrl: "https://example.com/p" }),
      });
      expect(res.status).toBe(200);
      const json = (await res.json()) as { previewUrl: string | null };
      expect(json.previewUrl).toBe("https://example.com/p");
    } finally {
      process.env.INTERNAL_PREVIEW_SECRET = prev;
    }
  });

  it("POST /v1/tasks/:id/confirm returns 404 for unknown task", async () => {
    const app = createApp();
    const res = await app.request("/v1/tasks/00000000-0000-4000-8000-000000000099/confirm", {
      method: "POST",
    });
    expect(res.status).toBe(404);
  });
});
