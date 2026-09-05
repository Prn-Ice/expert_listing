import { Hono } from "hono";
import { ApiError, errorResponse } from "./errors.ts";
import { createPostComment, getPostComments } from "./comments.ts";
import { getPosts } from "./feed.ts";
import { setPostLike } from "./likes.ts";
import { getProfile } from "./profile.ts";
import { getSearchSuggestions } from "./search.ts";

export const app = new Hono().basePath("/api");

app.get("/health", (context) => context.json({ status: "ok" }));
app.get("/posts", getPosts);
app.post("/posts/:id/like", setPostLike);
app.get("/posts/:id/comments", getPostComments);
app.post("/posts/:id/comments", createPostComment);
app.get("/profile", getProfile);
app.get("/search/suggestions", getSearchSuggestions);

app.notFound(() =>
  errorResponse(new ApiError(404, "NOT_FOUND", "That route does not exist."))
);

app.onError((error) => {
  if (error instanceof ApiError) {
    return errorResponse(error);
  }

  console.error("Unhandled error:", error);
  return errorResponse(
    new ApiError(
      500,
      "INTERNAL_ERROR",
      "Something went wrong. Try again later.",
    ),
  );
});
