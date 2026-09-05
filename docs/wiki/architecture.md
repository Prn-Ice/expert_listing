# Architecture

## The whole path

~~~mermaid
flowchart TD
    UI[Flutter widgets] --> Providers[Riverpod / Riverbloc providers]
    Providers --> Logic[Feature Bloc or Cubit]
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

`FeedBloc` also owns desired-state likes, returned-post insertion, local bookmark
overlays, and session hide or undo. `CommentsCubit` is scoped by post ID;
`CreatePostCubit` lives for one opened flow and retains retryable input after a
recoverable failure. `NotificationsBloc` owns recipient-scoped activity loading
and read-state reconciliation.

Riverbloc providers must create each Bloc or Cubit from provider-owned
repositories and close it exactly once when the scope is disposed.

## Data and cache flow

Flutter calls one public Hono base URL. Only Hono performs JSON data
operations and mutations against Supabase. Flutter never imports a Supabase
client, constructs object paths, or receives a service credential.

Feed reads are network-first. `FeedRepository` decides when a failed request may
fall back to a matching saved response; `FeedCache` owns only persistence
mechanics. Mutations are never cached or silently queued. See
[Offline and cache](offline-and-cache.md) for freshness, invalidation, and
fallback details.

Hono returns environment-correct public media URLs. `app_ui` owns public image
rendering through `AppNetworkImage` and `AppAvatar`; image bytes remain separate
from feed-response invalidation.
