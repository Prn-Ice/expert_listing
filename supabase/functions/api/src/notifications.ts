import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { resolveRequestActor } from "./actor.ts";
import { type AppEnv, readEnv } from "./env.ts";
import { ApiError, internalError, validationError } from "./errors.ts";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 20;

type NotificationRow = {
  id: number | string;
  event_type: "post_like";
  created_at: string;
  read_at: string | null;
  actor_handle: string;
  actor_display_name: string;
  actor_role: string;
  actor_avatar_path: string | null;
  post_id: number | string;
  post_body: string;
};

type MarkedNotificationRow = {
  id: number | string;
  read_at: string;
};

function parseLimit(raw: string | undefined): number {
  if (raw === undefined) return DEFAULT_LIMIT;
  if (!/^\d+$/.test(raw)) {
    throw validationError("Choose a limit from 1 through 20.");
  }
  const limit = Number(raw);
  if (limit < 1 || limit > MAX_LIMIT) {
    throw validationError("Choose a limit from 1 through 20.");
  }
  return limit;
}

function parseNotificationId(raw: string | undefined): number {
  if (raw === undefined || !/^\d+$/.test(raw)) {
    throw validationError("Choose a valid notification.");
  }
  const id = Number(raw);
  if (!Number.isSafeInteger(id) || id < 1) {
    throw validationError("Choose a valid notification.");
  }
  return id;
}

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

function client(env: AppEnv) {
  return createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function notificationDto(row: NotificationRow, origin: string) {
  if (row.event_type !== "post_like") throw internalError();
  return {
    id: Number(row.id),
    type: "postLike",
    createdAt: new Date(row.created_at).toISOString(),
    readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
    actor: {
      handle: row.actor_handle,
      displayName: row.actor_display_name,
      role: row.actor_role,
      avatarUrl: row.actor_avatar_path
        ? `${origin}/storage/v1/object/public/media/${row.actor_avatar_path}`
        : null,
    },
    post: { id: Number(row.post_id), body: row.post_body },
  };
}

export async function getNotifications(context: Context): Promise<Response> {
  const query = context.req.query();
  for (const name of Object.keys(query)) {
    if (name !== "limit") {
      throw validationError(`Remove the unsupported query parameter: ${name}.`);
    }
  }
  const limit = parseLimit(query.limit);
  const env = readEnv();
  if (!env) throw internalError();
  const actor = resolveRequestActor(context, env);
  const { data, error } = await client(env).rpc("list_notifications", {
    p_recipient_id: actor.userId,
    p_limit: limit,
  });
  if (error) {
    console.error("list_notifications failed:", error.message);
    throw internalError();
  }
  const origin = publicOrigin(context, env);
  return context.json(
    {
      notifications: ((data ?? []) as NotificationRow[]).map((row) =>
        notificationDto(row, origin)
      ),
    },
    200,
    { "Cache-Control": "private, max-age=0" },
  );
}

export async function markNotificationRead(
  context: Context,
): Promise<Response> {
  const notificationId = parseNotificationId(context.req.param("id"));
  const queryNames = Object.keys(context.req.query());
  if (queryNames.length > 0) {
    throw validationError(
      `Remove the unsupported query parameter: ${queryNames[0]}.`,
    );
  }
  const env = readEnv();
  if (!env) throw internalError();
  const actor = resolveRequestActor(context, env);
  const { data, error } = await client(env).rpc("mark_notification_read", {
    p_recipient_id: actor.userId,
    p_notification_id: notificationId,
  });
  if (error) {
    if (error.code === "P0002") {
      throw new ApiError(
        404,
        "NOT_FOUND",
        "That notification does not exist.",
      );
    }
    console.error("mark_notification_read failed:", error.message);
    throw internalError();
  }
  const row = (data as MarkedNotificationRow[] | null)?.at(0);
  if (!row) throw internalError();
  return context.json(
    { id: Number(row.id), readAt: new Date(row.read_at).toISOString() },
    200,
    { "Cache-Control": "no-store" },
  );
}
