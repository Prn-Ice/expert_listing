import { createClient } from "@supabase/supabase-js";
import { app } from "../src/app.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(
      `${name} must be set. Run the local Supabase stack and configure .env.local.`,
    );
  }
  return value;
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const dbUrl = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:56322/postgres";

const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Seeded feed order: created_at desc, id desc. Posts 1003 and 1004 tie on
// timestamp, so the id desc tiebreak puts 1004 first.
const ALL_POST_IDS = [
  1001,
  1002,
  1004,
  1003,
  1005,
  1006,
  1007,
  1008,
  1009,
  1010,
  1011,
  1012,
];

type ApiResult = {
  status: number;
  headers: Headers;
  // deno-lint-ignore no-explicit-any
  body: any;
  rawBody: string;
};

async function api(path: string): Promise<ApiResult> {
  const response = await app.request(`http://127.0.0.1:56321/api${path}`);
  const rawBody = await response.text();
  let body = null;
  try {
    body = JSON.parse(rawBody);
  } catch {
    // Non-JSON bodies fail assertions through rawBody.
  }
  return { status: response.status, headers: response.headers, body, rawBody };
}

function assertPostIds(body: { posts: { id: number }[] }, expected: number[]) {
  const actual = body.posts.map((post) => post.id);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected post IDs ${expected}, received ${actual}.`);
  }
}

function assertValidationError(result: ApiResult) {
  if (result.status !== 400) {
    throw new Error(`Expected 400, received ${result.status}: ${result.rawBody}`);
  }
  if (result.body?.error?.code !== "VALIDATION_ERROR") {
    throw new Error(`Expected VALIDATION_ERROR, received ${result.rawBody}.`);
  }
  if (result.headers.get("cache-control") !== "no-store") {
    throw new Error("Error responses must not be cacheable.");
  }
}

function encodeRawCursor(payload: unknown): string {
  return btoa(JSON.stringify(payload))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

async function psql(sql: string): Promise<string> {
  const command = new Deno.Command("psql", {
    args: [dbUrl, "--no-psqlrc", "-v", "ON_ERROR_STOP=1", "-tA", "-c", sql],
    clearEnv: true,
    stdout: "piped",
    stderr: "piped",
  });
  const output = await command.output();
  if (!output.success) {
    throw new Error(`psql failed: ${new TextDecoder().decode(output.stderr)}`);
  }
  return new TextDecoder().decode(output.stdout).trim();
}

Deno.test("GET /api/posts returns the first page with the default limit", async () => {
  const result = await api("/posts");

  if (result.status !== 200) {
    throw new Error(`Expected 200, received ${result.status}: ${result.rawBody}`);
  }
  if (result.headers.get("cache-control") !== "private, max-age=0") {
    throw new Error(
      `Unexpected Cache-Control: ${result.headers.get("cache-control")}`,
    );
  }
  assertPostIds(result.body, ALL_POST_IDS.slice(0, 10));
  if (typeof result.body.nextCursor !== "string") {
    throw new Error("Expected a nextCursor string on a full page.");
  }
});

Deno.test("GET /api/posts honours the maximum limit and ends with JSON null", async () => {
  const result = await api("/posts?limit=20");

  if (result.status !== 200) {
    throw new Error(`Expected 200, received ${result.status}: ${result.rawBody}`);
  }
  assertPostIds(result.body, ALL_POST_IDS);
  if (result.body.nextCursor !== null) {
    throw new Error("The final page must use JSON null for nextCursor.");
  }

  const overLimit = await api("/posts?limit=21");
  assertValidationError(overLimit);

  const zeroLimit = await api("/posts?limit=0");
  assertValidationError(zeroLimit);

  const wordLimit = await api("/posts?limit=ten");
  assertValidationError(wordLimit);
});

Deno.test("GET /api/posts walks every row once across tied timestamps", async () => {
  const seen: number[] = [];
  let cursor: string | null = null;

  do {
    const path = cursor === null
      ? "/posts?limit=3"
      : `/posts?limit=3&cursor=${encodeURIComponent(cursor)}`;
    const result: ApiResult = await api(path);

    if (result.status !== 200) {
      throw new Error(`Expected 200, received ${result.status}: ${result.rawBody}`);
    }
    seen.push(...result.body.posts.map((post: { id: number }) => post.id));
    cursor = result.body.nextCursor;
  } while (cursor !== null);

  if (JSON.stringify(seen) !== JSON.stringify(ALL_POST_IDS)) {
    throw new Error(`Walked ${seen}, expected ${ALL_POST_IDS}.`);
  }
  if (new Set(seen).size !== seen.length) {
    throw new Error("Pagination produced a duplicate row.");
  }
});

Deno.test("GET /api/posts rejects invalid cursors instead of returning page one", async () => {
  const invalidCursors = [
    "not-a-cursor",
    "",
    encodeRawCursor({ v: 2, createdAt: "2026-09-02T11:45:00.000Z", id: 1002 }),
    encodeRawCursor({ createdAt: "2026-09-02T11:45:00.000Z", id: 1002 }),
    encodeRawCursor({ v: 1, createdAt: "not-a-date", id: 1002 }),
    encodeRawCursor({ v: 1, createdAt: "2026-09-02T11:45:00.000Z", id: "1002" }),
    encodeRawCursor({ v: 1, createdAt: "2026-09-02T11:45:00.000Z", id: 0 }),
    encodeRawCursor([1, 2, 3]),
  ];

  for (const cursor of invalidCursors) {
    const result = await api(`/posts?cursor=${encodeURIComponent(cursor)}`);
    assertValidationError(result);
  }
});

Deno.test("GET /api/posts stays stable when a post is inserted between pages", async () => {
  const firstPage = await api("/posts?limit=2");
  if (firstPage.status !== 200) {
    throw new Error(`Expected 200, received ${firstPage.status}.`);
  }
  assertPostIds(firstPage.body, [1001, 1002]);

  const { data: newPostId, error } = await serviceClient.rpc("create_post", {
    p_author_id: "00000000-0000-0000-0000-000000000001",
    p_body: "Temporary pagination probe post",
    p_post_type: "general",
    p_location: "Testville, Lagos",
  });
  if (error) {
    throw new Error(`Probe post creation failed: ${error.message}`);
  }
  if (!Number.isSafeInteger(newPostId)) {
    throw new Error(`Expected a numeric post id, received ${newPostId}.`);
  }

  try {
    const secondPage = await api(
      `/posts?limit=2&cursor=${encodeURIComponent(firstPage.body.nextCursor)}`,
    );
    if (secondPage.status !== 200) {
      throw new Error(`Expected 200, received ${secondPage.status}.`);
    }

    // The newer probe post must not repeat on or displace the original page two.
    assertPostIds(secondPage.body, [1004, 1003]);
  } finally {
    await psql(`delete from public.posts where id = ${newPostId};`);
  }

  const remaining = await psql(
    `select count(*) from public.posts where id = ${newPostId};`,
  );
  if (remaining !== "0") {
    throw new Error("Probe post cleanup failed.");
  }
});

Deno.test("GET /api/posts filters by post type and variant filters", async () => {
  const cases: [string, number[]][] = [
    ["/posts?postType=general", [1005, 1007, 1011]],
    ["/posts?postType=request", [1002, 1004, 1009]],
    ["/posts?postType=request&requestType=looking_to_buy", [1004, 1009]],
    ["/posts?postType=request&requestType=looking_to_rent", [1002]],
    ["/posts?postType=property", [1001, 1003, 1006, 1008, 1010, 1012]],
    ["/posts?postType=property&propertyStatus=for_sale", [1001, 1008, 1012]],
    ["/posts?postType=property&propertyStatus=for_rent", [1003, 1006, 1010]],
  ];

  for (const [path, expected] of cases) {
    const result = await api(path);
    if (result.status !== 200) {
      throw new Error(`${path}: expected 200, received ${result.status}.`);
    }
    assertPostIds(result.body, expected);
  }
});

Deno.test("GET /api/posts rejects variant filters on the wrong post type", async () => {
  const invalid = [
    "/posts?requestType=looking_to_buy",
    "/posts?postType=general&requestType=looking_to_buy",
    "/posts?postType=property&requestType=looking_to_buy",
    "/posts?propertyStatus=for_sale",
    "/posts?postType=general&propertyStatus=for_sale",
    "/posts?postType=request&propertyStatus=for_sale",
    "/posts?postType=unknown",
    "/posts?postType=request&requestType=for_sale",
    "/posts?postType=property&propertyStatus=looking_to_rent",
  ];

  for (const path of invalid) {
    assertValidationError(await api(path));
  }
});

Deno.test("GET /api/posts searches the selected variant's owned location", async () => {
  const cases: [string, number[]][] = [
    ["/posts?location=Lekki", [1001]],
    ["/posts?location=Yaba", [1002]],
    ["/posts?location=Magodo&postType=property", [1008]],
    ["/posts?location=Magodo&postType=request", []],
    ["/posts?location=lagos&limit=20", ALL_POST_IDS],
    ["/posts?location=%20Lekki%20", [1001]],
  ];

  for (const [path, expected] of cases) {
    const result = await api(path);
    if (result.status !== 200) {
      throw new Error(`${path}: expected 200, received ${result.status}.`);
    }
    assertPostIds(result.body, expected);
  }
});

Deno.test("GET /api/posts matches location literally, escaping LIKE wildcards", async () => {
  // No seeded location contains %, _, or a backslash. Unescaped wildcards would
  // match every row, so an empty page proves literal matching.
  for (const encoded of ["%25", "_", "%5C"]) {
    const result = await api(`/posts?location=${encoded}`);
    if (result.status !== 200) {
      throw new Error(`Expected 200, received ${result.status}.`);
    }
    assertPostIds(result.body, []);
    if (result.body.nextCursor !== null) {
      throw new Error("An empty page must have a null nextCursor.");
    }
  }
});

Deno.test("GET /api/posts rejects out-of-range locations", async () => {
  assertValidationError(await api("/posts?location="));
  assertValidationError(await api("/posts?location=%20%20%20"));
  assertValidationError(await api(`/posts?location=${"a".repeat(121)}`));

  const longest = await api(`/posts?location=${"a".repeat(120)}`);
  if (longest.status !== 200) {
    throw new Error(`Expected 200 for a 120-character location.`);
  }
  assertPostIds(longest.body, []);
});

Deno.test("GET /api/posts rejects unknown query parameters instead of failing open", async () => {
  // transactionType was retired with the variant model; accepting it silently
  // would return an unfiltered feed that looks like a working filter.
  const legacy = await api("/posts?transactionType=for_rent");
  assertValidationError(legacy);
  if (!legacy.body.error.message.includes("transactionType")) {
    throw new Error("The error should name the unsupported parameter.");
  }

  assertValidationError(await api("/posts?unknown=1"));
  assertValidationError(await api("/posts?posttype=general"));
});

Deno.test("GET /api/posts returns stable discriminated DTO shapes", async () => {
  const result = await api("/posts?limit=20");
  if (result.status !== 200) {
    throw new Error(`Expected 200, received ${result.status}.`);
  }

  const posts = result.body.posts as Record<string, unknown>[];
  const byId = new Map(posts.map((post) => [post.id as number, post]));

  const general = byId.get(1005)!;
  if (general.postType !== "general") throw new Error("1005 must be general.");
  if (general.location !== "Victoria Island, Lagos") {
    throw new Error("A general post carries its own location.");
  }
  if ("request" in general || "property" in general) {
    throw new Error("A general post must not carry variant payloads.");
  }

  const request = byId.get(1002)! as {
    postType: string;
    request?: { type: string; location: string };
  };
  if (request.postType !== "request") throw new Error("1002 must be a request.");
  if (
    request.request?.type !== "looking_to_rent" ||
    request.request?.location !== "Yaba, Lagos"
  ) {
    throw new Error("A request post carries request { type, location }.");
  }
  if ("location" in request || "property" in request) {
    throw new Error("A request post must not carry other variant payloads.");
  }

  const property = byId.get(1001)! as {
    postType: string;
    property?: {
      id: number;
      status: string;
      location: string;
      images: { id: number; url: string; position: number }[];
    };
  };
  if (property.postType !== "property") throw new Error("1001 must be a property.");
  const propertyPayload = property.property;
  if (
    !propertyPayload || propertyPayload.id !== 5001 ||
    propertyPayload.status !== "for_sale" ||
    propertyPayload.location !== "Lekki Phase 1, Lagos"
  ) {
    throw new Error("A property post carries property { id, status, location }.");
  }
  const positions = propertyPayload.images.map((image) => image.position);
  if (JSON.stringify(positions) !== "[0,1]") {
    throw new Error("Property images must be stably ordered by position.");
  }
  for (const image of propertyPayload.images) {
    if (!image.url.startsWith(`${supabaseUrl}/storage/v1/object/public/media/properties/`)) {
      throw new Error(`Unexpected image URL: ${image.url}`);
    }
  }

  const author = general.author as Record<string, unknown>;
  for (const key of ["id", "handle", "displayName", "role", "avatarUrl"]) {
    if (!(key in author)) throw new Error(`Author is missing ${key}.`);
  }
  if (
    typeof author.avatarUrl !== "string" ||
    !author.avatarUrl.startsWith(`${supabaseUrl}/storage/v1/object/public/media/avatars/`)
  ) {
    throw new Error(`Unexpected avatar URL: ${author.avatarUrl}`);
  }

  const engaged = byId.get(1001)!;
  if (engaged.likeCount !== 2 || engaged.commentCount !== 2) {
    throw new Error("Engagement counts must come from related rows.");
  }
  if (engaged.likedByCurrentUser !== true) {
    throw new Error("Post 1001 is liked by the seeded current user.");
  }
  if (byId.get(1002)!.likedByCurrentUser !== false) {
    throw new Error("Post 1002 is not liked by the seeded current user.");
  }

  if (general.createdAt !== "2026-09-02T11:15:00.000Z") {
    throw new Error(`Dates must be UTC ISO-8601: ${general.createdAt}`);
  }
  if (typeof general.id !== "number") {
    throw new Error("Post IDs must be JSON numbers.");
  }
});

Deno.test("unknown routes return the stable NOT_FOUND envelope", async () => {
  const result = await api("/definitely-not-here");

  if (result.status !== 404) {
    throw new Error(`Expected 404, received ${result.status}.`);
  }
  if (result.body?.error?.code !== "NOT_FOUND") {
    throw new Error(`Expected NOT_FOUND, received ${result.rawBody}.`);
  }
  if (result.headers.get("cache-control") !== "no-store") {
    throw new Error("Error responses must not be cacheable.");
  }
});

Deno.test("an unreachable backend returns a safe INTERNAL_ERROR", async () => {
  const originalUrl = Deno.env.get("SUPABASE_URL");
  Deno.env.set("SUPABASE_URL", "http://127.0.0.1:1");

  try {
    const result = await api("/posts");
    if (result.status !== 500) {
      throw new Error(`Expected 500, received ${result.status}.`);
    }
    if (result.body?.error?.code !== "INTERNAL_ERROR") {
      throw new Error(`Expected INTERNAL_ERROR, received ${result.rawBody}.`);
    }
    if (result.headers.get("cache-control") !== "no-store") {
      throw new Error("Error responses must not be cacheable.");
    }
    const leaks = ["feed_page", "relation", "select ", serviceRoleKey];
    for (const leak of leaks) {
      if (result.rawBody.includes(leak)) {
        throw new Error(`Error response leaks implementation detail: ${leak}`);
      }
    }
  } finally {
    if (originalUrl === undefined) {
      Deno.env.delete("SUPABASE_URL");
    } else {
      Deno.env.set("SUPABASE_URL", originalUrl);
    }
  }
});

Deno.test("responses never carry the service credential", async () => {
  const feed = await api("/posts?limit=20");
  const notFound = await api("/definitely-not-here");

  for (const result of [feed, notFound]) {
    if (result.rawBody.includes(serviceRoleKey)) {
      throw new Error("A response body contains the service credential.");
    }
    for (const [name, value] of result.headers) {
      if (name.toLowerCase().includes("authorization") || value.includes(serviceRoleKey)) {
        throw new Error("A response header contains the service credential.");
      }
    }
  }
});
