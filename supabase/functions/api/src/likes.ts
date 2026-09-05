import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { resolveRequestActor } from "./actor.ts";
import { readEnv } from "./env.ts";
import { ApiError, internalError } from "./errors.ts";
import { parsePostId, readJsonObject, requireExactFields } from "./request.ts";

type LikeRow = {
  post_id: number | string;
  liked: boolean;
  like_count: number | string;
};

export async function setPostLike(context: Context): Promise<Response> {
  const postId = parsePostId(context.req.param("id"));
  const body = await readJsonObject(context);
  requireExactFields(body, ["liked"]);
  if (typeof body.liked !== "boolean") {
    throw new ApiError(400, "VALIDATION_ERROR", "Choose a like state.");
  }
  const env = readEnv();
  if (!env) throw internalError();
  const actor = resolveRequestActor(context, env);
  const supabase = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc("set_post_like", {
    p_actor_id: actor.userId,
    p_post_id: postId,
    p_liked: body.liked,
  });
  if (error) {
    if (error.code === "P0002") {
      throw new ApiError(404, "NOT_FOUND", "That post does not exist.");
    }
    console.error("set_post_like failed:", error.message);
    throw internalError();
  }
  const row = (data as LikeRow[] | null)?.at(0);
  if (!row) throw internalError();
  return context.json(
    {
      postId: Number(row.post_id),
      liked: row.liked,
      likeCount: Number(row.like_count),
    },
    200,
    { "Cache-Control": "no-store" },
  );
}
