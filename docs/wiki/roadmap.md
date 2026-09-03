# Deferred roadmap

All items below begin only after `v0.1.0` is published and independently
verified. Active work belongs in Beads. Dark mode is required for the assessment
and is not deferred.

## Golden tests

Early baselines would preserve screen churn rather than confidence. Start after
all three real journeys pass and the manual Figma overlay is accepted.

The smallest complete slice covers stable feed, post card, filter, comments,
create-post, offline, empty, error, light, and dark states at 428 and 360 logical
pixels.
Claim completion only with deterministic CI results and reviewed baseline
provenance.

## Supabase Realtime

REST pagination and mutation reconciliation must be trustworthy before adding
another ordering source. Start after cursor and desired-state mutation behaviour
is stable.

The smallest complete slice merges insert, update, and delete events by ID
without duplicates, preserves cursor order, reconnects through a REST resync,
and passes real-backend disconnect and reconnection tests.

## Post video support

Reliable bounded image upload, rollback, and rendering come first. Start after
image validation and cleanup are stable.

The smallest complete slice validates bytes, uploads and persists the media,
generates a poster or thumbnail, renders and controls playback, supports retry
and accessibility, and removes uploaded objects after cancellation or failure
on a real device.

## Offline mutation outbox

Queued writes are unsafe until read provenance, idempotency, and online
mutations are proven. Start after cache and mutation behaviour is trustworthy.

The smallest complete slice defines the conflict policy, persists queued intent,
shows pending and failed states, guarantees idempotent ordered replay, supports
cancellation, and proves reconnection behaviour with real tests.

Other boundaries remain those listed in the specification's
[scope section](../spec/expert-listing-assessment.md#6-scope). Do not scaffold an
excluded capability.
