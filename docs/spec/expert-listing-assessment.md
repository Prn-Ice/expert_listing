# Expert Listing Assessment Specification

- **Status:** Canonical implementation contract
- **Owner:** Prince
- **Assessment received:** Evening of Wednesday, 2 September 2026, West Africa
  Time
- **Employer deadline:** Evening of Saturday, 5 September 2026, West Africa Time
- **Internal release-candidate target:** 12:00 WAT, Saturday, 5 September 2026
- **Internal submission target:** 17:00 WAT, Saturday, 5 September 2026
- **Primary Figma frame:** `[private design node removed]`, “iPhone 14 Plus - 1312”, 428 logical
  pixels wide
- **Figma source:**
  <https://www.figma.com/design/[private design file removed]/ExpertListing-Assessment--Copy-?node-id=[private design node removed]>

This file defines the required product behaviour and engineering scope. Beads
records live work and evidence; the wiki records durable decisions and
workflows. Neither may silently redefine this contract.

## 1. Authority and precedence

When instructions disagree, use this order:

1. Prince’s current direct instruction.
2. This canonical specification.
3. The committed Figma-derived design contract, assets, measurements, and provenance for details represented in Figma.
4. SQL migrations and the published HTTP contract for executable backend behaviour.
5. Committed lockfiles for installed versions.
6. Beads for implementation status, dependencies, risks, and command evidence.
7. `docs/wiki/` for explanations and reproducible workflows.
8. Generic templates, skills, package examples, and framework recommendations.

Generic guidance applies only where it is compatible with this specification. It must not introduce unrequested architecture, packages, testing obligations, or scope.

Use Figma context when exact design measurements, variables, screenshots, or
exports are required.

## 2. Governing delivery rule

> A working, installable, polished core journey outranks another feature, abstraction, test count, or document.

Build the smallest complete product that satisfies this specification. The result must be easy to understand, easy to run, faithful to the design, pleasant to use, and honest about its boundaries.

Dark mode is required in P0 even though the supplied Figma frame represents light mode.

Do not start post-release roadmap work before the required `v0.1.0` release is published and independently verified.

## 3. Assessment brief

Build the core Expert Listing mobile experience in Flutter:

- feed;
- stories;
- filters;
- create-post field;
- post cards;
- likes;
- comments;
- sharing;
- bookmarks;
- general, request, and property post creation with their owned locations and property images.

Likes, viewing and adding comments, and filters must work rather than merely appear interactive.

The required backend surface is:

- `GET /posts`;
- `POST /posts`;
- `POST /posts/:id/like`;
- `GET /posts/:id/comments`;
- `POST /posts/:id/comments`;
- Supabase Postgres relational storage;
- direct Flutter-to-Hono API use for the feed and interactions;
- basic, useful error handling.

The original assessment explicitly requires relational Users, Posts, Comments, and Likes. This implementation also includes property requests, properties, and `property_images`, because requests and properties own different data and only properties can own ordered images.

The current user is deterministic and selected on the server. Full authentication is outside scope.

## 4. Required submission package

The finished submission must provide:

- a cloneable GitHub repository;
- a hosted Supabase backend;
- an installable signed Android APK on GitHub Releases;
- `SHA256SUMS.txt`;
- a concise assessor-first README;
- screenshots or a screen recording;
- a short walkthrough video;
- local run instructions;
- documented API endpoints and schema;
- documented assumptions, trade-offs, limitations, and skipped work.

The walkthrough video is mandatory. It must briefly explain:

- what was completed;
- the implementation approach;
- important decisions;
- assumptions;
- trade-offs;
- how the main journeys were verified.

Product video-post support is unrelated to the walkthrough and remains deferred.

Prince owns the final submission. The project must prepare a ready-to-send set of verified links and evidence.

## 5. Product goal

A reviewer must be able to:

1. launch the app and immediately understand its state;
2. browse a real feed;
3. pull to refresh;
4. apply and clear filters;
5. load additional pages;
6. create a general, request, or property post with its applicable location and property images;
7. like a post;
8. view and add comments;
9. refresh or relaunch and confirm server-backed changes persisted;
10. share a truthful text representation through the native share sheet;
11. save a bookmark locally and retain it across launches;
12. open post imagery;
13. interact with every visible control or receive a short, useful scope notice;
14. lose connectivity and see an explicitly labelled saved feed;
15. use both light and dark system appearances;
16. install the release APK without assembling the project.

### Request-location assumption

For a request post, location means the area where the author wants to buy or
rent, not the author's or device's location. The supplied Figma example is
ambiguous because its request text and location label name different areas.
Implement the desired-property-area meaning without blocking delivery, and ask
Expert Listing to confirm it. Record any reply and revise this contract before
release if their intended meaning differs.

## 6. Scope

### Required P0 work

In addition to the required user journeys, P0 includes:

- a hosted Hono, PostgreSQL, and Storage vertical slice with deterministic data;
- network-first reads with an honest saved-feed fallback;
- exact Figma assets, light-mode fidelity, and intentional dark mode;
- complete interaction outcomes, accessibility, and native platform behaviour;
- launcher icons, native splash, and named-device performance evidence;
- valuable tests across real database, API, Storage, cache, and mobile boundaries;
- reproducible local development with Nix and OrbStack on macOS;
- hosted verification, assessor documentation, walkthrough, signed APK,
  checksum, and GitHub Release.

### Explicitly out of scope

Do not implement:

- full authentication or login;
- email verification;
- payments;
- production Redis or CDN infrastructure;
- maps, GPS, or geocoding;
- threaded comments;
- server-synchronized bookmarks;
- full story viewing or creation;
- real search;
- messages;
- notifications;
- profiles;
- TestFlight or App Store publication;
- tablet or desktop layouts.

Out-of-scope controls still require a useful response.

## 7. Simplicity and readability

Simplicity is a correctness requirement.

Code should read in product language: load posts, show saved posts, apply a
filter, create a post, like it, and add a comment. The main sequence should be
understandable without framework-specific terminology.

Use this decision order:

1. Start with the plain language or platform construct that directly states the behaviour: `if`, `for`, `switch`, a small named function, a standard Flutter control, or an ordinary typed value.
2. Prefer visible sequential flow over generic pipelines, compressed expressions, metaprogramming, or clever extensions.
3. Reuse an existing `app_ui` component when it preserves a repeated visual,
   semantic, or interaction contract.
