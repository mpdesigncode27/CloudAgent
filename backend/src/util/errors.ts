import { CursorAgentError } from "@cursor/sdk";
import { Phase1RunError, Phase1StartupError } from "../agent/runSummary.js";
import { Phase2RunError, Phase2StartupError } from "../agent/runImplement.js";

export function userSafeAgentError(err: unknown): string {
  if (err instanceof Phase1StartupError || err instanceof Phase2StartupError) {
    return "The automation service could not start. Try again later.";
  }
  if (err instanceof Phase1RunError || err instanceof Phase2RunError) {
    return "The agent run did not complete successfully.";
  }
  if (err instanceof CursorAgentError) {
    return "The automation service reported an error. Try again later.";
  }
  return "Something went wrong. Try again later.";
}

export function logServerError(scope: string, err: unknown): void {
  const base: Record<string, unknown> = {
    level: "error",
    scope,
    message: err instanceof Error ? err.message : String(err),
    name: err instanceof Error ? err.name : "unknown",
  };
  if (err instanceof CursorAgentError) {
    base.retryable = err.isRetryable;
  }
  console.error(JSON.stringify(base));
}
