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

`GET /api/posts` accepts `limit` (default 10, maximum 20), an opaque versioned
`cursor`, `postType`, `requestType` (only with `postType=request`),
`propertyStatus` (only with `postType=property`), and a trimmed `location`
substring that is matched literally and case-insensitively against the selected
variant's owned location — or all three location owners without a post type.
Successful responses carry `Cache-Control: private, max-age=0`; errors use the
stable `{ "error": { "code", "message" } }` envelope with `Cache-Control:
no-store`. Invalid cursors and out-of-range parameters are `VALIDATION_ERROR`,
never a silent page one. Mutation routes arrive with their own beads.

Configuration is environment-based:

- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the Edge
  runtime and are the only credentials; they never appear in responses.
- `CURRENT_USER_ID` optionally overrides the deterministic seeded current user.
- `PUBLIC_API_ORIGIN` optionally overrides the media-URL origin (it cannot start
  with `SUPABASE_`; the runtime strips those from custom configuration); see
  [decisions.md](decisions.md#why-do-media-urls-derive-from-the-forwarded-request-origin).
  The hosted project pins it to the public project origin because the hosted
  gateway reports the internal hop's scheme.

## Relational data

The `public` schema contains seven RLS-enabled tables:

| Table | Identity and relationship contract |
| --- | --- |
| `users` | Caller-supplied UUID primary key with unique handle |
| `property_requests` | Generated bigint primary key; owns request type and desired-area location |
| `properties` | Generated bigint primary key; owns property status and physical location |
| `posts` | Generated bigint primary key; author belongs to `users` and selects exactly one variant |
| `property_images` | Generated bigint primary key; belongs to `properties` and deletes with it |
| `comments` | Generated bigint primary key; belongs to a post and author |
| `likes` | `(post_id, user_id)` primary key; both foreign keys delete with their parent |

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
grants to API roles. Two security-definer functions are the entire database
surface reachable by `service_role`:

- `create_post` creates the matching post variant and, for properties, ordered
  image metadata in one database transaction;
- `feed_page` returns one hydrated feed page — author, variant payload,
  engagement counts, and the viewer's like state — in a single round trip, with
  cursor keyset filtering and literal, escaped location matching.

## Media storage

`supabase/config.toml` declares the `media` bucket. It is public-read, accepts
only JPEG, PNG, and WebP objects up to 2 MiB, and sources deterministic fixture
objects from `supabase/seed_media/`. Property fixture objects use the
`properties/` path. Server-side code, not Flutter, owns writes and turns stored
paths into public URLs inside DTOs.

## Local reconstruction

These commands were verified on the local unlinked stack on 2026-09-03 after
confirming that `supabase/config.toml` has `project_id = "expert_listing"` and
that `supabase/.temp/project-ref` is absent:

~~~sh
direnv exec . supabase db reset --local
direnv exec . supabase seed buckets --local
direnv exec . supabase test db --local
direnv exec . scripts/run-api-tests
~~~

The reset applies both migrations, loads fixed Lagos fixtures from
`supabase/seed.sql`, and uploads nine media fixtures. A direct second SQL seed
application succeeded, and `supabase test db --local` passed 64 pgTAP
assertions. The seed is repeat-safe for its known fixture IDs, advances
identity sequences, and does not delete unrelated rows. The API test task runs
16 real HTTP tests against the local stack.