4. Introduce an abstraction only when it:
   - centralizes a repeated contract;
   - contains a meaningful business rule; or
   - isolates an external boundary;
   and makes its callers easier to read.
5. Reject an abstraction when it adds more concepts than it removes, hides operation order, requires a long explanation, or exists only for imagined future reuse.
6. Preserve appropriate algorithms, lazy rendering, bounded work, and image handling. When measured performance requires less-obvious code, isolate it behind a plainly named interface and preserve the evidence.

Concrete defaults:

- a clear loop beats a clever transformation chain;
- a small explicit Hono handler beats a generic CRUD framework;
- a themed `IconButton`, `FilledButton`, or equivalent semantic control beats a `Container` plus `GestureDetector`;
- one concrete feature repository beats an interface and base class invented for template symmetry;
- three clear repeated lines are acceptable when extracting them would hide meaning;
- duplicated behaviour or design contracts should be centralized.

Do not add:

- generic base repositories;
- universal async-state wrappers;
- controller layers;
- an ORM;
- a service locator;
- speculative domain-model duplication;
- package-per-layer clean-architecture ceremony;
- code generation that does not materially simplify this assessment.

## 8. Approved architecture

```text
Flutter widget
  -> Riverbloc provider
  -> FeedBloc / CommentsCubit / CreatePostCubit
  -> feature repository
  -> Dio API client and explicit read-cache boundary
  -> Hono routes in one Supabase Edge Function
  -> direct database or Storage operation
  -> Supabase Postgres and Storage
```

The design is feature-first and unidirectional.

### Flutter responsibilities

- Riverpod owns configuration and dependency lifecycles.
- Bloc and Cubit own feature behaviour.
- Riverbloc connects Riverpod lifecycle ownership to Bloc/Cubit.
- Widgets render state and translate user actions into events.
- Repositories reconcile remote and cached sources.
- API clients handle HTTP serialization and transport.
- `app_ui` owns genuinely repeated visual and interaction contracts.

Do not add `flutter_bloc`. Do not represent the same request state in both Riverpod and Bloc.

Use handwritten providers unless current stable APIs demonstrate that generation would make this project materially simpler.

### Feature boundaries

#### FeedBloc

Use an event-based Bloc because feed operations can overlap and their ordering matters.

It owns:

- initial load;
- pull-to-refresh;
- next-page loading;
- filter changes;
- cursor reset;
- superseding stale filter requests;
- optimistic desired-state likes and reconciliation;
- newly created post insertion;
- local bookmark overlays;
- session hide and undo.

Required concurrency behaviour:

- an old response cannot replace results for a newer filter;
- repeated next-page events cannot issue duplicate concurrent fetches;
- rapid like changes converge on the latest desired state;
- refreshes and insertions preserve stable feed identity and scroll behaviour.

#### CommentsCubit

Use an auto-disposed Riverbloc provider family keyed by post ID.

It owns:

- loading a flat comment list;
- retaining the current input;
- submitting a comment;
- reconciling success and failure;
- preserving the input after recoverable failure.

It does not own sheet layout.

#### CreatePostCubit

Use an auto-disposed provider for one create-post flow.

It owns:

- body text;
- location;
- post type and its applicable request type or property status;
- zero to four ordered property images;
- image removal;
- upload progress;
- submission;
- draft retention after recoverable failure.

The feature name is `create_post`.

The feed entry control is `CreatePostPrompt`. The opened surface is `CreatePostSheet`.

### Riverbloc lifecycle proof

Every Riverbloc or Riverpod upgrade must run a provider lifecycle smoke test that:

1. creates a provider container;
2. reads the Bloc or Cubit;
3. causes it to emit state;
4. disposes the provider scope;
5. proves the Bloc or Cubit closes exactly once.

## 9. Dependency contract

Resolve versions from current primary sources and this project’s actual compatibility graph.

At setup or upgrade time:

1. identify the latest official stable Flutter SDK;
2. use Context7 and official release/package sources for current APIs;
3. select current stable direct dependencies;
4. let Pub and Deno resolve the newest mutually compatible stable graph;
5. choose the newest compatible stable version when the absolute newest versions conflict;
6. document any compatibility concession;
7. reject prereleases by default;
8. do not use an undocumented `dependency_overrides` escape hatch;
9. run dependency inspection, analysis, tests, provider wiring, and a release APK probe;
10. commit and enforce all lockfiles;
11. freeze the proven graph during the assessment unless a blocker, incompatibility, or material security issue requires a reviewed change.

Expected capabilities include:

- Riverbloc;
- Flutter Riverpod;
- Bloc and Bloc testing utilities;
- Dio;
- a maintained Dio cache interceptor and durable file store;
- path-provider support;
- cached network images and a maintained mobile cache manager;
- SVG rendering;
- native image picking;
- native sharing;
- a small maintained preference store for bookmarks;
- simple immutable equality;
- strict Very Good Analysis rules;
- native splash and launcher-icon generation;
- Hono;
- the Supabase JavaScript client for Deno.

Do not add routing, connectivity, animation, local-database, dependency-injection, code-generation, form-validation, or other packages merely because a template recommends them. Add one only when a verified requirement becomes simpler and clearer with it.

## 10. Backend architecture

Use one Supabase Edge Function named `api`, running on Deno with Hono as a thin router.

Hono is not the hosting provider. Supabase hosts the function; Hono maps Web `Request` objects to Web `Response` objects and provides readable routing, small middleware, centralized error handling, and direct request-level testing.

Do not add controllers, an ORM, a DI container, or framework-specific entity layers.

The deployed base URL ends with:

```text
/functions/v1/api
```

Flutter treats that full value as `API_BASE_URL`, so application requests remain paths such as `GET /posts`.

`AppConfig` reads the public URL using `String.fromEnvironment`. No dotenv file is bundled into Flutter.

A missing development value displays a clear configuration error. Release preflight rejects:

- a missing value;
- loopback or localhost;
- reserved `.invalid` and example hosts;
- non-HTTPS URLs;
- a URL outside the confirmed Supabase project;
- a path that does not end in `/functions/v1/api`.

Supabase includes the function-name segment in the incoming URL. Configure Hono with the `/api` base path and child routes such as `/health` and `/posts`. Direct Hono tests must exercise the real `/api/...` prefix.

The assessment API is public because authentication is out of scope. Disable JWT verification for this function through checked-in Supabase configuration and document that production authentication must be revisited.

