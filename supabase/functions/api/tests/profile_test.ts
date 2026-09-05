import { app } from "../src/app.ts";

async function api(headers?: HeadersInit, path = "/profile") {
  const response = await app.request(
    `http://127.0.0.1:56321/api${path}`,
    { headers },
  );
  const rawBody = await response.text();
  return { response, body: JSON.parse(rawBody), rawBody };
}

Deno.test("GET /api/profile returns the configured user without identifiers", async () => {
  const result = await api();
  if (result.response.status !== 200) {
    throw new Error(
      `Expected 200, received ${result.response.status}: ${result.rawBody}`,
    );
  }
  if (result.body.profile?.displayName !== "Prince Adeyemi") {
    throw new Error(`Unexpected profile: ${result.rawBody}`);
  }
  if (result.body.profile?.handle !== "prince") {
    throw new Error(`Unexpected profile handle: ${result.rawBody}`);
  }
  if (result.body.profile?.role !== "Realtor") {
    throw new Error(`Unexpected profile role: ${result.rawBody}`);
  }
  if (
    !String(result.body.profile?.avatarUrl).endsWith(
      "/avatars/current-user.jpg",
    )
  ) {
    throw new Error(`Unexpected profile avatar: ${result.rawBody}`);
  }
  if (JSON.stringify(result.body.previewActors) !== "[]") {
    throw new Error("Disabled preview actors must not be advertised.");
  }
  if (result.rawBody.includes("00000000-")) {
    throw new Error("Profile responses must not expose fixture UUIDs.");
  }
  if (result.response.headers.get("cache-control") !== "private, max-age=0") {
    throw new Error("Profile responses must require revalidation.");
  }
});

Deno.test("GET /api/profile rejects actor overrides when disabled", async () => {
  const result = await api({ "X-Preview-Actor": "ayo" });
  if (
    result.response.status !== 403 || result.body.error?.code !== "FORBIDDEN"
  ) {
    throw new Error(
      `Expected a forbidden response, received ${result.rawBody}`,
    );
  }
  if (result.response.headers.get("cache-control") !== "no-store") {
    throw new Error("Rejected actor overrides must not be cacheable.");
  }
});

Deno.test("GET /api/profile rejects user identity query parameters", async () => {
  const result = await api(
    undefined,
    "/profile?userId=00000000-0000-0000-0000-000000000002",
  );
  if (
    result.response.status !== 400 ||
    result.body.error?.code !== "VALIDATION_ERROR"
  ) {
    throw new Error(
      `Expected a validation response, received ${result.rawBody}`,
    );
  }
});
