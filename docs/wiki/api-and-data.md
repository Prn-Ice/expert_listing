# API and data

This page records the implemented relational and media contract. HTTP endpoints
are not implemented yet; the assessment specification remains the authority for
their future behaviour.

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

All exposed tables have RLS enabled and no anonymous write policy. The
`create_post` security-invoker RPC is executable only by `service_role`. It
creates the matching post variant and, for properties, ordered image metadata in
one database transaction.

## Media storage

`supabase/config.toml` declares the `media` bucket. It is public-read, accepts
only JPEG, PNG, and WebP objects up to 2 MiB, and sources deterministic fixture
and turns stored paths into public URLs when that API is implemented.
objects from `supabase/seed_media/`. Property fixture objects use the
`properties/` path. Server-side code, not Flutter, owns writes and turns stored
paths into public URLs when that API is implemented.
and turns stored paths into public URLs when that API is implemented.

## Local reconstruction

These commands were verified on the local unlinked stack on 2026-09-03 after
confirming that `supabase/config.toml` has `project_id = "expert_listing"` and
that `supabase/.temp/project-ref` is absent:

~~~sh
direnv exec . supabase db reset --local
direnv exec . supabase seed buckets --local
direnv exec . supabase test db --local
~~~

The reset applies `20260903000000_create_feed_schema.sql`, loads fixed Lagos
fixtures from `supabase/seed.sql`, and uploads nine media fixtures. A direct
second SQL seed application succeeded, and `supabase test db --local` passed 64
pgTAP assertions. The seed is repeat-safe for its known fixture IDs, advances
identity sequences, and does not delete unrelated rows.
