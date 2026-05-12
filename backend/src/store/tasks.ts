import { randomUUID } from "node:crypto";

export type TaskStatus =
  | "awaiting_summary"
  | "summary_ready"
  | "awaiting_confirmation"
  | "executing"
  | "completed"
  | "failed";

export interface TaskRow {
  id: string;
  userId: string;
  rawTranscript: string;
  status: TaskStatus;
  summaryMarkdown: string | null;
  remoteAgentId: string | null;
  remoteRunIdPhase1: string | null;
  remoteRunIdPhase2: string | null;
  previewUrl: string | null;
  errorMessage: string | null;
  createdAt: string;
  updatedAt: string;
}

const terminal: TaskStatus[] = ["completed", "failed"];

function nowIso(): string {
  return new Date().toISOString();
}

function assertTransition(from: TaskStatus, to: TaskStatus): void {
  if (from === to) return;
  if (terminal.includes(from) && to !== from) {
    throw new Error(`Illegal transition from terminal state ${from} to ${to}`);
  }
  const allowed: Record<TaskStatus, TaskStatus[]> = {
    awaiting_summary: ["summary_ready", "failed"],
    summary_ready: ["awaiting_confirmation", "executing", "failed"],
    awaiting_confirmation: ["executing", "failed"],
    executing: ["completed", "failed"],
    completed: [],
    failed: [],
  };
  if (!allowed[from].includes(to)) {
    throw new Error(`Illegal transition ${from} -> ${to}`);
  }
}

export function toPublicTask(row: TaskRow): Record<string, unknown> {
  return {
    id: row.id,
    status: row.status,
    summaryMarkdown: row.summaryMarkdown,
    previewUrl: row.previewUrl,
    errorMessage: row.errorMessage,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    remoteAgentId: row.remoteAgentId,
    remoteRunIdPhase1: row.remoteRunIdPhase1,
    remoteRunIdPhase2: row.remoteRunIdPhase2,
  };
}

class TaskStore {
  private readonly tasks = new Map<string, TaskRow>();

  create(input: { userId: string; rawTranscript: string }): TaskRow {
    const id = randomUUID();
    const ts = nowIso();
    const row: TaskRow = {
      id,
      userId: input.userId,
      rawTranscript: input.rawTranscript,
      status: "awaiting_summary",
      summaryMarkdown: null,
      remoteAgentId: null,
      remoteRunIdPhase1: null,
      remoteRunIdPhase2: null,
      previewUrl: null,
      errorMessage: null,
      createdAt: ts,
      updatedAt: ts,
    };
    this.tasks.set(id, row);
    return row;
  }

  get(id: string): TaskRow | undefined {
    return this.tasks.get(id);
  }

  update(id: string, patch: Partial<Omit<TaskRow, "id" | "createdAt">> & { status?: TaskStatus }): TaskRow | undefined {
    const row = this.tasks.get(id);
    if (!row) return undefined;
    if (patch.status !== undefined && patch.status !== row.status) {
      assertTransition(row.status, patch.status);
    }
    const next: TaskRow = {
      ...row,
      ...patch,
      updatedAt: nowIso(),
    };
    this.tasks.set(id, next);
    return next;
  }

  setPreviewUrl(id: string, previewUrl: string): TaskRow | undefined {
    const row = this.tasks.get(id);
    if (!row) return undefined;
    const next: TaskRow = {
      ...row,
      previewUrl,
      updatedAt: nowIso(),
    };
    this.tasks.set(id, next);
    return next;
  }

  /** @internal Vitest */
  clearAll(): void {
    this.tasks.clear();
  }
}

export const taskStore = new TaskStore();
