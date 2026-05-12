import { Agent, CursorAgentError } from "@cursor/sdk";
import { getPhase2AgentResumeOptions, loadCursorServiceConfig } from "./cursorConfig.js";

const IMPLEMENT_SYSTEM = `You are an implementation agent. The user already confirmed the summarized plan.
Execute the work in the repository: make focused changes, run tests if appropriate, and finish with a short markdown recap of what you did.
If you cannot complete, explain blockers clearly.`;

export class Phase2StartupError extends Error {
  readonly causeError: unknown;
  constructor(message: string, causeError: unknown) {
    super(message);
    this.name = "Phase2StartupError";
    this.causeError = causeError;
  }
}

export class Phase2RunError extends Error {
  readonly runId: string;
  constructor(message: string, runId: string) {
    super(message);
    this.name = "Phase2RunError";
    this.runId = runId;
  }
}

export interface Phase2ImplementResult {
  agentId: string;
  runId: string;
  recapMarkdown: string;
}

export async function runPhase2Implement(remoteAgentId: string, summaryMarkdown: string): Promise<Phase2ImplementResult> {
  const config = loadCursorServiceConfig();
  const resumeOptions = getPhase2AgentResumeOptions(config);

  let agent: Awaited<ReturnType<typeof Agent.resume>>;
  try {
    agent = await Agent.resume(remoteAgentId, resumeOptions);
  } catch (err) {
    if (err instanceof CursorAgentError) {
      throw new Phase2StartupError("Agent could not resume for implementation", err);
    }
    throw err;
  }

  const prompt = `${IMPLEMENT_SYSTEM}\n\nApproved summary:\n\n${summaryMarkdown}`;
  try {
    const run = await agent.send(prompt);
    const result = await run.wait();
    if (result.status === "error" || result.status === "cancelled") {
      throw new Phase2RunError(`Implement run finished with status ${result.status}`, run.id);
    }
    const recap = (result.result ?? "").trim() || "_Run completed with no text result._";
    return {
      agentId: agent.agentId,
      runId: run.id,
      recapMarkdown: recap,
    };
  } finally {
    await agent[Symbol.asyncDispose]();
  }
}
