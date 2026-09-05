import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { resolveRequestActor } from "./actor.ts";
import { decodeCursor, encodeCursor } from "./cursor.ts";
import { type AppEnv, readEnv } from "./env.ts";
import { internalError, validationError } from "./errors.ts";

const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 20;
const MAX_LOCATION_LENGTH = 120;

const ALLOWED_QUERY_PARAMS = new Set([
  "limit",
  "cursor",
  "postType",
  "requestType",
  "propertyStatus",
  "location",
]);

const POST_TYPES = new Set(["general", "request", "property"]);
const REQUEST_TYPES = new Set(["looking_to_buy", "looking_to_rent"]);
const PROPERTY_STATUSES = new Set(["for_sale", "for_rent"]);

type PropertyImageRow = {
  id: number;
  storagePath: string;
  position: number;
};

type FeedRow = {
  id: number | string;
  body: string;
  post_type: "general" | "request" | "property";
  created_at: string;
  view_count: number;
  bookmark_count: number;
  general_location: string | null;
  author_id: string;
  author_handle: string;
  author_display_name: string;
  author_role: string;
  author_avatar_path: string | null;
  request_type: "looking_to_buy" | "looking_to_rent" | null;
  request_location: string | null;
  property_id: number | string | null;
  property_status: "for_sale" | "for_rent" | null;
  property_location: string | null;
  property_images: PropertyImageRow[] | null;
  like_count: number | string;
  comment_count: number | string;
  liked_by_viewer: boolean;
};

function parseLimit(raw: string | undefined): number {
  if (raw === undefined) {
    return DEFAULT_LIMIT;
  }

  if (!/^\d+$/.test(raw)) {
    throw validationError("Choose a limit from 1 through 20.");
  }

  const limit = Number(raw);
  if (limit < 1 || limit > MAX_LIMIT) {
    throw validationError("Choose a limit from 1 through 20.");
  }

  return limit;
}

function parseFilters(query: Record<string, string>) {
  const postType = query.postType;
  if (postType !== undefined && !POST_TYPES.has(postType)) {
    throw validationError("Choose a valid post type.");
  }

  const requestType = query.requestType;
  if (requestType !== undefined) {
    if (postType !== "request") {
      throw validationError("A request type only applies to request posts.");
    }
    if (!REQUEST_TYPES.has(requestType)) {
      throw validationError("Choose a valid request type.");
    }
  }

  const propertyStatus = query.propertyStatus;
  if (propertyStatus !== undefined) {
    if (postType !== "property") {
      throw validationError(
        "A property status only applies to property posts.",
      );
    }
    if (!PROPERTY_STATUSES.has(propertyStatus)) {
      throw validationError("Choose a valid property status.");
    }
  }

  let location: string | undefined;
  if (query.location !== undefined) {
    const trimmed = query.location.trim();
    if (trimmed.length < 1 || trimmed.length > MAX_LOCATION_LENGTH) {
      throw validationError("Enter a location from 1 through 120 characters.");
    }
    location = trimmed;
  }

  return { postType, requestType, propertyStatus, location };
}

function mediaUrl(publicOrigin: string, path: string | null): string | null {
  if (!path) {
    return null;
  }

  return `${publicOrigin}/storage/v1/object/public/media/${path}`;
}

// The externally reachable origin for DTO media URLs. Behind the Supabase
// gateway the forwarded headers carry the public origin; direct request-level
// use (tests) falls back to the request URL itself.
function publicOrigin(context: Context, env: AppEnv): string {
  if (env.publicUrlOverride) {
    return env.publicUrlOverride;
  }

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

function toPostDto(row: FeedRow, origin: string) {
  const post = {
    id: Number(row.id),
    body: row.body,
    postType: row.post_type,
    createdAt: new Date(row.created_at).toISOString(),
    viewCount: row.view_count,
    bookmarkCount: row.bookmark_count,
    likeCount: Number(row.like_count),
    commentCount: Number(row.comment_count),
    likedByCurrentUser: row.liked_by_viewer,
    author: {
      id: row.author_id,
      handle: row.author_handle,
      displayName: row.author_display_name,
      role: row.author_role,
      avatarUrl: mediaUrl(origin, row.author_avatar_path),
    },
  };

  if (row.post_type === "general") {
    return { ...post, location: row.general_location };
  }

  if (row.post_type === "request") {
    return {
      ...post,
      request: { type: row.request_type, location: row.request_location },
    };
  }

  return {
    ...post,
    property: {
      id: Number(row.property_id),
      status: row.property_status,
      location: row.property_location,
      images: (row.property_images ?? []).map((image) => ({
        id: Number(image.id),
        url: mediaUrl(origin, image.storagePath),
        position: image.position,
      })),
    },
  };
}

export async function getPosts(context: Context): Promise<Response> {
  const query = context.req.query();

  // Fail closed: a removed or mistyped parameter (such as the retired
  // transactionType) must never silently return an unfiltered feed.
  for (const name of Object.keys(query)) {
    if (!ALLOWED_QUERY_PARAMS.has(name)) {
      throw validationError(`Remove the unsupported query parameter: ${name}.`);
    }
  }

  const limit = parseLimit(query.limit);
  const filters = parseFilters(query);
  const cursor = query.cursor === undefined ? null : decodeCursor(query.cursor);

  const env = readEnv();
  if (!env) {
    console.error(
      "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not configured.",
    );
    throw internalError();
  }

  const origin = publicOrigin(context, env);
  const actor = resolveRequestActor(context, env);

  const supabase = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.rpc("feed_page", {
    p_viewer_id: actor.userId,
    p_limit: limit + 1,
    p_cursor_created_at: cursor?.createdAt ?? null,
    p_cursor_id: cursor?.id ?? null,
    p_post_type: filters.postType ?? null,
    p_request_type: filters.requestType ?? null,
    p_property_status: filters.propertyStatus ?? null,
    p_location: filters.location ?? null,
  });

  if (error) {
    console.error("feed_page failed:", error.message);
    throw internalError();
  }

  const rows = (data ?? []) as FeedRow[];
  const pageRows = rows.slice(0, limit);
  const lastRow = pageRows.at(-1);
  const nextCursor = rows.length > limit && lastRow
    ? encodeCursor({
      createdAt: new Date(lastRow.created_at).toISOString(),
      id: Number(lastRow.id),
    })
    : null;

  return context.json(
    { posts: pageRows.map((row) => toPostDto(row, origin)), nextCursor },
    200,
    { "Cache-Control": "private, max-age=0" },
  );
}
