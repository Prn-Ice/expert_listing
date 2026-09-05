import { createClient } from "@supabase/supabase-js";
import type { Context } from "hono";
import { resolveRequestActor } from "./actor.ts";
import { readEnv } from "./env.ts";
import {
  internalError,
  payloadTooLargeError,
  storageError,
  unsupportedMediaError,
  validationError,
} from "./errors.ts";
import { type FeedRow, publicOrigin, toPostDto } from "./feed.ts";

const MAX_BODY_LENGTH = 2000;
const MAX_LOCATION_LENGTH = 120;
const MAX_IMAGES = 4;
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const MAX_TOTAL_IMAGE_BYTES = 8 * 1024 * 1024;
const ALLOWED_FIELDS = new Set([
  "body",
  "postType",
  "location",
  "requestType",
  "propertyStatus",
  "images",
]);

type PostType = "general" | "request" | "property";
type RequestType = "looking_to_buy" | "looking_to_rent";
type PropertyStatus = "for_sale" | "for_rent";
type ValidatedImage = {
  bytes: Uint8Array;
  contentType: string;
  extension: string;
};

function readSingleText(form: FormData, name: string): string | null {
  const values = form.getAll(name);
  if (values.length === 0) return null;
  if (values.length !== 1 || typeof values[0] !== "string") {
    throw validationError(`Send ${name} once as text.`);
  }
  return values[0];
}

function requiredTrimmedText(
  form: FormData,
  name: string,
  maxLength: number,
): string {
  const value = readSingleText(form, name)?.trim() ?? "";
  const length = [...value].length;
  if (length < 1 || length > maxLength) {
    throw validationError(
      `Enter ${
        name === "body" ? "post text" : "a location"
      } from 1 through ${maxLength} characters.`,
    );
  }
  return value;
}

function exactChoice<T extends string>(
  value: string | null,
  values: readonly T[],
  message: string,
): T {
  if (value === null || !values.includes(value as T)) {
    throw validationError(message);
  }
  return value as T;
}

function uint32(
  bytes: Uint8Array,
  offset: number,
  littleEndian = false,
): number {
  return new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
    .getUint32(offset, littleEndian);
}

function isPng(bytes: Uint8Array): boolean {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 45 || !signature.every((value, i) => bytes[i] === value)) {
    return false;
  }
  let offset = 8;
  let sawHeader = false;
  let sawData = false;
  while (offset + 12 <= bytes.length) {
    const length = uint32(bytes, offset);
    if (length > bytes.length - offset - 12) return false;
    const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
    const dataOffset = offset + 8;
    const nextOffset = offset + 12 + length;
    if (!sawHeader) {
      if (type !== "IHDR" || length !== 13) return false;
      if (
        uint32(bytes, dataOffset) === 0 || uint32(bytes, dataOffset + 4) === 0
      ) {
        return false;
      }
      sawHeader = true;
    } else if (type === "IDAT") {
      sawData = true;
    } else if (type === "IEND") {
      return length === 0 && sawData && nextOffset === bytes.length;
    }
    offset = nextOffset;
  }
  return false;
}

function isJpeg(bytes: Uint8Array): boolean {
  if (
    bytes.length < 12 || bytes[0] !== 0xff || bytes[1] !== 0xd8 ||
    bytes.at(-2) !== 0xff || bytes.at(-1) !== 0xd9
  ) {
    return false;
  }
  let offset = 2;
  let sawFrame = false;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] !== 0xff) return false;
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xda) return sawFrame;
    if (marker === 0xd9) return false;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (offset + 2 > bytes.length) return false;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || length > bytes.length - offset) return false;
    if (
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf)
    ) {
      if (length < 7) return false;
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width === 0 || height === 0) return false;
      sawFrame = true;
    }
    offset += length;
  }
  return false;
}

function isWebp(bytes: Uint8Array): boolean {
  if (
    bytes.length < 30 || bytes[0] !== 0x52 || bytes[1] !== 0x49 ||
    bytes[2] !== 0x46 || bytes[3] !== 0x46 || bytes[8] !== 0x57 ||
    bytes[9] !== 0x45 || bytes[10] !== 0x42 || bytes[11] !== 0x50 ||
    uint32(bytes, 4, true) !== bytes.length - 8
  ) {
    return false;
  }
  const type = String.fromCharCode(...bytes.subarray(12, 16));
  const chunkLength = uint32(bytes, 16, true);
  if (chunkLength > bytes.length - 20) return false;
  return type === "VP8 " || type === "VP8L" || type === "VP8X";
}

function detectImage(bytes: Uint8Array): Omit<ValidatedImage, "bytes"> | null {
  if (isPng(bytes)) {
    return { contentType: "image/png", extension: "png" };
  }
  if (isJpeg(bytes)) {
    return { contentType: "image/jpeg", extension: "jpg" };
  }
  if (isWebp(bytes)) {
    return { contentType: "image/webp", extension: "webp" };
  }
  return null;
}

