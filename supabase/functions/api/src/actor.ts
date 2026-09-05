import type { Context } from "hono";
import type { AppEnv } from "./env.ts";
import { forbiddenError, validationError } from "./errors.ts";

export const PREVIEW_ACTORS = [
  { alias: "prince", userId: "00000000-0000-0000-0000-000000000001" },
  { alias: "ayo", userId: "00000000-0000-0000-0000-000000000002" },
  { alias: "ifeoma", userId: "00000000-0000-0000-0000-000000000003" },
  { alias: "bizzaro", userId: "00000000-0000-0000-0000-000000000004" },
] as const;

export type RequestActor = {
  alias: string | null;
  userId: string;
};

export function resolveRequestActor(
  context: Context,
  env: AppEnv,
): RequestActor {
  const requestedAlias = context.req.header("x-preview-actor");
  if (requestedAlias === undefined) {
    return {
      alias: PREVIEW_ACTORS.find((actor) => actor.userId === env.currentUserId)
        ?.alias ?? null,
      userId: env.currentUserId,
    };
  }

  if (!env.previewActorsEnabled) {
    throw forbiddenError("Preview actors are not available on this server.");
  }

  const actor = PREVIEW_ACTORS.find(({ alias }) => alias === requestedAlias);
  if (!actor) {
    throw validationError("Choose a known preview actor alias.");
  }
  return actor;
}

export function availablePreviewAliases(env: AppEnv): string[] {
  return env.previewActorsEnabled
    ? PREVIEW_ACTORS.map(({ alias }) => alias)
    : [];
}
