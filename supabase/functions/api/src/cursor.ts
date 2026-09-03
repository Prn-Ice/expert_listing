import { validationError } from "./errors.ts";

const CURSOR_VERSION = 1;

export type FeedCursor = {
  createdAt: string;
  id: number;
};

// The cursor is an opaque URL-safe encoding of a versioned payload carrying
// the pagination timestamp and post ID.
export function encodeCursor(cursor: FeedCursor): string {
  const payload = JSON.stringify({
    v: CURSOR_VERSION,
    createdAt: cursor.createdAt,
    id: cursor.id,
  });

  return btoa(payload)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

// Invalid or incompatible cursors are a validation error; they must never
// silently become page one.
export function decodeCursor(raw: string): FeedCursor {
  let parsed: unknown;

  try {
    const base64 = raw.replaceAll("-", "+").replaceAll("_", "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    parsed = JSON.parse(atob(padded));
  } catch {
    throw validationError("The cursor is invalid.");
  }

  if (typeof parsed !== "object" || parsed === null) {
    throw validationError("The cursor is invalid.");
  }

  const candidate = parsed as Record<string, unknown>;
  if (candidate.v !== CURSOR_VERSION) {
    throw validationError("The cursor is invalid.");
  }

  const { createdAt, id } = candidate;
  if (typeof createdAt !== "string" || Number.isNaN(Date.parse(createdAt))) {
    throw validationError("The cursor is invalid.");
  }
  if (typeof id !== "number" || !Number.isSafeInteger(id) || id < 1) {
    throw validationError("The cursor is invalid.");
  }

  return { createdAt, id };
}