async function validateImages(
  form: FormData,
  postType: PostType,
): Promise<ValidatedImage[]> {
  const parts = form.getAll("images");
  if (postType !== "property" && parts.length > 0) {
    throw validationError("Images only apply to property posts.");
  }
  if (parts.length > MAX_IMAGES) {
    throw validationError("Add no more than four images.");
  }
  if (parts.some((part) => typeof part === "string")) {
    throw validationError("Send images as files.");
  }
  const files = parts as File[];
  if (files.some((file) => file.size > MAX_IMAGE_BYTES)) {
    throw payloadTooLargeError("Each image must be 2 MiB or smaller.");
  }
  if (
    files.reduce((total, file) => total + file.size, 0) > MAX_TOTAL_IMAGE_BYTES
  ) {
    throw payloadTooLargeError("Images must total 8 MiB or less.");
  }

  const images: ValidatedImage[] = [];
  for (const file of files) {
    const bytes = new Uint8Array(await file.arrayBuffer());
    const detected = detectImage(bytes);
    if (!detected) {
      throw unsupportedMediaError("That image format isn’t supported yet.");
    }
    images.push({ bytes, ...detected });
  }
  return images;
}

async function parseCreatePost(context: Context) {
  if (!context.req.header("content-type")?.startsWith("multipart/form-data;")) {
    throw unsupportedMediaError("Send this request as multipart form data.");
  }
  let form: FormData;
  try {
    form = await context.req.formData();
  } catch {
    throw validationError("Send valid multipart form data.");
  }
  for (const name of form.keys()) {
    if (!ALLOWED_FIELDS.has(name)) {
      throw validationError(`Remove the unsupported field: ${name}.`);
    }
  }

  const body = requiredTrimmedText(form, "body", MAX_BODY_LENGTH);
  const location = requiredTrimmedText(form, "location", MAX_LOCATION_LENGTH);
  const postType = exactChoice<PostType>(
    readSingleText(form, "postType"),
    ["general", "request", "property"],
    "Choose a valid post type.",
  );
  const requestTypeValue = readSingleText(form, "requestType");
  const propertyStatusValue = readSingleText(form, "propertyStatus");

  let requestType: RequestType | null = null;
  let propertyStatus: PropertyStatus | null = null;
  if (postType === "request") {
    if (propertyStatusValue !== null) {
      throw validationError(
        "A property status only applies to property posts.",
      );
    }
    requestType = exactChoice<RequestType>(
      requestTypeValue,
      ["looking_to_buy", "looking_to_rent"],
      "Choose a valid request type.",
    );
  } else if (postType === "property") {
    if (requestTypeValue !== null) {
      throw validationError("A request type only applies to request posts.");
    }
    propertyStatus = exactChoice<PropertyStatus>(
      propertyStatusValue,
      ["for_sale", "for_rent"],
      "Choose a valid property status.",
    );
  } else if (requestTypeValue !== null || propertyStatusValue !== null) {
    throw validationError("Subtype fields do not apply to general posts.");
  }

  const images = await validateImages(form, postType);
  return { body, location, postType, requestType, propertyStatus, images };
}

export async function createPost(context: Context): Promise<Response> {
  const input = await parseCreatePost(context);
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
  const uploadId = crypto.randomUUID();
  const uploadedPaths: string[] = [];

  try {
    for (const [position, image] of input.images.entries()) {
      const path = `properties/${uploadId}/${position}.${image.extension}`;
      const { error } = await supabase.storage.from("media").upload(
        path,
        image.bytes,
        {
          contentType: image.contentType,
          cacheControl: "31536000",
          upsert: false,
        },
      );
      if (error) {
        console.error("Property image upload failed.");
        throw storageError();
      }
      uploadedPaths.push(path);
    }

    const { data, error } = await supabase.rpc("create_hydrated_post", {
      p_author_id: actor.userId,
      p_body: input.body,
      p_post_type: input.postType,
      p_location: input.location,
      p_request_type: input.requestType,
      p_property_status: input.propertyStatus,
      p_image_paths: uploadedPaths,
    });
    if (error || !data?.[0]) {
      console.error("create_hydrated_post failed.");
      throw internalError();
    }

    return context.json(
      toPostDto(data[0] as FeedRow, publicOrigin(context, env)),
      201,
      { "Cache-Control": "no-store" },
    );
  } catch (error) {
    if (uploadedPaths.length > 0) {
      const { error: cleanupError } = await supabase.storage.from("media")
        .remove(uploadedPaths);
      if (cleanupError) console.error("Property image cleanup failed.");
    }
    throw error;
  }
}
