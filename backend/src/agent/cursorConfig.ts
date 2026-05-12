import { fileURLToPath } from "node:url";
import path from "node:path";
import type { AgentOptions, CloudAgentOptions, ModelSelection } from "@cursor/sdk";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Repo root (parent of `backend/`) for default local agent cwd. */
export const repoRoot = path.resolve(__dirname, "..", "..");

export type CloudRepoEntry = NonNullable<CloudAgentOptions["repos"]>[number];

export interface CursorServiceConfig {
  apiKey: string | undefined;
  model: ModelSelection;
  cloudRepos: CloudRepoEntry[];
}

function parseCloudReposFromEnv(): CloudRepoEntry[] {
  const raw = process.env.CLOUD_REPOS_JSON?.trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (!Array.isArray(parsed)) return [];
      return parsed
        .filter((r): r is { url: string } => typeof r === "object" && r !== null && "url" in r && typeof (r as { url: unknown }).url === "string")
        .map((r) => {
          const entry: CloudRepoEntry = { url: r.url };
          const ref = (r as Record<string, unknown>)["startingRef"];
          if (typeof ref === "string") entry.startingRef = ref;
          return entry;
        });
    } catch {
      return [];
    }
  }
  const single = process.env.CLOUD_REPO_URL?.trim();
  if (single) return [{ url: single }];
  return [];
}

export function loadCursorServiceConfig(): CursorServiceConfig {
  const apiKey = process.env.CURSOR_API_KEY?.trim() || undefined;
  const modelId = process.env.CURSOR_MODEL_ID?.trim() || "composer-2";
  return {
    apiKey,
    model: { id: modelId },
    cloudRepos: parseCloudReposFromEnv(),
  };
}

/** Fail fast when production would run agents without a key. */
export function assertProductionCursorKey(): void {
  if (process.env.NODE_ENV !== "production") return;
  const { apiKey } = loadCursorServiceConfig();
  if (!apiKey) {
    throw new Error("CURSOR_API_KEY is required when NODE_ENV=production");
  }
}

export function getPhase1AgentOptions(config: CursorServiceConfig): AgentOptions {
  if (!config.apiKey) {
    throw new Error("CURSOR_API_KEY is not set");
  }
  return {
    apiKey: config.apiKey,
    model: config.model,
    local: { cwd: repoRoot },
  };
}

export function getPhase2AgentResumeOptions(config: CursorServiceConfig): Partial<AgentOptions> {
  if (!config.apiKey) {
    throw new Error("CURSOR_API_KEY is not set");
  }
  const base: Partial<AgentOptions> = {
    apiKey: config.apiKey,
    model: config.model,
  };
  if (config.cloudRepos.length > 0) {
    return {
      ...base,
      cloud: { repos: config.cloudRepos },
    };
  }
  return {
    ...base,
    local: { cwd: repoRoot },
  };
}