Only the Edge Function receives the service credential. It resolves the deterministic current user itself. It must never trust a client-supplied user ID.

Flutter:

- never imports a Supabase client;
- never reads or writes database tables directly;
- never constructs Storage paths;
- never writes Storage objects directly;
- never contains a service-role credential;
- fetches media bytes only from public URLs returned by Hono DTOs.

## 11. Relational schema

Use lowercase snake-case identifiers, `timestamptz`, database constraints, and
indexed foreign keys. Users use UUIDs; posts, property requests, properties,
comments, and images use generated integer IDs.

### `users`

| Column | Contract |
|---|---|
| `id` | `uuid primary key` |
| `handle` | `text not null unique` |
| `display_name` | `text not null` |
| `role` | `text not null` |
| `avatar_path` | nullable `text` |
| `created_at` | `timestamptz not null default now()` |

### `posts`

| Column | Contract |
|---|---|
| `id` | `bigint generated always as identity primary key` |
| `author_id` | `uuid not null references users(id)` |
| `body` | trimmed length from 1 through 2000 |
| `post_type` | required `general`, `request`, or `property` enum value |
| `location` | nullable; trimmed length from 1 through 120; only general posts use it |
| `property_request_id` | nullable unique foreign key to `property_requests` |
| `property_id` | nullable unique foreign key to `properties` |
| `view_count` | non-negative integer, default 0 |
| `bookmark_count` | non-negative integer, default 0 |
| `created_at` | `timestamptz not null default now()` |

The post variant check is mandatory:

- `general` has its own location and no subtype reference;
- `request` has a `property_request_id`, no post location, and no property reference;
- `property` has a `property_id`, no post location, and no request reference.

`created_at` is immutable because it participates in the pagination key.

### `property_requests`

| Column | Contract |
|---|---|
| `id` | `bigint generated always as identity primary key` |
| `request_type` | required `looking_to_buy` or `looking_to_rent` enum value |
| `location` | required desired-area location, trimmed length from 1 through 120 |
| `created_at` | `timestamptz not null default now()` |

### `properties`

| Column | Contract |
|---|---|
| `id` | `bigint generated always as identity primary key` |
| `property_status` | required `for_sale` or `for_rent` enum value |
| `location` | required physical location, trimmed length from 1 through 120 |
| `created_at` | `timestamptz not null default now()` |

### `property_images`

| Column | Contract |
|---|---|
| `id` | `bigint generated always as identity primary key` |
| `property_id` | references `properties(id)` with cascade delete |
| `storage_path` | `text not null unique` |
| `position` | integer from 0 through 3 |
| `created_at` | `timestamptz not null default now()` |

`(property_id, position)` is unique. General and request posts cannot have images;
properties may have zero through four ordered images.

### `comments`

| Column | Contract |
|---|---|
| `id` | `bigint generated always as identity primary key` |
| `post_id` | references `posts(id)` with cascade delete |
| `author_id` | references `users(id)` |
| `body` | trimmed length from 1 through 1000 |
| `created_at` | `timestamptz not null default now()` |

### `likes`

| Column | Contract |
|---|---|
| `post_id` | references `posts(id)` with cascade delete |
| `user_id` | references `users(id)` with cascade delete |
| `created_at` | `timestamptz not null default now()` |

The primary key is `(post_id, user_id)`.

Likes set a desired state:

- `liked: true` uses an atomic upsert;
- `liked: false` uses a delete.

Never use a blind toggle or select-then-insert race.

### Indexes and query behaviour

Enable `pg_trgm`.

Indexes must support:

- posts by `(created_at desc, id desc)`;
- posts filtered by `(post_type, created_at desc, id desc)`;
- request-type and property-status filtering;
- case-insensitive substring search across the applicable general-post, request,
  and property location columns with `pg_trgm` GIN indexes;
- comments by `(post_id, created_at, id)`;
- images by `(property_id, position)`;
- every foreign key not already covered by a leading primary or unique key.

Do not issue one database request per post when hydrating authors, images, counts, and current-user like state. Use one relational query/RPC or a fixed number of batched queries.

### Row-level security and Storage

Enable RLS on exposed tables with no anonymous write policies.

The Edge Function accesses the database using its server-only service credential.

The `media` bucket is:

- public-read;
- server-write;
- limited to JPEG, PNG, and WebP;
- limited to 2 MiB per stored object;
- configured declaratively in `supabase/config.toml`.

Do not create bucket configuration through dashboard-only steps or direct writes to Supabase-managed Storage tables.

Hono converts stored paths to environment-correct public URLs. Flutter never derives them.

### Atomic post creation

Upload property images to unique property-oriented paths.

Use one service-only, security-definer `create_post` RPC transaction. It creates a
general post directly, a property request and its request post, or a property,
its property post, and ordered `property_images`. Revoke execution from
`PUBLIC`, `anon`, and `authenticated`; grant it only to `service_role`.

The database surface reachable by API roles is vetted security-definer
functions only; tables grant no privileges to `anon`, `authenticated`, or
`service_role`. Each such function pins `search_path` to `public`.

If a database insert fails:

- the post, subtype row, and image metadata rows roll back;
- the server attempts to remove only the newly uploaded Storage objects;
- cleanup is best-effort;
- the API returns an honest server error.

## 12. Deterministic data

Seed:

- fixed user UUIDs;
- varied authors and roles;
- all post types, request types, and property statuses;
- Lagos locations;
- deliberately tied timestamps;
- properties with zero, one, and multiple images;
- general, request, and property posts;
- posts with and without engagement;
- ordered property images;
- comments;
- likes;
- enough rows to cross at least three small test pages.

Serialize `postType` and its matching discriminated payload. Dart uses simple
sealed or discriminated models so a general post cannot be mistaken for a
property.

The current-user UUID is fixed in server configuration and seed data. Flutter does not submit a pretend `userId`.

Seed operations must be safe to repeat against the dedicated assessment project:

- use fixed fixture IDs;
- use `OVERRIDING SYSTEM VALUE` where required;
- update only known fixture rows on conflict;
- advance identity sequences beyond the greatest existing ID;
- never delete reviewer-created or unrelated rows.

Commit deterministic avatars and property images under `supabase/seed_media/`.

## 13. Cursor pagination

Sort posts by:

```sql
order by created_at desc, id desc
```

For a later page:

