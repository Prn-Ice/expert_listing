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
  const expectedAliases = ["prince", "ayo", "ifeoma", "bizzaro"];
  if (
    JSON.stringify(result.body.previewActors) !==
      JSON.stringify(expectedAliases)
  ) {
    throw new Error("The fixed public demo aliases must be advertised.");
  }
  if (result.rawBody.includes("00000000-")) {
    throw new Error("Profile responses must not expose fixture UUIDs.");
  }
  if (result.response.headers.get("cache-control") !== "private, max-age=0") {
    throw new Error("Profile responses must require revalidation.");
  }
});

Deno.test("GET /api/profile accepts a fixed public demo alias", async () => {
  const result = await api({ "X-Preview-Actor": "ayo" });
  if (result.response.status !== 200 || result.body.profile?.handle !== "ayo") {
    throw new Error(
      `Expected Ayo's profile, received ${result.rawBody}`,
    );
  }
  if (result.rawBody.includes("00000000-")) {
    throw new Error("Profile responses must not expose fixture UUIDs.");
  }
});

Deno.test("GET /api/profile rejects unknown aliases and raw UUIDs", async () => {
  for (
    const alias of [
      "unknown",
      "00000000-0000-0000-0000-000000000002",
      "AYO",
    ]
  ) {
    const result = await api({ "X-Preview-Actor": alias });
    if (
      result.response.status !== 400 ||
      result.body.error?.code !== "VALIDATION_ERROR"
    ) {
      throw new Error(`Expected ${alias} to be rejected: ${result.rawBody}`);
    }
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
