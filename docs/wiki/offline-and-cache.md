# Offline and cache

## Feed reads

`FeedRepository` always asks Hono for the requested `/posts` page first. It
constructs the full URI from active filters and cursor, parses the live response,
then asks `FeedCache` to persist the validated JSON envelope. The cache uses its
own `CacheManager` key, a seven-day stale period, and a 32-object bound.

There is no automatic error fallback. The repository receives the original
`DioException`, reads `FeedCache` only after a connection, DNS, or timeout
failure, or after HTTP 500, 502, 503, or 504. A 404 or validation error remains
an error. `FeedCache.read` calls `getFileFromCache` with the full request URI,
so it is a cache-only operation and cannot fetch.

Saved entries contain the original saved timestamp and validated data. Expired,
corrupt, unreadable, or unavailable cache entries are cache misses. Reads,
writes, and corrupt-entry cleanup for one full URI run one at a time in call
order: a superseded response never saves, the newest accepted response for a
URI is the final saved value, and cleanup cannot delete a fresher value
written under the same URI. Invalidation retires the network loads that were
still running and drains cache writes already underway, so neither can write
pre-mutation data into the cleared cache. Different filter and cursor pages
stay independent. Cache I/O is optional infrastructure: a failure cannot turn a
valid live response into an error. There is no mutation cache and no offline
queue.

## Visible provenance

The feed labels connection fallback as `Offline · Showing saved posts` and
service fallback as `Showing saved posts`, both with Retry. A live first-page
request for the active filter is the only operation that clears that label.
Later pages, health checks, and future mutations cannot clear saved provenance.

## Image bytes

Public Hono image and avatar URLs use `AppNetworkImage` and `AppAvatar` from
`app_ui`. `app_ui` is the only production owner of `CachedNetworkImage`; image
cache mechanics remain separate from saved feed responses. Feed-response
invalidation deliberately leaves image bytes alone.

## Evidence

`apps/expert_listing_mobile/test/feed/feed_cache_integration_test.dart` primes
a real local HTTP server and temporary-directory `CacheManager`, reconstructs
the manager and repository, then verifies connection and service fallback
provenance, full-URI lookup, seven-day expiry, 32-entry eviction,
corruption misses, malformed-live protection, same-URI write and cleanup
races, and live success when cache writing fails.

Named manual evidence: on 4 September 2026, the iPhone 16 Pro simulator
full-app journey rebuilt the production provider graph over the primed disk
store after the operator stopped the local functions route. Refresh rendered
`Offline · Showing saved posts`, the saved posts, and Retry. This
operator-driven flow is not an unattended integration test; the reconstruction
test above is the automated offline proof.
