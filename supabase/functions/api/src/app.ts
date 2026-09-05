import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { ApiError, errorResponse } from "./errors.ts";
import { createPostComment, getPostComments } from "./comments.ts";
import { getPosts } from "./feed.ts";
import { setPostLike } from "./likes.ts";
import { getNotifications, markNotificationRead } from "./notifications.ts";
import { getProfile } from "./profile.ts";
import { createPost } from "./posts.ts";
import { getSearchSuggestions } from "./search.ts";

export const app = new Hono().basePath("/api");

app.get("/health", (context) => context.json({ status: "ok" }));
app.get("/posts", getPosts);
app.post(
  "/posts",
  bodyLimit({
    maxSize: 9 * 1024 * 1024,
    onError: () => {
      throw new ApiError(
        413,
        "PAYLOAD_TOO_LARGE",
        "The post upload is too large.",
      );
    },
  }),
  createPost,
);
app.post("/posts/:id/like", setPostLike);
app.get("/posts/:id/comments", getPostComments);
app.post("/posts/:id/comments", createPostComment);
app.get("/notifications", getNotifications);
app.post("/notifications/:id/read", markNotificationRead);
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
