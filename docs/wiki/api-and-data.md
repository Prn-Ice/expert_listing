# API and data

This page records the implemented relational, media, and HTTP contract. The
assessment specification remains the authority for required behaviour; this page
describes what exists and how to run it.

## HTTP endpoints

One Supabase Edge Function named `api` serves a thin Hono app under the real
`/api` prefix. It is public by design (authentication is out of scope) and runs
with `verify_jwt = false` from checked-in configuration.

Implemented now:

| Route | Contract |
| --- | --- |
| `GET /api/health` | `200 {"status":"ok"}` |
| `GET /api/posts` | Cursor-paginated, server-side filtered feed of hydrated, variant-discriminated post DTOs |
| `POST /api/posts` | Validated multipart creation for general, request, and property posts; properties accept up to four ordered images |
| `GET /api/notifications` | Returns the latest bounded like activity addressed to the current preview actor |
| `POST /api/notifications/:id/read` | Idempotently records the current actor's first read timestamp |
| `GET /api/search/suggestions` | Bounded property and location autocomplete |
| `GET /api/profile` | Server-resolved current user's display name, handle, role, and public avatar URL |

`GET /api/posts` accepts `limit` (default 10, maximum 20), an opaque versioned
`cursor`, `postType`, `requestType` (only with `postType=request`),
`propertyStatus` (only with `postType=property`), and a trimmed `location`
substring that is matched literally and case-insensitively against the selected
variant's owned location — or all three location owners without a post type.
Successful responses carry `Cache-Control: private, max-age=0`; errors use the
stable `{ "error": { "code", "message" } }` envelope with `Cache-Control:
no-store`. Invalid cursors and out-of-range parameters are `VALIDATION_ERROR`,
never a silent page one.

`POST /api/posts` accepts trimmed `body`, `postType`, and `location` fields,
plus the matching `requestType` or `propertyStatus`. Repeated `images` parts are
property-only and retain their request order. Hono rejects unknown and mixed
variant fields, more than four files, files over 2 MiB, totals over 8 MiB, and
bytes that are not JPEG, PNG, or WebP regardless of their supplied filename or
MIME header. Successful responses are complete post DTOs with `201` and
`Cache-Control: no-store`.

`GET /api/notifications` accepts only an optional `limit` from 1 through 20.
It returns deterministic newest-first activity with safe actor and post fields,
but no recipient or actor UUID. `POST /api/notifications/:id/read` can update
only the request actor's event and preserves the first read timestamp. Missing
and other-recipient IDs share the same safe not-found response.

Configuration is environment-based:

- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the Edge
  runtime and are the only credentials; they never appear in responses.
- `CURRENT_USER_ID` optionally overrides the deterministic seeded current user.
- Local and hosted APIs advertise four fixed public demo aliases. Any app build
  may send one through `X-Preview-Actor`; UUIDs and arbitrary aliases are never
  accepted as client input. This intentionally permits unauthenticated fixture
  impersonation for the assessment demo and is not a production identity model.
- `PUBLIC_API_ORIGIN` optionally overrides the media-URL origin (it cannot start
  with `SUPABASE_`; the runtime strips those from custom configuration); see
  [decisions.md](decisions.md#why-do-media-urls-derive-from-the-forwarded-request-origin).
  The hosted project pins it to the public project origin because the hosted
  gateway reports the internal hop's scheme.

## Relational data

The `public` schema contains eight RLS-enabled tables:

| Table | Identity and relationship contract |
| --- | --- |
| `users` | Caller-supplied UUID primary key with unique handle |
| `property_requests` | Generated bigint primary key; owns request type and desired-area location |
| `properties` | Generated bigint primary key; owns property status and physical location |
| `posts` | Generated bigint primary key; author belongs to `users` and selects exactly one variant |
| `property_images` | Generated bigint primary key; belongs to `properties` and deletes with it |
| `comments` | Generated bigint primary key; belongs to a post and author |
| `likes` | `(post_id, user_id)` primary key; both foreign keys delete with their parent |
| `notification_events` | Generated bigint primary key; durable non-self like activity belongs to one recipient, actor, and post |

Posts and comments reject blank or out-of-range trimmed text. General posts own
`posts.location`. Request posts reference a `property_requests` row, which owns
the desired-area location and `looking_to_buy` or `looking_to_rent` type.
Property posts reference a `properties` row, which owns the physical location
and `for_sale` or `for_rent` status. The post check constraint rejects every
other combination, including a location on a subtype post or both subtype IDs.

Property images have unique stored paths, positions from zero through three,
and one image per property position. Only properties can have images, and a
property may have none. Post view and bookmark counts cannot become negative.
Post `created_at` cannot be changed after insertion.

Indexes cover feed cursor order, post-type pagination, request-type and
property-status filtering, case-insensitive location substring search on each
location owner, comment order, property image order, and uncovered foreign
keys.

All exposed tables have RLS enabled, no anonymous write policy, and no direct
grants to API roles. Security-definer functions are the entire database surface
reachable by `service_role`:

- `create_post` creates the matching post variant and, for properties, ordered
  image metadata in one database transaction;
- `create_hydrated_post` wraps creation and returns the complete new feed row in
  that same transaction;
- `feed_page` returns one hydrated feed page — author, variant payload,
  engagement counts, and the viewer's like state — in a single round trip, with
  cursor keyset filtering and literal, escaped location matching;
- `property_search_suggestions` returns ranked, bounded property autocomplete;
- `list_notifications` returns at most 20 recipient-isolated activity rows in deterministic newest-first order;
- `mark_notification_read` records one recipient-owned event's first read timestamp;
- `user_profile` returns one user's public profile fields without exposing the
  UUID in the HTTP response.

`set_post_like` appends a notification event in the same transaction only when
a non-self `liked: true` request creates a new like row. Repeated desired-state
likes create no duplicate, unlike retains history, and a later relike appends a
new activity event.

## Media storage

`supabase/config.toml` declares the `media` bucket. It is public-read, accepts
only JPEG, PNG, and WebP objects up to 2 MiB, and sources deterministic fixture
objects from `supabase/seed_media/`. Property fixture objects use the
`properties/` path. Server-side code, not Flutter, owns writes and turns stored
paths into public URLs inside DTOs.
Property uploads use server-generated `properties/<upload-id>/<position>`
paths with detected extensions and no overwrite. If an upload or database step
fails, Hono removes only the exact objects confirmed for that request.
The picker bounds the longest edge to 2048 pixels while preserving aspect
ratio, and Hono stores the resulting bytes unchanged. Feed media uses an
aspect-preserving cover crop; full-screen media uses contain, adding empty space
when needed rather than stretching the image.

## Local reconstruction

These commands were verified on the local unlinked stack on 2026-09-05 after
confirming that `supabase/config.toml` has `project_id = "expert_listing"` and
that `supabase/.temp/project-ref` is absent:

~~~sh
direnv exec . supabase db reset --local
direnv exec . supabase seed buckets --local
direnv exec . supabase test db --local
direnv exec . scripts/run-api-tests
~~~

The reset applies all committed migrations, loads fixed Lagos fixtures from
`supabase/seed.sql`, and uploads nine media fixtures. A direct second SQL seed
application succeeded, and the pgTAP and API suites passed against real local
Postgres and Storage, including one request through the served local Edge
Function. The
seed is repeat-safe for its known fixture IDs, advances
identity sequences, and does not delete unrelated rows.
