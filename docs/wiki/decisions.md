# Decisions

These entries answer questions whose rationale would otherwise be expensive to
recover from code. The specification remains authoritative.

## Why Hono instead of bare Deno handlers?

Use Hono as a thin router inside one Supabase Edge Function named api. Supabase
hosts and executes the function; Hono is not an edge-function provider.

Readable route declarations, small middleware, centralized error mapping, and
direct Request-to-Response tests justify the dependency. Controllers, an ORM,
and a DI container would add ceremony without simplifying this assessment.
Revisit bare Deno only if Hono stops supporting the selected stable Deno or
Supabase runtime, or the API becomes so small that routing no longer earns a
dependency.

## Why Riverbloc?

Riverpod owns configuration and object lifecycles; Bloc/Cubit owns feature
behaviour; Riverbloc connects them without adding flutter_bloc.

That split makes dependencies replaceable while keeping feed races and mutation
reconciliation explicit and testable. Its trade-off is sensitivity to Riverpod
lifecycle APIs. Revisit only if the packages become incompatible or a verified
lifecycle test shows the bridge cannot close instances exactly once.

## Why cursor pagination instead of offsets?

Use the ordered tuple created_at descending, id descending and encode the last
returned tuple in an opaque versioned cursor.

Offsets can duplicate or skip rows when new posts arrive between requests. A
cursor is slightly more work to validate but preserves stable continuation.
Revisit only if the product needs random page access or a different ranking key;
any replacement must prove insertion and tied-timestamp behaviour.

## Why separate requests and properties from posts?

A post describes feed presentation and engagement. A request owns the area and
intent someone is seeking; a property owns its physical location, sale or rent
status, and images. Keeping those values on their domain rows prevents an
impossible feed item such as a general post with property images or a request
with a property status.

The trade-off is a small join when hydrating the feed. Revisit only if the
product gains a shared, real domain object that needs a different relationship;
do not reintroduce a combined subtype field merely to avoid that join.

## Why does the repository own offline fallback?

Dio owns transport, and cache packages own persisted response mechanics. The
repository owns failure classification, freshness, invalidation, and the words
shown to users.

Automatic cache fallback can hide whether a device is offline or the service
failed, making stale data look fresh. Explicit fallback costs a little code but
keeps the product honest. Revisit when an admitted cache library exposes the
same provenance contract transparently and real persistence tests prove it.

## Why is Storage public-read and server-write?

The assessment needs durable images without implementing auth. Hono writes
unique paths using its server-only credential and returns public URLs; Flutter
only downloads those bytes.

This simplifies viewing but is not a production privacy model. Revisit before
real user or private listing data, when authentication, ownership policies,
signed URLs, abuse controls, and retention rules must be designed together.

## What belongs to Nix and what remains on the host?

Nix provides the command-line toolchain. Flutter, Android tooling, emulator
assets, Xcode, and container runtime state remain on the host so entering the
project does not download mobile SDKs or start services.

The trade-off is weaker fresh-machine reproduction of the mobile toolchain.
Revisit when onboarding a machine without a working host setup.

## Why are tests selected by promise rather than coverage?

Test the browse/filter/paginate, create-and-reopen-images, and
like/comment/persistence journeys against real boundaries. Repository fakes are
appropriate for state-machine tests; Hono, Postgres, Storage, and disk
persistence need integration evidence.

Revisit a test when its protected risk disappears or a cheaper test proves the
same contract. Coverage percentage is not the goal.

## Why is the database surface security-definer functions only?

Feed tables carry no direct grants to API roles. `create_post` and `feed_page`
are security-definer functions executable only by `service_role`, so the entire
database surface reachable through PostgREST is those two vetted contracts. This
also repaired a latent defect: a security-invoker `create_post` would have
failed through PostgREST because `service_role` has no table privileges.

The trade-off is discipline inside the functions: each pins `search_path` so
the definer context cannot be hijacked. Revisit if per-caller RLS policies are
introduced; then selective grants with security-invoker functions may express
the contract more directly.

## Why do media URLs derive from the forwarded request origin?

DTOs must carry client-reachable public URLs, but the local Edge runtime
injects the internal container host as `SUPABASE_URL`. The gateway already
tells the function the public origin through `x-forwarded-host`,
`x-forwarded-port`, and `x-forwarded-proto`, so media URLs are built from those
headers, falling back to the request origin. An optional `PUBLIC_API_ORIGIN`
override wins first when an operator needs to pin the origin — the hosted
project uses it because the hosted gateway's forwarded scheme reports the
internal hop rather than the client's TLS scheme, and custom environment names
may not start with `SUPABASE_`.

The trade-off is trusting gateway headers that Supabase controls on both local
and hosted paths. Revisit if the hosted gateway stops sending forwarded headers
or if the API gains non-gateway callers that must not influence URL generation.

## Why are goldens, Realtime, video posts, and queued writes deferred?

They add baseline churn, ordering complexity, media failure modes, or conflict
behaviour before the core is proven. Do not scaffold them during the
assessment; [roadmap.md](roadmap.md) defines their entry and completion gates.
