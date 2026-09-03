import { app } from "../src/app.ts";

Deno.test("GET /api/health returns the expected status", async () => {
  const response = await app.request("http://127.0.0.1/api/health");

  if (!response.ok) {
    throw new Error(
      `Expected a successful response, received ${response.status}.`,
    );
  }

  const body = await response.json();
  if (body.status !== "ok") {
    throw new Error(`Expected status ok, received ${JSON.stringify(body)}.`);
  }
});

const apiBaseUrl = Deno.env.get("API_BASE_URL");

if (apiBaseUrl) {
  Deno.test("local Edge Function serves GET /health", async () => {
    const response = await fetch(`${apiBaseUrl}/health`);

    if (!response.ok) {
      throw new Error(
        `Expected a successful response, received ${response.status}.`,
      );
    }

    const body = await response.json();
    if (body.status !== "ok") {
      throw new Error(`Expected status ok, received ${JSON.stringify(body)}.`);
    }
  });
}
