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

async function api(path: string, init?: RequestInit): Promise<ApiResult> {
  const response = await app.request(
    `http://127.0.0.1:56321/api${path}`,
    init,
  );
  const rawBody = await response.text();
  let body = null;
  try {
    body = JSON.parse(rawBody);
  } catch {
    // Non-JSON responses fail the assertions below through rawBody.
  }
  return { status: response.status, headers: response.headers, body, rawBody };
}

function json(method: "POST", body: unknown): RequestInit {
  return {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
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

async function deleteProbePost(postId: number): Promise<void> {
  const command = new Deno.Command("psql", {
    args: [
      dbUrl,
      "--no-psqlrc",
      "-v",
      "ON_ERROR_STOP=1",
      "-c",
      `delete from public.posts where id = ${postId};`,
    ],
    clearEnv: true,
    stdout: "piped",
    stderr: "piped",
  });
  const output = await command.output();
  if (!output.success) {
    throw new Error(
      `Probe post cleanup failed: ${new TextDecoder().decode(output.stderr)}`,
    );
  }
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

Deno.test("POST /api/posts/:id/like is idempotent under repeated requests", async () => {
  const postId = await createProbePost("Concurrent like probe");
  try {
    const results = await Promise.all(
      Array.from(
        { length: 8 },
        () => api(`/posts/${postId}/like`, json("POST", { liked: true })),
      ),
    );
    for (const result of results) {
      if (
        result.status !== 200 || result.body.postId !== postId ||
        result.body.liked !== true
      ) {
        throw new Error(`Unexpected like response: ${result.rawBody}`);
      }
    }
    const settled = await api(
      `/posts/${postId}/like`,
      json("POST", { liked: true }),
    );
    if (settled.body.likeCount !== 1) {
      throw new Error(`Expected one persisted like: ${settled.rawBody}`);
    }

    const unlike = await api(
      `/posts/${postId}/like`,
      json("POST", { liked: false }),
    );
    const repeatedUnlike = await api(
      `/posts/${postId}/like`,
      json("POST", { liked: false }),
    );
    if (
      unlike.status !== 200 || unlike.body.likeCount !== 0 ||
      repeatedUnlike.status !== 200 || repeatedUnlike.body.likeCount !== 0
    ) {
      throw new Error("Repeated unlikes must converge on zero likes.");
    }
  } finally {
    await deleteProbePost(postId);
  }
});

Deno.test("comments persist, hydrate their author, and list oldest first", async () => {
  const postId = await createProbePost("Comment order probe");
  try {
    const first = await api(
      `/posts/${postId}/comments`,
      json("POST", { body: "  First comment  " }),
    );
    const second = await api(
      `/posts/${postId}/comments`,
      json("POST", { body: "Second comment" }),
    );
    if (first.status !== 201 || first.body.body !== "First comment") {
      throw new Error(`Unexpected first comment: ${first.rawBody}`);
    }
    if (
      second.status !== 201 || second.body.postId !== postId ||
      second.body.author?.handle !== "prince" ||
      !second.body.author?.avatarUrl?.startsWith(
        `${supabaseUrl}/storage/v1/object/public/media/avatars/`,
      )
    ) {
      throw new Error(`Unexpected hydrated comment: ${second.rawBody}`);
    }

    const listed = await api(`/posts/${postId}/comments`);
    if (
      listed.status !== 200 ||
      JSON.stringify(
          listed.body.comments.map((item: { body: string }) => item.body),
        ) !==
        JSON.stringify(["First comment", "Second comment"])
    ) {
      throw new Error(`Comments are not oldest first: ${listed.rawBody}`);
    }
    if (listed.headers.get("cache-control") !== "no-store") {
      throw new Error("Comments must not be cached for offline use.");
    }
  } finally {
    await deleteProbePost(postId);
  }
});

Deno.test("engagement endpoints reject invalid requests and missing posts", async () => {
  const cases: Array<[string, RequestInit | undefined, number, string]> = [
    [
      "/posts/nope/like",
      json("POST", { liked: true }),
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/posts/1001/like",
      json("POST", { liked: "yes" }),
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/posts/1001/like",
      json("POST", { liked: true, actor: "ayo" }),
      400,
      "VALIDATION_ERROR",
    ],
    [
      "/posts/1001/like",
      { method: "POST", body: '{"liked":true}' },
      415,
      "UNSUPPORTED_MEDIA_TYPE",
    ],
    [
      "/posts/1001/comments",
      json("POST", { body: " " }),
      400,
      "VALIDATION_ERROR",
    ],
    ["/posts/1001/comments?limit=1", undefined, 400, "VALIDATION_ERROR"],
    ["/posts/999999/like", json("POST", { liked: true }), 404, "NOT_FOUND"],
    ["/posts/999999/comments", undefined, 404, "NOT_FOUND"],
    [
      "/posts/999999/comments",
      json("POST", { body: "Hello" }),
      404,
      "NOT_FOUND",
    ],
  ];
  for (const [path, init, status, code] of cases) {
    assertError(await api(path, init), status, code);
  }
});

Deno.test("comment limits count Unicode code points", async () => {
  const postId = await createProbePost("Unicode comment probe");
  try {
    const accepted = await api(
      `/posts/${postId}/comments`,
      json("POST", { body: "😀".repeat(1000) }),
    );
    if (accepted.status !== 201) {
      throw new Error(
        `Expected 1000 emoji to be accepted: ${accepted.rawBody}`,
      );
    }
    const rejected = await api(
      `/posts/${postId}/comments`,
      json("POST", { body: "😀".repeat(1001) }),
    );
    assertError(rejected, 400, "VALIDATION_ERROR");
  } finally {
    await deleteProbePost(postId);
  }
});
