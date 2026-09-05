import { createClient } from "@supabase/supabase-js";
import { app } from "../src/app.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} must be set for create-post tests.`);
  return value;
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const dbUrl = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:56322/postgres";
const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

type ApiResult = {
  status: number;
  headers: Headers;
  // deno-lint-ignore no-explicit-any
  body: any;
  rawBody: string;
};

async function api(
  body: BodyInit | null,
  headers?: HeadersInit,
): Promise<ApiResult> {
  const response = await app.request("http://127.0.0.1:56321/api/posts", {
    method: "POST",
    body,
    headers,
  });
  const rawBody = await response.text();
  let parsed = null;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    // Assertions below include the raw response when JSON is malformed.
  }
  return {
    status: response.status,
    headers: response.headers,
    body: parsed,
    rawBody,
  };
}

async function psql(sql: string): Promise<string> {
  const command = new Deno.Command("psql", {
    args: [dbUrl, "--no-psqlrc", "-v", "ON_ERROR_STOP=1", "-tA", "-c", sql],
    clearEnv: true,
    stdout: "piped",
    stderr: "piped",
  });
  const output = await command.output();
  if (!output.success) {
    throw new Error(`psql failed: ${new TextDecoder().decode(output.stderr)}`);
  }
  return new TextDecoder().decode(output.stdout).trim();
}

