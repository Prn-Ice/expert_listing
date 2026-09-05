import { createClient } from "@supabase/supabase-js";
import { app } from "../src/app.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} must be configured for API tests.`);
  return value;
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const dbUrl = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:56322/postgres";
const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

type ApiResult = {
  status: number;
  headers: Headers;
  // deno-lint-ignore no-explicit-any
  body: any;
  rawBody: string;
};

async function api(
  path: string,
  alias = "prince",
  init: RequestInit = {},
): Promise<ApiResult> {
  const headers = new Headers(init.headers);
  headers.set("X-Preview-Actor", alias);
  const response = await app.request(
    `http://127.0.0.1:56321/api${path}`,
    { ...init, headers },
  );
  const rawBody = await response.text();
  let body = null;
  try {
    body = JSON.parse(rawBody);
  } catch {
    // Non-JSON responses fail through the assertions below.
  }
  return { status: response.status, headers: response.headers, body, rawBody };
}

function like(postId: number, alias: string, liked: boolean) {
  return api(`/posts/${postId}/like`, alias, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ liked }),
  });
}

async function createProbePost(label: string): Promise<number> {
  const { data, error } = await serviceClient.rpc("create_post", {
    p_author_id: "00000000-0000-0000-0000-000000000001",
    p_body: label,
    p_post_type: "general",
    p_location: "Testville, Lagos",
  });
  if (error || !Number.isSafeInteger(data)) {
    throw new Error(`Probe post creation failed: ${error?.message ?? data}`);
  }
  return data as number;
}

async function executeSql(sql: string): Promise<void> {
  const output = await new Deno.Command("psql", {
    args: [dbUrl, "--no-psqlrc", "-v", "ON_ERROR_STOP=1", "-c", sql],
    clearEnv: true,
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!output.success) {
    throw new Error(new TextDecoder().decode(output.stderr));
  }
}

function notificationsForPost(result: ApiResult, postId: number) {
  return result.body.notifications.filter(
    (item: { post: { id: number } }) => item.post.id === postId,
  );
}

function assertError(result: ApiResult, status: number, code: string): void {
  if (result.status !== status || result.body?.error?.code !== code) {
    throw new Error(
      `Expected ${status} ${code}, received ${result.status}: ${result.rawBody}`,
    );
  }
  if (result.headers.get("cache-control") !== "no-store") {
    throw new Error("Error responses must not be cacheable.");
  }
}

Deno.test("like notifications are durable, isolated, ordered, and idempotently read", async () => {
  const postId = await createProbePost("Notification API probe");
  try {
    const likes = await Promise.all(
      Array.from({ length: 8 }, () => like(postId, "ayo", true)),
    );
    if (likes.some((result) => result.status !== 200)) {
      throw new Error("Concurrent desired-state likes must all succeed.");
    }

    let prince = await api("/notifications", "prince");
    if (prince.status !== 200) {
      throw new Error(`Notifications failed: ${prince.rawBody}`);
    }
    if (prince.headers.get("cache-control") !== "private, max-age=0") {
      throw new Error("Notification reads must require revalidation.");
    }
    if (notificationsForPost(prince, postId).length !== 1) {
      throw new Error(
        "Concurrent repeated likes must create exactly one event.",
      );
    }
    const first = notificationsForPost(prince, postId)[0];
    if (
      first.type !== "postLike" || first.actor.handle !== "ayo" ||
      first.post.body !== "Notification API probe" || first.readAt !== null
    ) {
      throw new Error(`Unexpected notification DTO: ${JSON.stringify(first)}`);
    }
    if (
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
        .test(prince.rawBody) ||
      prince.rawBody.includes("recipient_id") ||
      prince.rawBody.includes("actor_id")
    ) {
      throw new Error("Notification DTOs must not leak UUIDs or raw fields.");
    }

    const ayo = await api("/notifications", "ayo");
    if (notificationsForPost(ayo, postId).length !== 0) {
      throw new Error("A recipient must not see another recipient's activity.");
    }

    await like(postId, "ayo", false);
    prince = await api("/notifications", "prince");
    if (notificationsForPost(prince, postId).length !== 1) {
      throw new Error("Unlike must retain durable notification history.");
    }
    await like(postId, "ayo", true);
    await like(postId, "prince", true);
    await executeSql(
      `update public.notification_events set created_at = statement_timestamp() where post_id = ${postId};`,
    );
    prince = await api("/notifications", "prince");
    const reliked = notificationsForPost(prince, postId);
    if (
      reliked.length !== 2 || reliked[0].id <= reliked[1].id ||
      reliked.some((item: { actor: { handle: string } }) =>
        item.actor.handle !== "ayo"
      )
    ) {
      throw new Error(
        "Relikes must append activity ordered by descending ID on timestamp ties.",
      );
    }

    const read = await api(`/notifications/${reliked[0].id}/read`, "prince", {
      method: "POST",
    });
    const repeatedRead = await api(
      `/notifications/${reliked[0].id}/read`,
      "prince",
      { method: "POST" },
    );
    if (
      read.status !== 200 || !read.body.readAt ||
      read.body.readAt !== repeatedRead.body.readAt ||
      read.headers.get("cache-control") !== "no-store"
    ) {
      throw new Error(
        "Read state must preserve the first timestamp and be no-store.",
      );
    }
    assertError(
      await api(`/notifications/${reliked[0].id}/read`, "ayo", {
        method: "POST",
      }),
      404,
      "NOT_FOUND",
    );
  } finally {
    await executeSql(`delete from public.posts where id = ${postId};`);
  }
});

Deno.test("notification endpoints validate bounded identity-free requests", async () => {
  const cases: Array<[string, string, RequestInit, number, string]> = [
    ["/notifications?limit=0", "prince", {}, 400, "VALIDATION_ERROR"],
    ["/notifications?limit=21", "prince", {}, 400, "VALIDATION_ERROR"],
    ["/notifications?limit=nope", "prince", {}, 400, "VALIDATION_ERROR"],
    [
      "/notifications?userId=00000000-0000-0000-0000-000000000002",
      "prince",
      {},
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/notifications",
      "00000000-0000-0000-0000-000000000002",
      {},
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/notifications/nope/read",
      "prince",
      { method: "POST" },
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/notifications/999999999/read",
      "prince",
      { method: "POST" },
      404,
      "NOT_FOUND",
    ],
  ];
  for (const [path, alias, init, status, code] of cases) {
    assertError(await api(path, alias, init), status, code);
  }

  const limited = await api("/notifications?limit=1", "prince");
  if (
    limited.status !== 200 || limited.body.notifications.length > 1 ||
    limited.headers.get("cache-control") !== "private, max-age=0"
  ) {
    throw new Error(`Unexpected bounded response: ${limited.rawBody}`);
  }
});
