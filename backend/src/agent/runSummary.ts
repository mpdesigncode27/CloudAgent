import { Agent, CursorAgentError } from "@cursor/sdk";
import { getPhase1AgentOptions, loadCursorServiceConfig } from "./cursorConfig.js";

const SUMMARY_SYSTEM = `You are a planning assistant. The user spoke a short task request (possibly German).
Produce a concise markdown summary with sections: **Verstanden**, **Annahmen**, **Geplant**.
Do not claim to have edited files or run tools. No code blocks longer than 8 lines. Stay under 400 words.`;

export class Phase1StartupError extends Error {
  readonly causeError: unknown;
  constructor(message: string, causeError: unknown) {
    super(message);
    this.name = "Phase1StartupError";
    this.causeError = causeError;
  }
}

export class Phase1RunError extends Error {
  readonly runId: string;
  constructor(message: string, runId: string) {
    super(message);
    this.name = "Phase1RunError";
    this.runId = runId;
  }
}

export interface Phase1SummaryResult {
  markdown: string;
  agentId: string;
  runId: string;
}

export async function runPhase1Summary(rawTranscript: string): Promise<Phase1SummaryResult> {
  const config = loadCursorServiceConfig();
  const options = getPhase1AgentOptions(config);
  const userBlock = `User request (transcript):\n\n${rawTranscript}`;
  const prompt = `${SUMMARY_SYSTEM}\n\n${userBlock}`;

  let agent: Awaited<ReturnType<typeof Agent.create>>;
  try {
    agent = await Agent.create(options);
  } catch (err) {
    if (err instanceof CursorAgentError) {
      throw new Phase1StartupError("Agent could not start for summary", err);
    }
    throw err;
  }

  try {
    const run = await agent.send(prompt);
    const result = await run.wait();
    if (result.status === "error" || result.status === "cancelled") {
      throw new Phase1RunError(`Summary run finished with status ${result.status}`, run.id);
    }
    const markdown = (result.result ?? "").trim() || "_No summary text returned._";
    return {
      markdown,
      agentId: agent.agentId,
      runId: run.id,
    };
  } finally {
    await agent[Symbol.asyncDispose]();
  }
}
