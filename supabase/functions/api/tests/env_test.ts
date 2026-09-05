import { previewActorsAreEnabled } from "../src/env.ts";

Deno.test("preview actors require an exact explicit opt-in", () => {
  for (const setting of [undefined, "", "false", "TRUE", "1"]) {
    if (previewActorsAreEnabled("http://127.0.0.1:56321", setting)) {
      throw new Error(`Unexpected preview actor opt-in for ${setting}.`);
    }
  }
});

Deno.test("preview actors accept known local Supabase hosts", () => {
  for (
    const url of [
      "http://127.0.0.1:56321",
      "http://localhost:56321",
      "http://kong:8000",
      "http://host.docker.internal:56321",
    ]
  ) {
    if (!previewActorsAreEnabled(url, "true")) {
      throw new Error(`Expected ${url} to permit explicit local previews.`);
    }
  }
});

Deno.test("preview actors cannot be enabled on hosted or lookalike URLs", () => {
  for (
    const url of [
      "https://chvhwausefhvaceygppc.supabase.co",
      "https://localhost.example.com",
      "https://host.docker.internal.example.com",
      "not-a-url",
    ]
  ) {
    if (previewActorsAreEnabled(url, "true")) {
      throw new Error(`Expected ${url} to reject preview actors.`);
    }
  }
});
