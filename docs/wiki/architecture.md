# Architecture

**Status:** M4 implements the feed read path. Comments, create-post, likes, and
bookmarks remain separate feature work; check code and tests before treating
those layers as implemented.

## The whole path

~~~mermaid
flowchart TD
    UI[Flutter widgets] --> Providers[Riverpod / Riverbloc providers]
    Providers --> Logic[FeedBloc / CommentsCubit / CreatePostCubit]
    Logic --> Repo[Feature repositories]
    Repo --> Client[Dio API client]
    Repo <--> Cache[Durable read cache]
    Client --> Hono[Hono in Supabase Edge Function api]
    Hono --> DB[(Supabase Postgres)]
    Hono --> Storage[(Supabase Storage)]
    Hono -->|Returns public media URL| UI
    UI -->|Downloads public media bytes| Storage
~~~

The path is deliberately short. Feature code stays together; app_ui is separate
only because tokens and repeated controls genuinely cross feature boundaries.

## Ownership

| Concern | Owner |
| --- | --- |
| Environment configuration and object lifecycle | Riverpod |
| Feature events, state, races, and reconciliation | Bloc or Cubit |
| Riverpod-to-Bloc lifecycle connection | Riverbloc |
| Remote and saved-source policy | Feature repository |
| HTTP transport and serialization | Dio client |
| Feed-response persistence mechanics | FeedCache with its dedicated CacheManager |
| JSON routes, validation, current user, safe errors | Thin Hono function |
| Relations, constraints, atomic data work | Postgres migrations and RPC |
| Object bytes and public media delivery | Supabase Storage |
| Shared visual and interaction contracts | app_ui |
| Layout and input translation | Feature widgets |

Add a layer only when it centralizes a real boundary or business rule and makes
callers easier to understand.

## Feed state flow

Widgets translate initial load, refresh, retry, filter replacement, and
next-page requests into `FeedBloc` events. A request generation prevents a
late first-page response from replacing a newer filter, and an in-flight guard
prevents duplicate cursor requests. Stable post IDs preserve feed identity
across refresh and page merges.

Desired-state likes, returned-post insertion, local bookmarks, and session
hide or undo are owned by later feature work.

CommentsCubit and CreatePostCubit will be smaller command-oriented flows.
Comments are scoped by post ID. Create-post state lives for one opened flow and
retains retryable input after recoverable failure.

Riverbloc providers must create each Bloc or Cubit from provider-owned
repositories and close it exactly once when the scope is disposed.

## Data and cache flow

Flutter will call one public Hono base URL. Only Hono performs JSON data
operations and mutations against Supabase. Flutter never imports a Supabase
client, constructs object paths, or receives a service credential.

A feed request is network-first. After a validated live `/posts` response,
`FeedRepository` asks `FeedCache` to persist it under the full request URI.
`FeedCache` owns one seven-day, 32-object `CacheManager`; it only reads through
cache-only `getFileFromCache` and never initiates a fetch.

The repository classifies a connection, timeout, or selected service failure
before asking `FeedCache` for the matching saved entry. This preserves the
reason needed for truthful offline provenance. Only a successful first-page
network response for the active filter may clear saved state. Mutations are
never cached or silently queued.

Hono returns environment-correct public media URLs. `app_ui` owns public image
rendering through `AppNetworkImage` and `AppAvatar`; image bytes remain separate
from feed-response invalidation.
