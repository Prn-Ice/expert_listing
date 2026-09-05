export type AppEnv = {
  supabaseUrl: string;
  serviceRoleKey: string;
  currentUserId: string;
  publicUrlOverride: string | null;
  previewActorsEnabled: boolean;
};

// The assessment user is deterministic and fixed in seed data; auth is out of
// scope. Server configuration may override it, but clients never supply one.
export const DEFAULT_CURRENT_USER_ID = "00000000-0000-0000-0000-000000000001";

/// Resolves the deliberately narrow local-only preview actor capability.
export function previewActorsAreEnabled(
  supabaseUrl: string,
  setting: string | undefined,
): boolean {
  if (setting !== "true") return false;
  try {
    return ["127.0.0.1", "localhost", "kong", "host.docker.internal"].includes(
      new URL(supabaseUrl).hostname,
    );
  } catch {
    return false;
  }
}

export function readEnv(): AppEnv | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }

  return {
    supabaseUrl,
    serviceRoleKey,
    currentUserId: Deno.env.get("CURRENT_USER_ID") ?? DEFAULT_CURRENT_USER_ID,
    previewActorsEnabled: previewActorsAreEnabled(
      supabaseUrl,
      Deno.env.get("ALLOW_PREVIEW_ACTORS"),
    ),
    // Optional ops override for the externally reachable origin used in DTO
    // media URLs. Unset locally and hosted: the request's forwarded origin is
    // used instead, because the local runtime injects the internal kong host
    // as SUPABASE_URL, which clients cannot reach. The name cannot start with
    // SUPABASE_; the runtime strips those from custom configuration.
    publicUrlOverride: Deno.env.get("PUBLIC_API_ORIGIN") ?? null,
  };
}