function validPng(): Uint8Array {
  const raw = atob(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
  );
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

function imageFile(
  bytes: Uint8Array,
  name: string,
  type = "application/octet-stream",
): File {
  return new File([bytes.buffer as ArrayBuffer], name, { type });
}

function baseForm(postType: string): FormData {
  const form = new FormData();
  form.set("body", `Create post API ${postType} probe`);
  form.set("postType", postType);
  form.set("location", "Yaba, Lagos");
  return form;
}

function storagePath(url: string): string {
  const marker = "/storage/v1/object/public/media/";
  const index = url.indexOf(marker);
  if (index < 0) throw new Error(`Unexpected media URL: ${url}`);
  return url.slice(index + marker.length);
}

async function removePost(postId: number, paths: string[] = []): Promise<void> {
  if (paths.length > 0) {
    const { error } = await serviceClient.storage.from("media").remove(paths);
    if (error) throw new Error(`Storage cleanup failed: ${error.message}`);
  }
  await psql(`
    do $$
    declare
      v_request_id bigint;
      v_property_id bigint;
    begin
      select property_request_id, posts.property_id
      into v_request_id, v_property_id
      from public.posts where id = ${postId};
      delete from public.posts where id = ${postId};
      delete from public.property_requests where id = v_request_id;
      delete from public.properties where id = v_property_id;
    end $$;
  `);
}

function assertError(result: ApiResult, status: number, code: string): void {
  if (result.status !== status || result.body?.error?.code !== code) {
    throw new Error(
      `Expected ${status} ${code}, received ${result.status}: ${result.rawBody}`,
    );
  }
  if (result.headers.get("cache-control") !== "no-store") {
    throw new Error("Errors must not be cacheable.");
  }
}

Deno.test("POST /api/posts creates and hydrates every post variant", async () => {
  const created: number[] = [];
  try {
    const general = await api(baseForm("general"));
    if (general.status !== 201 || general.body?.location !== "Yaba, Lagos") {
      throw new Error(`General creation failed: ${general.rawBody}`);
    }
    created.push(general.body.id);

    const requestForm = baseForm("request");
    requestForm.set("requestType", "looking_to_rent");
    const request = await api(requestForm);
    if (
      request.status !== 201 ||
      request.body?.request?.type !== "looking_to_rent" ||
      request.body?.request?.location !== "Yaba, Lagos"
    ) {
      throw new Error(`Request creation failed: ${request.rawBody}`);
    }
    created.push(request.body.id);

    const propertyForm = baseForm("property");
    propertyForm.set("propertyStatus", "for_sale");
    const property = await api(propertyForm);
    if (
      property.status !== 201 ||
      property.body?.property?.status !== "for_sale" ||
      property.body?.property?.images?.length !== 0
    ) {
      throw new Error(`Property creation failed: ${property.rawBody}`);
    }
    created.push(property.body.id);

    for (const result of [general, request, property]) {
      if (
        result.headers.get("cache-control") !== "no-store" ||
        result.body?.author?.handle !== "prince" ||
        result.body?.likeCount !== 0 || result.body?.commentCount !== 0
      ) {
        throw new Error(`Unexpected hydrated post: ${result.rawBody}`);
      }
    }
  } finally {
    for (const id of created) await removePost(id);
  }
});

Deno.test("POST /api/posts preserves ordered verified property images", async () => {
  const form = baseForm("property");
  form.set("propertyStatus", "for_rent");
  form.append(
    "images",
    imageFile(validPng(), "first.jpg", "image/jpeg"),
  );
  form.append(
    "images",
    imageFile(validPng(), "second.bin", "text/plain"),
  );

  const result = await api(form);
  if (result.status !== 201) {
    throw new Error(
      `Expected 201, received ${result.status}: ${result.rawBody}`,
    );
  }
  const images = result.body?.property?.images;
  if (
    images?.length !== 2 || images[0].position !== 0 || images[1].position !== 1
  ) {
    throw new Error(`Image order was not retained: ${result.rawBody}`);
  }
  const paths = images.map((image: { url: string }) => storagePath(image.url));

  try {
    for (const [index, path] of paths.entries()) {
      if (!path.endsWith(`/${index}.png`)) {
        throw new Error(`Detected media extension was not used: ${path}`);
      }
      const { data, error } = await serviceClient.storage.from("media")
        .download(path);
      if (error || !data) {
        throw new Error(`Uploaded image unavailable: ${path}`);
      }
      const bytes = new Uint8Array(await data.arrayBuffer());
      const expected = validPng();
      if (
        bytes.length !== expected.length ||
        bytes.some((value, byteIndex) => value !== expected[byteIndex])
      ) {
        throw new Error("Uploaded bytes changed.");
      }
    }
  } finally {
    await removePost(result.body.id, paths);
  }
});

Deno.test("POST /api/posts rejects invalid multipart fields and media", async () => {
  assertError(
    await api("{}", { "content-type": "application/json" }),
    415,
    "UNSUPPORTED_MEDIA_TYPE",
  );

  const unknown = baseForm("general");
  unknown.set("authorId", "00000000-0000-0000-0000-000000000001");
  assertError(await api(unknown), 400, "VALIDATION_ERROR");

  const duplicate = baseForm("general");
  duplicate.append("body", "second body");
  assertError(await api(duplicate), 400, "VALIDATION_ERROR");

  const generalImage = baseForm("general");
  generalImage.set("images", imageFile(validPng(), "image.png"));
  assertError(await api(generalImage), 400, "VALIDATION_ERROR");

  const missingRequestType = baseForm("request");
  assertError(await api(missingRequestType), 400, "VALIDATION_ERROR");

  const mixedProperty = baseForm("property");
  mixedProperty.set("propertyStatus", "for_sale");
  mixedProperty.set("requestType", "looking_to_buy");
  assertError(await api(mixedProperty), 400, "VALIDATION_ERROR");

  const fiveImages = baseForm("property");
  fiveImages.set("propertyStatus", "for_sale");
  for (let index = 0; index < 5; index++) {
    fiveImages.append("images", imageFile(validPng(), `${index}.png`));
  }
  assertError(await api(fiveImages), 400, "VALIDATION_ERROR");

  const overlongBody = baseForm("general");
  overlongBody.set("body", "x".repeat(2001));
  assertError(await api(overlongBody), 400, "VALIDATION_ERROR");

  const unsupported = baseForm("property");
  unsupported.set("propertyStatus", "for_sale");
  unsupported.set(
    "images",
    new File([new Uint8Array(24)], "fake.png", { type: "image/png" }),
  );
  assertError(await api(unsupported), 415, "UNSUPPORTED_MEDIA_TYPE");

  const oversized = baseForm("property");
  oversized.set("propertyStatus", "for_sale");
  oversized.set(
    "images",
    new File([new Uint8Array(2 * 1024 * 1024 + 1)], "large.png"),
  );
  assertError(await api(oversized), 413, "PAYLOAD_TOO_LARGE");
});

Deno.test("POST /api/posts removes uploaded objects after database failure", async () => {
  const before = await psql(
    "select name from storage.objects where bucket_id = 'media' and name like 'properties/%/%' order by name;",
  );
  const beforePaths = new Set(before === "" ? [] : before.split("\n"));
  await psql(`
    create function public.reject_create_post_probe() returns trigger
    language plpgsql as $$ begin
      if new.body = 'Create post database failure probe' then
        raise exception 'deliberate test failure';
      end if;
      return new;
    end $$;
    create trigger reject_create_post_probe before insert on public.posts
    for each row execute function public.reject_create_post_probe();
  `);
  try {
    const form = baseForm("property");
    form.set("body", "Create post database failure probe");
    form.set("propertyStatus", "for_sale");
    form.set("images", imageFile(validPng(), "probe.png"));
    assertError(await api(form), 500, "INTERNAL_ERROR");

    const after = await psql(
      "select name from storage.objects where bucket_id = 'media' and name like 'properties/%/%' order by name;",
    );
    if (after !== before) {
      throw new Error(
        `Expected exact Storage compensation. Before: ${before}; after: ${after}.`,
      );
    }
    const posts = await psql(
      "select count(*) from public.posts where body = 'Create post database failure probe';",
    );
    if (posts !== "0") {
      throw new Error("Failed database mutation persisted a post.");
    }
  } finally {
    const remaining = await psql(
      "select name from storage.objects where bucket_id = 'media' and name like 'properties/%/%' order by name;",
    );
    const leaked = (remaining === "" ? [] : remaining.split("\n"))
      .filter((path) => !beforePaths.has(path));
    if (leaked.length > 0) {
      await serviceClient.storage.from("media").remove(leaked);
    }
    await psql(`
      drop trigger if exists reject_create_post_probe on public.posts;
      drop function if exists public.reject_create_post_probe();
    `);
  }
});
