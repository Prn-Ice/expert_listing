import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { availablePreviewAliases, resolveRequestActor } from "./actor.ts";
import { type AppEnv, readEnv } from "./env.ts";
import { ApiError, internalError, validationError } from "./errors.ts";

type ProfileRow = {
  handle: string;
  display_name: string;
  role: string;
  avatar_path: string | null;
};

function publicOrigin(context: Context, env: AppEnv): string {
  if (env.publicUrlOverride) return env.publicUrlOverride;

  const forwardedHost = context.req.header("x-forwarded-host");
  if (forwardedHost) {
    const proto = context.req.header("x-forwarded-proto") ?? "https";
    const port = context.req.header("x-forwarded-port") ?? "";
    const defaultPort = proto === "https" ? "443" : "80";
    return port === "" || port === defaultPort
      ? `${proto}://${forwardedHost}`
      : `${proto}://${forwardedHost}:${port}`;
  }

  return new URL(context.req.url).origin;
}

function avatarUrl(origin: string, path: string | null): string | null {
  return path ? `${origin}/storage/v1/object/public/media/${path}` : null;
}

export async function getProfile(context: Context): Promise<Response> {
  const queryNames = Object.keys(context.req.query());
  if (queryNames.length > 0) {
    throw validationError(
      `Remove the unsupported query parameter: ${queryNames[0]}.`,
    );
  }
  const env = readEnv();
  if (!env) {
    console.error(
      "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not configured.",
    );
    throw internalError();
  }
  const actor = resolveRequestActor(context, env);
  const supabase = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc("user_profile", {
    p_user_id: actor.userId,
  });
  if (error) {
    console.error("user_profile failed:", error.message);
    throw internalError();
  }

  const profile = (data as ProfileRow[] | null)?.at(0);
  if (!profile) {
    throw new ApiError(404, "NOT_FOUND", "That profile does not exist.");
  }
  const origin = publicOrigin(context, env);
  return context.json(
    {
      profile: {
        handle: profile.handle,
        displayName: profile.display_name,
        role: profile.role,
        avatarUrl: avatarUrl(origin, profile.avatar_path),
      },
      previewActors: availablePreviewAliases(env),
    },
    200,
    { "Cache-Control": "private, max-age=0" },
  );
}
