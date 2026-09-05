import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { resolveRequestActor } from "./actor.ts";
import { type AppEnv, readEnv } from "./env.ts";
import { ApiError, internalError, validationError } from "./errors.ts";
import { parsePostId, readJsonObject, requireExactFields } from "./request.ts";

type CommentRow = {
  id: number | string;
  post_id: number | string;
  body: string;
  created_at: string;
  author_id: string;
  author_handle: string;
  author_display_name: string;
  author_role: string;
  author_avatar_path: string | null;
};

function publicOrigin(context: Context, env: AppEnv): string {
  if (env.publicUrlOverride) return env.publicUrlOverride;
  const forwardedHost = context.req.header("x-forwarded-host");
  if (!forwardedHost) return new URL(context.req.url).origin;
  const proto = context.req.header("x-forwarded-proto") ?? "https";
  const port = context.req.header("x-forwarded-port") ?? "";
  const defaultPort = proto === "https" ? "443" : "80";
  return port === "" || port === defaultPort
    ? `${proto}://${forwardedHost}`
    : `${proto}://${forwardedHost}:${port}`;
}

function toCommentDto(row: CommentRow, origin: string) {
  return {
    id: Number(row.id),
    postId: Number(row.post_id),
    body: row.body,
    createdAt: new Date(row.created_at).toISOString(),
    author: {
      id: row.author_id,
      handle: row.author_handle,
      displayName: row.author_display_name,
      role: row.author_role,
      avatarUrl: row.author_avatar_path
        ? `${origin}/storage/v1/object/public/media/${row.author_avatar_path}`
        : null,
    },
  };
}

function client(env: AppEnv) {
  return createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function throwRpcError(
  name: string,
  error: { code?: string; message: string },
) {
  if (error.code === "P0002") {
    throw new ApiError(404, "NOT_FOUND", "That post does not exist.");
  }
  console.error(`${name} failed:`, error.message);
  throw internalError();
}

export async function getPostComments(context: Context): Promise<Response> {
  const postId = parsePostId(context.req.param("id"));
  const queryNames = Object.keys(context.req.query());
  if (queryNames.length > 0) {
    throw validationError(
      `Remove the unsupported query parameter: ${queryNames[0]}.`,
    );
  }
  const env = readEnv();
  if (!env) throw internalError();
  resolveRequestActor(context, env);
  const { data, error } = await client(env).rpc("list_post_comments", {
    p_post_id: postId,
  });
  if (error) throwRpcError("list_post_comments", error);
  const origin = publicOrigin(context, env);
  return context.json(
    {
      comments: ((data ?? []) as CommentRow[]).map((row) =>
        toCommentDto(row, origin)
      ),
    },
    200,
    { "Cache-Control": "no-store" },
  );
}

export async function createPostComment(context: Context): Promise<Response> {
  const postId = parsePostId(context.req.param("id"));
  const body = await readJsonObject(context);
  requireExactFields(body, ["body"]);
  if (typeof body.body !== "string") {
    throw validationError("Enter a comment.");
  }
  const value = body.body.trim();
  if ([...value].length < 1 || [...value].length > 1000) {
    throw validationError("Enter 1 through 1000 characters.");
  }
  const env = readEnv();
  if (!env) throw internalError();
  const actor = resolveRequestActor(context, env);
  const { data, error } = await client(env).rpc(
    "create_post_comment",
    {
      p_actor_id: actor.userId,
      p_post_id: postId,
      p_body: value,
    },
  );
  if (error) throwRpcError("create_post_comment", error);
  const row = (data as CommentRow[] | null)?.at(0);
  if (!row) throw internalError();
  return context.json(toCommentDto(row, publicOrigin(context, env)), 201, {
    "Cache-Control": "no-store",
  });
}
