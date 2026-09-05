import { app } from "../src/app.ts";

async function api(path: string, alias: string) {
  const response = await app.request(`http://127.0.0.1:56321/api${path}`, {
    headers: { "X-Preview-Actor": alias },
  });
  const rawBody = await response.text();
  return { response, body: JSON.parse(rawBody), rawBody };
}

async function post(path: string, alias: string, body: unknown) {
  const response = await app.request(`http://127.0.0.1:56321/api${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Preview-Actor": alias,
    },
    body: JSON.stringify(body),
  });
  const rawBody = await response.text();
  return { response, body: JSON.parse(rawBody), rawBody };
}

Deno.test("preview aliases resolve profiles without exposing user IDs", async () => {
  const result = await api("/profile", "ayo");
  if (result.response.status !== 200) {
    throw new Error(`Expected 200, received ${result.rawBody}`);
  }
  if (result.body.profile?.displayName !== "Ayo Balogun") {
    throw new Error(`Unexpected preview profile: ${result.rawBody}`);
  }
  const expectedAliases = ["prince", "ayo", "ifeoma", "bizzaro"];
  if (
    JSON.stringify(result.body.previewActors) !==
      JSON.stringify(expectedAliases)
  ) {
    throw new Error(`Unexpected preview aliases: ${result.rawBody}`);
  }
  if (result.rawBody.includes("00000000-")) {
    throw new Error("Preview responses must not expose fixture UUIDs.");
  }
});

Deno.test("preview aliases are request-scoped for feed viewer state", async () => {
  const prince = await api("/posts?limit=1", "prince");
  const ayo = await api("/posts?limit=1", "ayo");
  if (prince.body.posts?.[0]?.likedByCurrentUser !== true) {
    throw new Error(`Prince's like state was not resolved: ${prince.rawBody}`);
  }
  if (ayo.body.posts?.[0]?.likedByCurrentUser !== false) {
    throw new Error(`Ayo inherited another actor's state: ${ayo.rawBody}`);
  }
});

Deno.test("preview actor headers accept aliases only", async () => {
  for (
    const value of [
      "unknown",
      "00000000-0000-0000-0000-000000000002",
      "AYO",
    ]
  ) {
    const result = await api("/profile", value);
    if (
      result.response.status !== 400 ||
      result.body.error?.code !== "VALIDATION_ERROR"
    ) {
      throw new Error(`Expected ${value} to be rejected: ${result.rawBody}`);
    }
  }
});

Deno.test("preview like mutations remain request-actor scoped", async () => {
  const postId = 1002;
  const initialPrince = await api("/posts?limit=20", "prince");
  const initialAyo = await api("/posts?limit=20", "ayo");
  const princeWasLiked = initialPrince.body.posts.find(
    (item: { id: number }) => item.id === postId,
  )?.likedByCurrentUser === true;
  const ayoWasLiked = initialAyo.body.posts.find(
    (item: { id: number }) => item.id === postId,
  )?.likedByCurrentUser === true;

  try {
    await post(`/posts/${postId}/like`, "prince", { liked: false });
    await post(`/posts/${postId}/like`, "ayo", { liked: false });
    const liked = await post(`/posts/${postId}/like`, "ayo", { liked: true });
    if (liked.response.status !== 200 || liked.body.liked !== true) {
      throw new Error(`Ayo could not like the post: ${liked.rawBody}`);
    }
    const princeFeed = await api("/posts?limit=20", "prince");
    const ayoFeed = await api("/posts?limit=20", "ayo");
    const princePost = princeFeed.body.posts.find(
      (item: { id: number }) => item.id === postId,
    );
    const ayoPost = ayoFeed.body.posts.find(
      (item: { id: number }) => item.id === postId,
    );
    if (princePost?.likedByCurrentUser !== false) {
      throw new Error("Prince inherited Ayo's like mutation.");
    }
    if (ayoPost?.likedByCurrentUser !== true) {
      throw new Error("Ayo's mutation was not resolved for Ayo.");
    }
  } finally {
    await post(`/posts/${postId}/like`, "ayo", { liked: ayoWasLiked });
    await post(`/posts/${postId}/like`, "prince", { liked: princeWasLiked });
  }
});
