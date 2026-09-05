import type { Context } from "hono";
import { ApiError, validationError } from "./errors.ts";

export function parsePostId(value: string | undefined): number {
  if (value === undefined || !/^\d+$/.test(value)) {
    throw validationError("Choose a valid post.");
  }
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id < 1) {
    throw validationError("Choose a valid post.");
  }
  return id;
}

export async function readJsonObject(
  context: Context,
): Promise<Record<string, unknown>> {
  if (
    context.req.header("content-type")?.split(";", 1)[0] !== "application/json"
  ) {
    throw new ApiError(
      415,
      "UNSUPPORTED_MEDIA_TYPE",
      "Send this request as JSON.",
    );
  }
  try {
    const body: unknown = await context.req.json();
    if (body === null || Array.isArray(body) || typeof body !== "object") {
      throw validationError("Send a valid JSON object.");
    }
    return body as Record<string, unknown>;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw validationError("Send a valid JSON object.");
  }
}

export function requireExactFields(
  body: Record<string, unknown>,
  fields: string[],
): void {
  const names = Object.keys(body);
  if (
    names.length !== fields.length ||
    fields.some((field) => !Object.hasOwn(body, field))
  ) {
    throw validationError(`Send only: ${fields.join(", ")}.`);
  }
}
