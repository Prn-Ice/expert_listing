import { Hono } from "hono";
import { ApiError, errorResponse } from "./errors.ts";
import { getPosts } from "./feed.ts";

export const app = new Hono().basePath("/api");

app.get("/health", (context) => context.json({ status: "ok" }));
app.get("/posts", getPosts);

app.notFound(() =>
  errorResponse(new ApiError(404, "NOT_FOUND", "That route does not exist."))
);

app.onError((error) => {
  if (error instanceof ApiError) {
    return errorResponse(error);
  }

  console.error("Unhandled error:", error);
  return errorResponse(
    new ApiError(500, "INTERNAL_ERROR", "Something went wrong. Try again later."),
  );
});
