import { app } from "../src/app.ts";

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

function assertValidationError(result: ApiResult) {
  if (
    result.status !== 400 || result.body?.error?.code !== "VALIDATION_ERROR"
  ) {
    throw new Error(`Expected validation error, received ${result.rawBody}.`);
  }
  if (result.headers.get("cache-control") !== "no-store") {
    throw new Error("Search errors must not be cacheable.");
  }
}

Deno.test("GET /api/search/suggestions returns locations and properties", async () => {
  const result = await api("/search/suggestions?q=Lekki");
  if (result.status !== 200) {
    throw new Error(
      `Expected 200, received ${result.status}: ${result.rawBody}`,
    );
  }
  if (result.headers.get("cache-control") !== "private, max-age=0") {
    throw new Error("Search responses must require revalidation.");
  }

  const location = result.body.suggestions.find(
    (suggestion: { type: string }) => suggestion.type === "location",
  );
  const property = result.body.suggestions.find(
    (suggestion: { type: string }) => suggestion.type === "property",
  );
  if (
    location?.label !== "Lekki Phase 1, Lagos" || location.propertyCount !== 1
  ) {
    throw new Error(
      `Unexpected location suggestion: ${JSON.stringify(location)}`,
    );
  }
  if (
    property?.postId !== 1001 ||
    property?.propertyId !== 5001 ||
    property?.status !== "for_sale" ||
    !property?.imageUrl?.endsWith("/properties/lekki-kitchen-01.jpg")
  ) {
    throw new Error(
      `Unexpected property suggestion: ${JSON.stringify(property)}`,
    );
  }
});

Deno.test("GET /api/search/suggestions matches property summaries", async () => {
  const result = await api("/search/suggestions?q=waterfront");
  if (result.status !== 200) {
    throw new Error(
      `Expected 200, received ${result.status}: ${result.rawBody}`,
    );
  }
  const postIds = result.body.suggestions
    .filter((suggestion: { type: string }) => suggestion.type === "property")
    .map((suggestion: { postId: number }) => suggestion.postId);
  if (JSON.stringify(postIds) !== JSON.stringify([1006])) {
    throw new Error(`Expected post 1006, received ${postIds}.`);
  }
});

Deno.test("GET /api/search/suggestions keeps properties in broad location results", async () => {
  const result = await api("/search/suggestions?q=Lagos");
  if (result.status !== 200) {
    throw new Error(
      `Expected 200, received ${result.status}: ${result.rawBody}`,
    );
  }
  const types = result.body.suggestions.map(
    (suggestion: { type: string }) => suggestion.type,
  );
  if (!types.includes("location") || !types.includes("property")) {
    throw new Error(`Expected both suggestion types, received ${types}.`);
  }
});

Deno.test("GET /api/search/suggestions validates query and limit", async () => {
  for (
    const path of [
      "/search/suggestions",
      "/search/suggestions?q=a",
      "/search/suggestions?q=ab",
      `/search/suggestions?q=${"a".repeat(121)}`,
      "/search/suggestions?q=Lekki&limit=0",
      "/search/suggestions?q=Lekki&limit=11",
      "/search/suggestions?q=Lekki&limit=many",
      "/search/suggestions?q=Lekki&extra=true",
    ]
  ) {
    assertValidationError(await api(path));
  }
});

Deno.test("GET /api/search/suggestions treats wildcards literally", async () => {
  for (const query of ["%25%25%25", "___", "%5C%5C%5C"]) {
    const result = await api(`/search/suggestions?q=${query}`);
    if (result.status !== 200 || result.body.suggestions.length !== 0) {
      throw new Error(`Expected no matches, received ${result.rawBody}.`);
    }
  }
});
