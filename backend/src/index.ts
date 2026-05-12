import { serve } from "@hono/node-server";
import { assertProductionCursorKey, loadCursorServiceConfig } from "./agent/cursorConfig.js";
import { createApp } from "./app.js";

function assertProductionTaskBearer(): void {
  if (process.env.NODE_ENV !== "production") return;
  const token = process.env.TASK_API_BEARER_TOKEN?.trim();
  if (!token) {
    throw new Error("TASK_API_BEARER_TOKEN is required when NODE_ENV=production");
  }
}

assertProductionCursorKey();
assertProductionTaskBearer();

const app = createApp();
const port = Number.parseInt(process.env.PORT ?? "8787", 10);

serve(
  {
    fetch: app.fetch,
    port,
  },
  (info) => {
    const { apiKey } = loadCursorServiceConfig();
    console.log(
      JSON.stringify({
        level: "info",
        scope: "bootstrap",
        message: "Task API listening",
        port: info.port,
        address: info.address,
        cursorKeyConfigured: Boolean(apiKey),
      }),
    );
  },
);