```sql
where (created_at, id) < (:cursor_created_at, :cursor_id)
order by created_at desc, id desc
limit :limit_plus_one
```

Fetch `limit + 1`, return at most `limit`, and create `nextCursor` only when the extra row exists.

The cursor is an opaque URL-safe encoding of a versioned payload containing:

- timestamp;
- post ID.

Invalid or incompatible cursors return a validation error. They must not silently become page one.

Limits:

- default: 10;
- maximum: 20.

Tests must cover:

- equal timestamps at a page boundary;
- a new post inserted between page requests;
- no duplicate;
- no skipped row from the original sequence.

## 14. Filters

The approved filter sheet contains:

- one optional post-type choice;
- a request-type choice when filtering requests;
- a property-status choice when filtering properties;
- one optional location query;
- `Clear`;
- `Apply`;
- a subtle active-filter count on the closed filter control.

Filtering is server-side.

Location matching searches the selected variant's owned location. Without a post
type it searches general post, request, and property locations. It:

- trims input;
- is case-insensitive;
- uses literal substring matching;
- escapes `%`, `_`, and the escape character;
- uses a parameterized query;
- is supported by the `pg_trgm` index;
- does not use maps, GPS, or geocoding.

Applying or clearing filters resets pagination and replaces the existing result. A response for an older filter cannot replace the current filter’s result.

## 15. HTTP contract

Successful JSON uses camelCase. Dates use UTC ISO-8601 strings. User IDs are
UUID strings; post, comment, and image IDs are JSON numbers.

### Cache headers

- Successful `GET /posts`: `Cache-Control: private, max-age=0`.
- Mutations: `Cache-Control: no-store`.
- Errors: `Cache-Control: no-store`.

The selected Dio cache implementation must be verified against these headers and the explicit repository fallback behaviour.

### `GET /health`

Response `200`:

```json
{"status":"ok"}
```

### `GET /posts`

Optional query parameters:

| Parameter | Contract |
|---|---|
| `limit` | integer from 1 through 20 |
| `cursor` | opaque cursor |
| `postType` | `general`, `request`, or `property` |
| `requestType` | approved request enum; valid only with `postType=request` |
| `propertyStatus` | approved property enum; valid only with `postType=property` |
| `location` | trimmed string from 1 through 120 characters |

Response `200`:

```json
{
  "posts": [
    {
      "id": 42,
      "body": "Newly serviced 3-bedroom apartment with a bright living room and secure parking.",
      "postType": "property",
      "createdAt": "2026-09-02T08:00:00.000Z",
      "viewCount": 1000,
      "bookmarkCount": 2,
      "likeCount": 23,
      "commentCount": 4,
      "likedByCurrentUser": false,
      "author": {
        "id": "11111111-1111-4111-8111-111111111111",
        "handle": "boyd.from",
        "displayName": "Boyd From",
        "role": "Developer",
        "avatarUrl": "https://assets.example.invalid/avatars/boyd-from.webp"
      },
      "property": {
        "id": 7,
        "status": "for_rent",
        "location": "Lekki Phase 1, Lagos",
        "images": [
          {
            "id": 7,
            "url": "https://assets.example.invalid/properties/7/front.webp",
            "position": 0
          }
        ]
      }
    }
  ],
  "nextCursor": null
}
```

Feed items are discriminated:

- a general item has `postType: "general"` and `location`;
- a request item has `postType: "request"` and `request { type, location }`;
- a property item has `postType: "property"` and `property { id, status, location, images }`.

The legacy combined subtype field is absent. Property image positions are stable and ordered.

The final page uses JSON null, never a string sentinel.

### `POST /posts`

Use `multipart/form-data`.

Fields:

- `body`: trimmed, 1 through 2000 characters;
- `postType`: required `general`, `request`, or `property`;
- `location`: required, trimmed 1 through 120 characters; it is the general
  location, desired request area, or physical property location by variant;
- `requestType`: required only for requests;
- `propertyStatus`: required only for properties;
- repeated `images` fields in display order, permitted only for properties.

Properties accept zero through four JPEG, PNG, or WebP images. The required integration journey must exercise multiple images.

Client constraints before upload:

- longest edge no greater than 2048 pixels;
- each image no greater than 2 MiB.

Server constraints:

- no images for general or request posts and at most four property images;
- no request fields on general or property posts, and no property fields on general or request posts;
- at most 8 MiB across all image parts;
- actual media type and bytes verified;
- client filename and MIME headers are not trusted.

Unsupported local image formats retain the draft and show:

```text
That image format isn’t supported yet.
```

Return the complete hydrated post with `201`. Flutter inserts that returned post without refreshing the entire feed.

### `POST /posts/:id/like`

Request:

```json
{"liked":true}
```

Response `200`:

```json
{"postId":42,"liked":true,"likeCount":24}
```

Repeated identical requests have the same effect.

### `GET /posts/:id/comments`

Return a flat list ordered oldest to newest:

```json
{
  "comments": [
    {
      "id": 9,
      "postId": 42,
      "body": "Is inspection still open?",
      "createdAt": "2026-09-02T08:15:00.000Z",
      "author": {
        "id": "11111111-1111-4111-8111-111111111111",
        "handle": "prince",
        "displayName": "Prince",
        "role": "Buyer",
        "avatarUrl": "https://assets.example.invalid/avatars/prince.webp"
      }
    }
  ]
}
```

### `POST /posts/:id/comments`

Request:

```json
{"body":"Is inspection still open?"}
```

Trim the body and require 1 through 1000 characters. Return the hydrated comment with `201`.

### Errors

