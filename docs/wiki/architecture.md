# Architecture

**Status:** planned architecture. Check code and tests before treating a layer
as implemented.

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
| Read-response persistence mechanics | Cache interceptor and file store |
| JSON routes, validation, current user, safe errors | Thin Hono function |
| Relations, constraints, atomic data work | Postgres migrations and RPC |
| Object bytes and public media delivery | Supabase Storage |
| Shared visual and interaction contracts | app_ui |
| Layout and input translation | Feature widgets |

Add a layer only when it centralizes a real boundary or business rule and makes
callers easier to understand.

## Planned state flow

Widgets translate user intent into product events. FeedBloc will handle
overlapping feed work because ordering matters: initial load, refresh, next
page, filter replacement, desired-state likes, returned-post insertion, local
bookmarks, and session hide or undo.

CommentsCubit and CreatePostCubit will be smaller command-oriented flows.
Comments are scoped by post ID. Create-post state lives for one opened flow and
retains retryable input after recoverable failure.

Riverbloc providers must create each Bloc or Cubit from provider-owned
repositories and close it exactly once when the scope is disposed.

## Data and cache flow

Flutter will call one public Hono base URL. Only Hono performs JSON data
operations and mutations against Supabase. Flutter never imports a Supabase
client, constructs object paths, or receives a service credential.

A feed request is network-first. The repository—not the HTTP cache—decides
whether a connection, timeout, or selected service failure may fall back to a
saved response. It returns saved timestamp and failure provenance with the data.
Only a successful first-page network response for the active filter may clear
that saved state. Mutations are never cached or silently queued.

Hono returns environment-correct public media URLs. Image bytes use their own
bounded cache and remain separate from feed-response invalidation.
