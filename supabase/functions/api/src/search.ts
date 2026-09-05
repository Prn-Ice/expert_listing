import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { type AppEnv, readEnv } from "./env.ts";
import { internalError, validationError } from "./errors.ts";

const DEFAULT_LIMIT = 6;
const MAX_LIMIT = 10;
const MIN_QUERY_LENGTH = 3;
const MAX_QUERY_LENGTH = 120;
const ALLOWED_QUERY_PARAMS = new Set(["q", "limit"]);

type SearchSuggestionRow = {
  suggestion_type: "location" | "property";
  label: string;
  post_id: number | string | null;
  property_id: number | string | null;
  property_status: "for_sale" | "for_rent" | null;
  location: string;
  body: string | null;
  image_storage_path: string | null;
  matching_property_count: number | string | null;
};

function parseLimit(raw: string | undefined): number {
  if (raw === undefined) return DEFAULT_LIMIT;
  if (!/^\d+$/.test(raw)) {
    throw validationError("Choose a suggestion limit from 1 through 10.");
  }

  const limit = Number(raw);
  if (limit < 1 || limit > MAX_LIMIT) {
    throw validationError("Choose a suggestion limit from 1 through 10.");
  }
  return limit;
}

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

function mediaUrl(origin: string, path: string | null): string | null {
  return path ? `${origin}/storage/v1/object/public/media/${path}` : null;
}

export async function getSearchSuggestions(
  context: Context,
): Promise<Response> {
  const query = context.req.query();
  for (const name of Object.keys(query)) {
    if (!ALLOWED_QUERY_PARAMS.has(name)) {
      throw validationError(`Remove the unsupported query parameter: ${name}.`);
    }
  }

  const value = query.q?.trim() ?? "";
  if (value.length < MIN_QUERY_LENGTH || value.length > MAX_QUERY_LENGTH) {
    throw validationError("Enter 3 through 120 characters to search.");
  }
  const limit = parseLimit(query.limit);

  const env = readEnv();
  if (!env) {
    console.error(
      "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not configured.",
    );
    throw internalError();
  }

  const supabase = createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc("property_search_suggestions", {
    p_query: value,
    p_limit: limit,
  });
  if (error) {
    console.error("property_search_suggestions failed:", error.message);
    throw internalError();
  }

  const origin = publicOrigin(context, env);
  const suggestions = ((data ?? []) as SearchSuggestionRow[]).map((row) => {
    if (row.suggestion_type === "location") {
      return {
        type: "location",
        label: row.label,
        propertyCount: Number(row.matching_property_count),
      };
    }

    return {
      type: "property",
      postId: Number(row.post_id),
      propertyId: Number(row.property_id),
      status: row.property_status,
      location: row.location,
      summary: row.body,
      imageUrl: mediaUrl(origin, row.image_storage_path),
    };
  });

  return context.json(
    { suggestions },
    200,
    { "Cache-Control": "private, max-age=0" },
  );
}
