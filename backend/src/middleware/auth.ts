import type { Context, Next } from "hono";

const BEARER = /^Bearer\s+(.*)$/i;

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) {
    out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return out === 0;
}

export async function authMiddleware(c: Context, next: Next): Promise<Response | void> {
  const bypass =
    process.env.DEV_AUTH_BYPASS === "1" ||
    (process.env.NODE_ENV !== "production" && process.env.TASK_API_BEARER_TOKEN === undefined);
  const expected = process.env.TASK_API_BEARER_TOKEN?.trim();

  if (bypass || !expected) {
    c.set("userId", "dev-user");
    await next();
    return;
  }

  const auth = c.req.header("authorization") ?? "";
  const m = BEARER.exec(auth);
  const token = m?.[1]?.trim() ?? "";
  if (!timingSafeEqual(token, expected)) {
    return c.json({ error: "Unauthorized" }, 401);
  }

  c.set("userId", "bearer-user");
  await next();
}

export async function internalPreviewGuard(c: Context, next: Next): Promise<Response | void> {
  const secret = process.env.INTERNAL_PREVIEW_SECRET?.trim();
  if (!secret) {
    return c.json({ error: "Preview updates are not configured" }, 503);
  }
  const got = c.req.header("x-clone-agent-internal")?.trim() ?? "";
  if (!got || got.length !== secret.length) {
    return c.json({ error: "Forbidden" }, 403);
  }
  let diff = 0;
  for (let i = 0; i < secret.length; i++) {
    diff |= secret.charCodeAt(i) ^ got.charCodeAt(i);
  }
  if (diff !== 0) {
    return c.json({ error: "Forbidden" }, 403);
  }
  await next();
}
