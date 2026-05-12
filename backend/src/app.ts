import { Hono } from "hono";
import { internalRoutes, tasksRoutes } from "./routes/tasks.js";
import type { AppVariables } from "./types/app-variables.js";

export function createApp(): Hono<{ Variables: AppVariables }> {
  const app = new Hono<{ Variables: AppVariables }>();

  app.onError((err, c) => {
    logRequestError(c.req.path, err);
    return c.json({ error: "Internal server error" }, 500);
  });

  app.use("*", async (c, next) => {
    const started = Date.now();
    await next();
    const ms = Date.now() - started;
    console.log(
      JSON.stringify({
        level: "info",
        scope: "http",
        method: c.req.method,
        path: c.req.path,
        status: c.res.status,
        ms,
      }),
    );
  });

  app.route("/v1", tasksRoutes);
  app.route("/v1/internal", internalRoutes);

  return app;
}

function logRequestError(path: string, err: unknown): void {
  const message = err instanceof Error ? err.message : String(err);
  console.error(JSON.stringify({ level: "error", scope: "http.onError", path, message }));
}