Use correct HTTP status codes and one stable envelope:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Choose a valid post type."
  }
}
```

Stable codes:

- `VALIDATION_ERROR`;
- `NOT_FOUND`;
- `STORAGE_ERROR`;
- `INTERNAL_ERROR`;
- `PAYLOAD_TOO_LARGE`, HTTP 413;
- `UNSUPPORTED_MEDIA_TYPE`, HTTP 415.

Never expose stack traces, SQL, credentials, or raw exception messages.

## 16. Offline and cache contract

Dio provides transport. `FeedCache`, backed by one dedicated `CacheManager`,
provides feed-response storage mechanics. The repository owns freshness,
fallback, invalidation, and the state shown to users.

Do not enable an automatic cache fallback that hides the original failure category.

Feed reads are network-first:

1. attempt the network;
2. classify the failure;
3. perform an explicit cache-only lookup only for an approved fallback failure;
4. return content with its actual provenance.

Fallback is permitted after:

- connection failure;
- DNS failure;
- timeout;
- HTTP 500;
- HTTP 502;
- HTTP 503;
- HTTP 504.

Rules:

- successful feed responses persist on disk;
- the full request URI, including cursor and filters, identifies an entry;
- cached responses retain saved timestamp, stale provenance, and fallback reason;
- HTTP service failures are never called offline;
- `FeedCache` uses a seven-day `CacheManager` stale period and a 32-object
  response-cache bound;
- cache-only reads use `CacheManager.getFileFromCache`; they never fetch;
- cache read, write, removal, clearing, and disposal failures are optional
  infrastructure failures, never a reason to change correct live content;
- comments are not persisted for offline use;
- mutations are never cached;
- mutations are never silently queued;
- image caching is separately owned by `app_ui` and its
  `CachedNetworkImage`/`CacheManager` configuration; feed invalidation never
  removes image bytes.

After a successful create, like, or comment:

1. update accurate visible state;
2. invalidate the complete feed-response cache;
3. refresh and re-cache the active filter while the network remains available.

Do not clear cached image bytes during feed invalidation.

If re-caching fails, retain correct in-memory state and prefer a missing future cache over a confidently wrong cache.

### Visible saved-feed states

| Situation | Required UI |
|---|---|
| Saved feed after connection, DNS, or timeout failure | Persistent `Offline · Showing saved posts` with `Retry` |
| Saved feed after HTTP 500, 502, 503, or 504 | Persistent `Showing saved posts` with `Retry`; show `Service unavailable. Showing saved posts.` once |
| Connection failure without saved data | `You’re offline. Reconnect to load the feed.` with `Retry` |
| Service failure without saved data | `Feed unavailable. Try again.` with `Retry` |
| Refresh failure while content is visible | Retain content and show `Couldn’t refresh. Showing the posts already loaded.` |
| Successful active first-page request after connection failure | Remove status and show `Back online. Feed updated.` once |
| Successful active first-page request after service fallback | Remove status without describing the device as back online |

Only a successful first-page network `GET /posts` for the active filter clears saved provenance.

A successful like, comment, create, health request, or stale next-page response cannot clear it.

### Online feed states

- Initial loading reserves feed geometry and uses one quiet platform-adaptive progress treatment.
- Do not flash an empty state.
- Do not use decorative shimmer.
- Unfiltered empty feed: `No posts yet.` with `Create a post`.
- Filtered empty feed: `No posts match these filters.` with `Clear filters`.
- First-page failure: `Couldn’t load the feed.` with `Try again`.
- End of pagination removes the footer without an end-of-feed celebration.

The status indicator is a semantics live region.

Do not add a connectivity package unless a measured retry problem justifies one. Link status cannot establish data freshness.

### Offline mutations

- Like updates optimistically, rolls back, and shows `You’re offline. Likes need a connection.`
- Comment input remains and shows `You’re offline. Reconnect to comment.`
- Complete create-post draft remains and shows `You’re offline. Reconnect to publish.`

## 17. Design system and Figma fidelity

Use Figma MCP design context, measurements, variables, screenshots, and exports. A screenshot is a comparison aid, not structured design data.

The reference frame is node `[private design node removed]` at 428 logical pixels. Header node `[private design node removed]` contains the complete logo and distinct brand mark.

Download and commit exact assets immediately because generated asset URLs may expire.

### Required assets

Commit:

- exact brand mark;
- exact wordmark;
- every custom SVG used by the selected mobile frame;
- reference imagery required for deterministic visual states;
- a semantic asset-name-to-Figma-node provenance map;
- Open Runde in weights 400, 500, 600, and 700;
- Open Runde’s OFL 1.1 licence.

Do not:

- redraw SVG paths;
- approximate an available icon;
- substitute a similar icon family;
- use a screenshot as an app asset;
- use `google_fonts`;
- permit silent font fallback.

### Tokens

`app_ui` owns repeated observed values:

- semantic colours;
- light and dark theme colour roles;
- spacing scale;
- typography roles and line heights;
- repeated radii and borders;
- visible icon sizes;
- interaction sizes;
- the small approved motion-duration and curve set.

Do not promote one-off measured geometry into a global token. A one-off local constant needs a clear semantic name and a Figma-node comment.

### Reusable components

The following components earn their keep:

- `AppIcon`;
- `AppIconButton`;
- `AppSheet`;
- `AppNotice`;
- `OfflineStatusBar`.

Use standard Flutter composition for ordinary buttons and fields.

`AppIconButton` preserves the exact visible glyph geometry while providing:

- at least a 48 by 48 logical-pixel hit region;
- platform press feedback;
- focus support;
- tooltip;
- semantics;
- optional restrained haptic feedback.

The larger interaction region must not distort the visible row geometry.

### Light mode

Light mode is the primary Figma-fidelity target.

Match:

- icon family and stroke weight;
- typography;
- image ratios;
- spacing;
- borders and radii;
- surfaces;
- system-bar relationship;
- component geometry;
- 428-pixel reference layout.

### Dark mode

Requirements:

- follow the platform system appearance;
- do not add a theme selector that is not represented in the design;
- react correctly when system brightness changes;
- use the same semantic roles as light mode;
- do not invert individual widgets;
- retain Open Runde, spacing, radii, icon geometry, image ratios, and component structure;
- preserve the brand identity and use deliberate dark surfaces;
- provide readable contrast for text, icons, borders, status surfaces, and notices;
- ensure system bars, sheets, dialogs, keyboard-adjacent surfaces, splash behaviour, and image placeholders do not flash an inappropriate light surface;
- record the inferred dark palette and its rationale in `docs/wiki/design-system.md`;
- visually verify the complete feed and all core sheets in dark mode.

### Visual validation

Before release:

- compare the 428-pixel light feed against the reference using a screenshot overlay;
- verify a 360-logical-pixel phone width for clipping and overflow;
- inspect core dark-mode surfaces at both widths;
- record assumptions for filter, comment, and create-post sheets because Figma does not provide them;
- use restrained platform-appropriate sheets built from shared tokens.

Manual overlays and behavioural tests are P0.

## 18. Interaction contract

Every visually interactive element must respond. Static labels such as location, post type, request type, property status, view count, and liked-by text do not require artificial tap handlers.

| Surface | Required outcome |
|---|---|
| Expert Listing mark | Smoothly return the feed to the top |
| Messages | `Messages aren’t part of this preview.` |
| Story strip | Native horizontal scrolling; dragging must not activate a story |
| Your Story | `Story posting isn’t part of this preview.` |
| Other story | `Story viewing isn’t part of this preview.` |
| Filters | Open working sheet; Apply resets pagination; Clear restores full feed |
| Create-post prompt | Open `CreatePostSheet` and focus body input |
| Add images | Open native picker; ordered previews; removal; four-image limit |
| Close populated create sheet | Adaptive `Discard this post?` confirmation with `Keep editing` and `Discard` |
| Publish | Stable-size progress; real request; retain draft on failure; insert returned post |
| Author avatar or name | `Profiles aren’t part of this preview.` |
| Post overflow | `Copy post details`; `Hide this post` for session with `Undo` |
| Single image | Full-screen preview with native back behaviour |
| Multiple images | Swipe carousel, stable height, understated page indicator |
| Like or like count | Whole action cell updates immediately, reconciles, or rolls back |
| Comment, count, preview, or View all | Open the same comments sheet |
| Share | Native share sheet with truthful post text, owned location, and request type or property status when applicable; no fake URL |
| Bookmark | Persist locally; first use only: `Saved on this device.` |
| Pull to refresh | Real network refresh with platform-adaptive feedback |
| Pagination | Quiet stable footer; inline `Try again` after failure |
| Active Feed destination | Scroll to top; refresh when already at top |
| Search | `Search isn’t part of this preview. Try Filters.` without selecting Search |
| List | Open the create-post flow |
| Notifications | `Notifications aren’t part of this preview.` without selecting it |
| Profile | `Profiles aren’t part of this preview.` without selecting it |

The backend `bookmarkCount` excludes this device. A local bookmark overlays the aggregate by zero or one and never implies server synchronization.

Notices must not stack.

Approved notice language includes:

- `Post published.`
- `Post hidden.` with `Undo`;
- `Post details copied.`;
- `Couldn’t refresh. Showing the posts already loaded.`;
- `Couldn’t update your like. Try again.`;
- `Couldn’t add your comment. It’s still here.`;
- `Couldn’t publish. Your post is still here.`;
- `That image couldn’t be added. Choose another.`;
- `That image format isn’t supported yet.`;
- `You can add up to 4 images.`;
- `Sharing isn’t available right now.`

Avoid:

- `Oops`;
- `Something went wrong`;
- raw exceptions;
- exclamation marks;
- fake success;
- notices for changes already obvious on screen.

## 19. Native and premium quality

Required qualities:

- stable geometry;
- sharp imagery;
- immediate feedback;
- restrained motion;
- respectful copy;
- deliberate light and dark appearances.

It does not mean:

- decorative gradients;
- broad blur;
- glass effects;
- excessive shadows;
- parallax;
- pervasive shimmer;
- haptics on every tap.

Preserve current Flutter platform behaviours:

- native scroll physics and overscroll;
- iOS status-bar tap-to-top;
- adaptive route transitions;
- iOS swipe-back;
- Android predictive back;
- native text editing, selection, and spellcheck;
- native photo picker;
- native share sheet;
- edge-to-edge system surfaces;
- safe areas and correct system-icon brightness.

Adapt mechanics without changing the shared identity:

- Android uses appropriate ink feedback;
- iOS uses restrained press-opacity feedback;
- sheets and dialogs use current platform presentation;
- keyboard insets never cover comment or publish actions;
- controls expose labels, state, focus, and tooltips;
- reduced-motion requests remove translation, scaling, bounce, shimmer, and repetitive motion.

Motion exists only to explain state or continuity:

- touch-down feedback;
- brief like or bookmark transition;
- post insertion without unexpected viewport movement;
- sheet presentation;
- saved-feed status appearance and removal.

Use haptics sparingly for deliberate selection and confirmed publication. Do not duplicate feedback already supplied by a platform control.

## 20. Performance

Target the device's native refresh rate. Do not add a frame-rate package, timer,
or unmeasured rendering workaround.

Requirements:

- use the selected stable Flutter defaults;
- use one `CustomScrollView` with lazy slivers;
- do not place a shrink-wrapped feed inside `SingleChildScrollView`;
- use stable post IDs as keys;
- preserve scroll position across refresh, like, comment, and insertion;
- decode images near rendered physical size;
- reserve final image geometry before bytes arrive;
- retain prior imagery during replacement;
- avoid content jumps;
- prefetch only visible or next-likely media;
- localize Riverbloc selection so one action row does not rebuild the entire feed;
- do not add unmeasured `RepaintBoundary`, clipping, opacity, blur, or shadow wrappers as folklore.

Profile a realistic image-filled feed in profile mode on named physical hardware:

1. warmed continuous fling;
2. next page arriving during the fling;
3. rapid likes;
4. comments sheet open and dismiss;
5. light-to-dark and dark-to-light system appearance change.

Record:

- device;
- display refresh rate;
- Flutter revision;
- trace conclusion.

If no 120 Hz device is available, mark 120 Hz as unverified. Do not infer it from an emulator or debug build.

## 21. Native splash and app icons

Use the exact Figma brand mark.

### App icon

- use the mark only;
- preserve brand proportions;
- place it within platform safe zones;
- do not squeeze the horizontal wordmark into a square.

Android requires:

- adaptive foreground;
- background;
- monochrome themed-icon layer;
- circle, squircle, and themed-mask inspection.

iOS requires:

- an opaque default asset;
- a transparent-background dark asset so the system background shows through;
- grayscale tinted artwork;
- no pre-rounded corners;
- current light, dark, and tinted appearances where supported without altering the mark.

### Splash

- use real Android and iOS native launch configuration;
- use the same base colour as the first Flutter frame for the active system appearance where supported;
- show a static mark;
- do not wait for the network;
- do not add an artificial delay;
- do not create a second Dart splash page;
- avoid a bright flash when launching in dark mode.

Commit source exports, generator configuration, and generated native assets.

Validate with a cold-launch recording and actual launcher screenshots.

## 22. Testing philosophy

Choose tests for user promises, business rules, external boundaries, or
regression-prone invariants. There is no coverage target. Prefer realistic
boundary evidence where mocks could drift from the implementation.

### Promise-to-evidence map

| Promise or invariant | Primary evidence |
|---|---|
| Relational constraints, indexes, and seed assumptions | pgTAP against local Postgres |
| Variant and ordered-property-image atomicity | Real pgTAP failure proving post, subtype, and image rows roll back |
| Cursor ordering and variant filters | Real Hono HTTP tests against local Supabase/Postgres |
| Idempotent likes and comments | Real Hono HTTP tests |
| Create-post validation and Storage behaviour | Real Hono/Postgres/Storage tests |
| Storage cleanup after database failure | Focused route-boundary test with exact-object cleanup assertion |
| Disk cache survives reconstructed process graph | Real file-store and local HTTP-server integration test |
| Feed ordering, overlap, and rollback | Bloc tests with repository fakes |
| Comment and create draft retention | Cubit tests with repository fakes |
| Provider lifecycle and disposal | Riverbloc provider-container smoke test |
| Layout states and interaction outcomes | Widget and semantics tests |
| Browse, filter, paginate, refresh | Flutter `integration_test` through real Hono/Postgres |
| Create and reopen ordered images | Flutter `integration_test` through real Hono/Storage/Postgres |
| Like, comment, refresh, and persistence | Flutter `integration_test` through real Hono/Postgres |
| Native picker, share, back, splash, icon, keyboard | Named-device manual checks |
| Light-mode Figma fidelity | 428-pixel screenshot overlay |
| Dark-mode coherence | Named-width screenshots and system-theme transition check |
| Smoothness | Named-device profile trace |
| Installability | Download, checksum, and install GitHub Release APK |

### Mocking boundary

Use:

- repository fakes for deterministic state-machine tests;
- OS/plugin fakes for difficult picker and share failures.

Do not replace these boundaries with mocks and claim integration confidence:

- Hono;
- Postgres;
- Storage;
- durable disk cache;
- main mobile journeys.

Widget tests should override repository providers while retaining the real provider, Bloc/Cubit, and widget wiring. A mocked Bloc stream is appropriate only for a small deliberate visual-state test.

### Required user journeys

#### Feed journey

Launch, see seeded posts, apply post-type, request-type, property-status, and location filters, clear filters, paginate, and refresh.

#### Create-post journey

Create a property post with multiple ordered images, property location, and status; see it in the feed; relaunch; prove content and image order persist. Also prove general and request creation without images.

#### Engagement journey

Like a post and add a comment; refresh or relaunch; prove both persist.

### Additional required proofs

- Tap every visible interactive surface and prove a state change, native invocation, route, or exact useful notice.
- Prime the feed cache through a real HTTP server, close and recreate the file store, Dio, repository, and provider container, make the server unavailable, and prove saved content renders with stale provenance.
- Verify core light and dark states.
- Verify changed filter responses cannot race.
- Verify duplicate pagination is suppressed.
- Verify rapid desired-state likes converge correctly.

Use fixed IDs and timestamps. Deliberately place equal timestamps around a page boundary.

Reset only a known local, unlinked Supabase stack or isolated CI environment. Never reset a linked, shared, or production project.

The Android emulator configuration and optional CI job may be checked in but remain commented to avoid large downloads. Required journeys still run on Prince’s existing emulator or device before completion is claimed.

Golden tests remain deferred until after the required release, required journeys, and manual overlay pass.

## 23. Nix, OrbStack, and local development

Use a lean Nix shell for Deno, Supabase CLI, Docker CLI, PostgreSQL client, JDK,
GitHub CLI, direnv, and the OrbStack CLI on macOS. Flutter, Android tooling,
emulator assets, Xcode, and container runtime state remain host prerequisites.

macOS uses OrbStack and standard host Xcode; never add Colima. Linux uses Docker
Engine. Entering the shell must not start services, reset data, open a GUI, or
download mobile SDK or emulator assets.

`.envrc`:

- enters the flake;
- clears Nix's `DEVELOPER_DIR` and `SDKROOT` overrides on macOS so Flutter uses
  the standard host-selected Xcode;
- loads `.env.local` only when it exists;
- does not start a daemon;
- does not mutate data.

Commit `.env.example`. Ignore `.env.local`, signing material, tokens, and every secret.

### Local API tests

`scripts/run-api-tests` must:

- derive the local API URL and service-role value from `supabase status -o env`;
- reject a non-loopback target;
- pass values only to the Deno child process;
- never print or persist credentials;
- fail clearly when the local stack is unavailable.

### Linked Supabase safety

Linking requires explicit current user approval. Before any linked mutation:

1. read the CLI's machine-readable ref from `supabase/.temp/project-ref`;
2. require a non-empty `EXPECTED_SUPABASE_PROJECT_REF`;
3. require exact equality and print only the public ref;
4. stop on an absent or mismatched value.

The only approved remote commands are `supabase db push`,
`supabase seed buckets --linked`, and `supabase functions deploy api`. Never
reset, delete, guess, or automatically relink a remote target. Local reset is
allowed only for an unlinked config whose project id is `expert_listing`, using
the explicit `--local` flag.

### Mobile routing

Android local development uses `adb reverse` for the local Supabase port, including public Storage URLs returned by Hono. Cleartext permission exists only in the debug manifest.

The iOS Simulator may use host loopback with only a narrow local exception. A physical iOS device uses the deployed HTTPS API.

Every release build uses deployed HTTPS and contains no broad cleartext exception.

## 24. Documentation

Documentation preserves information that is expensive or unsafe to recover from
code alone.

| Source | Purpose |
|---|---|
| This specification | Required behaviour, scope, and assumptions |
| `AGENTS.md` | Concise operational and safety rules |
| Beads | Live work, dependencies, risks, and detailed evidence |
| Root README | Assessor entry point and verified delivery links |
| `docs/wiki/` | Architecture, decisions, design contracts, and workflows |
| `docs/releases/v0.1.0.md` | Curated release record |

Create phase-specific pages only with the behaviour they describe:

| Page | Create or update with |
|---|---|
| `api-and-data.md` | Schema and HTTP implementation |
| `offline-and-cache.md` | Persisted cache and freshness behaviour |
| `testing.md` | Actual commands, environments, and evidence |
| `release.md` | Deployment, signing, artifacts, and install evidence |

A wiki entry must preserve a non-obvious decision, invariant, reproducible
workflow, provenance, external boundary, limitation, or meaningful trade-off.
A decision records its reason and the condition that would change it. Do not add
generic tutorials, internal reasoning, speculative architecture, aspirational
claims, or descriptions obvious from code.

The final assessor README answers, in order:

1. What is this?
2. What can I try immediately?
3. Where are the APK and walkthrough?
4. How do I run it?
5. What endpoints and schema exist?
6. What assumptions and trade-offs were made?
7. What was skipped?

Update documentation with the behaviour it describes. Mark claims as planned,
inferred, deferred, unverified, or verified where the distinction matters.
Include exact commands only when reproduction or safety depends on them, and
never include credentials.

## 25. Continuous integration

Before release, CI must run the project commands for:

- formatting verification;
- Dart and Flutter analysis;
- package tests;
- Bloc and Cubit tests;
- widget and semantics tests;
- provider lifecycle tests;
- cache persistence tests;
- Deno formatting;
- Deno linting;
- Deno type-checking;
- Hono function tests;
- local Supabase migrations;
- deterministic seed;
- pgTAP;
- real HTTP tests;
- release APK build probe.

A checked-in Android-emulator job may remain commented out. Do not call the mobile journeys CI-passing unless a configured runner actually executed them.

GitHub Actions must use current stable releases resolved at implementation time and pin each third-party action to a full commit SHA with a version comment.

## 26. GitHub Release

The first release is:

```text
Tag: v0.1.0
Flutter version: 0.1.0+1
```

A tag-triggered workflow must:

1. check out the existing tag;
2. install the exact selected Flutter SDK;
3. restore the committed lockfile graph;
4. reject a tag/version mismatch;
5. run required non-device checks;
6. reconstruct the assessment keystore from GitHub environment secrets;
7. build one release-mode universal APK against the deployed API;
8. verify signing;
9. name the artifact `expert-listing-v0.1.0-android.apk`;
10. generate `SHA256SUMS.txt`;
11. create the GitHub Release and attach both assets in the same release command.

Workflow permissions:

- top level: `contents: read`;
- release job only: `contents: write`;
- unrelated permissions unset;
- use the built-in GitHub token;
- do not use a personal access token.

The release body comes from `docs/releases/v0.1.0.md` and includes:

- short product description;
- two screenshots, including appropriate light and dark evidence;
- Android installation steps;
- backend and health URL;
- feature highlights;
- walkthrough link;
- tested device;
- scope notes;
- source commit;
- checksum instructions.

TestFlight is out of scope. Do not attach an unsigned IPA; document verified iOS run status honestly.

Before sharing the release:

1. download its APK;
2. verify its checksum;
3. install that downloaded artifact;
4. launch it against the hosted backend.

A locally built APK is not equivalent evidence.

## 27. Hosted verification

The final backend must pass hosted health and feed smoke checks.

A hosted mutation smoke test must:

- verify the expected project reference;
- exercise media count, size, and type rejection;
- use a unique marker;
- retain only its own returned IDs and paths;
- restore the initial desired-like state;
- delete only its returned comment, post, and exact Storage objects in `finally`;
- prove those artifacts are absent afterward.

A cleanup failure blocks release. Remediate by exact ID or path. Never reseed, truncate, reset, or delete a broad prefix to clean a hosted test.

## 28. Deferred roadmap

Post-release options are golden tests, Supabase Realtime, post video support,
and an offline mutation outbox. Their entry and completion gates are maintained
in the [deferred roadmap](../wiki/roadmap.md). Do not scaffold them during the
assessment; start only after `v0.1.0` is published and independently verified.

Everything else excluded by [Scope](#6-scope) remains out of scope.

## 29. Cut order under time pressure

If time becomes constrained:

1. cut deferred work and nonessential polish first;
2. retain the approved simple boundaries: plain-text location, flat comments,
   native text sharing, local bookmarks, read-only feed caching, one create-post
   sheet, and manual visual comparison;
3. never cut required journeys, database and API invariants, exact design assets,
   light or dark theme correctness, truthful offline state, real-boundary tests,
   useful interaction outcomes, native launch quality, or installability.

If P0 still cannot fit, surface the exact conflict. Do not silently drop an approved requirement.

## 30. Completion evidence

The assessment is complete only when every gate has recorded evidence. Only the
performance gate may use the explicitly permitted unverified outcome.

| Gate | Required evidence |
|---|---|
| Reproducible environment | Current compatible dependencies and committed lockfiles; a fresh Nix shell with required CLIs; healthy OrbStack and local Supabase |
| Data | Applied migrations and deterministic seed; configured Storage bucket; passing pgTAP tests |
| API | Passing Deno checks and real Hono tests for health, feed pagination boundaries, insertion between pages, filters, post creation and ordered images, idempotent likes, comments, validation, media rejection, not-found responses, and error envelopes |
| Flutter | Passing analysis and selected package, Bloc, Cubit, widget, provider, cache, and semantics tests, each mapped to a promise or invariant; all three mobile journeys pass against the real local backend |
| Product behaviour | Interaction inventory passes; saved-feed fallback with and without cached data and reconnection behaviour are proven |
| Design and native behaviour | Committed Figma asset provenance; recorded 428-pixel light overlay, 360-pixel light viewport, dark feed and core sheets at both widths, and live system-theme transition; picker, share, keyboard, back, splash, and icon checks on a named device |
| Performance | Profile trace on named hardware, or high-refresh performance explicitly marked unverified |
| Hosted backend | Health and feed smoke checks plus the mutation smoke test and exact cleanup from [Hosted verification](#27-hosted-verification) |
| Submission | Assessor README, indexed wiki, final screenshots, walkthrough, and externally accessible links checked in a logged-out or private browser where relevant |
| Release | Matching tag and app version; signed APK and checksum published; the downloaded APK checksum verified, then installed and launched against the hosted backend |

Do not claim visual fidelity, device behaviour, test success, release success, installability, or high-refresh performance without corresponding evidence.

## 31. Security and preservation

- Preserve unrelated staged, unstaged, and untracked work.
- Stage files by explicit path.
- Keep secrets out of source, Flutter assets, logs, screenshots, recordings, and release artifacts.
- Never print the service-role key.
- Never accept a client-supplied current-user ID.
- Never reset or delete a remote Supabase project.
- Never mutate a linked Supabase target before verifying its exact reference.
- Never use broad cleanup commands where exact IDs or paths exist.
- Never fake success.
- Never describe cached data as fresh.
- Never discard a recoverable comment or post draft.
- Never claim evidence produced in a different environment.
