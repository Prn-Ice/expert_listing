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

Posts are ordered by `created_at` descending, then `id` descending. Each
response encodes the last pair in an opaque, versioned cursor used to fetch the
next page.

Unlike an offset, this cursor does not skip or repeat posts when newer rows are
inserted between requests. The cost is extra cursor validation. Revisit if the
product needs random page access or a different ranking; any replacement must
still handle new insertions and tied timestamps correctly.

## Why separate requests and properties from posts?

A post stores the fields every feed item shares. A request stores the area and
intent someone is seeking. A property stores its physical location, sale or rent
status, and images. Separate rows prevent invalid combinations such as property
images on a general post or property status on a request.

This requires a small join when loading the feed. Change the relationship only
when the product gains a real shared domain object, not merely to avoid the join.

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

## Why are mobile tools installed directly?

Flutter, Android tooling, emulator assets, Xcode, and OrbStack are managed on
the host. Nix and direnv are optional, and the current Nix setup is incomplete;
neither may gate running, building, testing, or completing the repository.

The optional flake can still provide selected backend command-line tools. The
trade-off is weaker fresh-machine reproduction. Revisit only after the flake is
proven to supply the complete intended toolset without overriding host Xcode or
downloading mobile SDKs.

## Why are Dart classes final or sealed?

Concrete classes are `final` when they are complete implementations rather than
supported extension points. This makes that intent compiler-enforced and avoids
accidental subclassing or implementation outside their library. Deliberate
replacement seams, such as repositories and native services, remain abstract or
interface contracts instead of requiring tests to subclass concrete classes.

`sealed` roots represent a closed family of variants, including Bloc events and
discriminated feed models. Keeping every permitted subtype in the same library
lets Dart check exhaustive switches; making concrete leaves `final` prevents
the family from being reopened indirectly. The trade-off is less downstream
extension. Revisit a modifier only when a real external subtype is required,
not for speculative flexibility.

## Why can controls be larger than the Figma geometry?

The visible icon or artwork retains its specified dimensions, but an interactive
control keeps at least a 48 by 48 logical-pixel hit region. Standard control
padding may therefore occupy more space than the compact reference. That small
geometry difference reduces mispresses and preserves accessible touch behavior;
normal parent spacing is adjusted before diverging from the design.

Do not recover compact geometry with overlapping, invisible, or custom hit
targets. Revisit the extra padding when the design supplies a suitable 48 by 48
control or named-device testing proves a standard control can meet both
contracts without increasing mispress risk.

## Why do some Flutter controls vary by platform?

The app shares product behavior, semantic tokens, and feature state while using
narrow platform conditionals for interaction mechanics and native presentation.
Routes, sheets, dialogs, scrolling, press feedback, text editing, image picking,
sharing, and back behavior should feel expected on iOS and Android rather than
forcing one platform's conventions onto the other.

The trade-off is an additional rendering path to verify. Keep platform
selection at the app root, theme, or shared-control boundary; do not scatter
`Platform.isIOS` through feature widgets or fork business logic. Revisit a
conditional when the platform APIs converge or one shared standard control
provides equivalent native behavior on both platforms.

## Why are tests selected by promise rather than coverage?

Test the required mobile journeys against real boundaries. Repository fakes are
appropriate for state-machine tests; Hono, Postgres, Storage, and disk
persistence need integration evidence.

Revisit a test when its protected risk disappears or a cheaper test proves the
same contract. Coverage percentage is not the goal.

## Why does the database expose only security-definer functions?

API roles cannot access feed tables directly. Hono instead calls reviewed
PostgREST functions that run with the function owner's privileges, and only
`service_role` may execute them. A security-invoker `create_post` would inherit
`service_role`'s lack of table access and fail.
[API and data](api-and-data.md#relational-data) lists the available functions.

Elevated functions require careful review, so each fixes its `search_path` before
running. Revisit if the app gains per-user RLS policies; selective grants and
security-invoker functions may then express the access rules more directly.

## Why are demo personas fixed public aliases?

Authentication is outside this assessment, but current-user feed and activity
states still need realistic verification. All Flutter builds may therefore send
one of four aliases advertised by the local and hosted APIs. Hono maps it to a
known fixture UUID for that request only, and Riverpod recreates actor-sensitive
clients, repositories, and state. Feed cache keys include the alias so saved
viewer state cannot cross personas. The client never submits a fixture UUID as
request identity, and unknown aliases are rejected. Feed DTOs may still carry
author UUIDs as post data; profile and notification DTOs omit them.

This intentionally lets any assessor impersonate any fixture persona and make
mutations as that persona. It is acceptable only for the public assessment demo
with deterministic non-user accounts. Replace the header with authenticated
request identity before introducing real accounts or user-owned data.

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

## Why are like notifications durable events?

Notification history records that another persona liked a post, not merely the
current contents of the `likes` table. A new non-self like therefore appends an
event atomically with the like. Repeating the same desired state adds nothing,
unlike leaves the historical event intact, and a later relike records a new
transition. Read state belongs to the event and preserves its first timestamp.

This costs one small append-only table and explicit recipient indexes, but it
avoids notifications disappearing after they have been seen and makes read
state stable. Revisit derived notifications only if the product explicitly
decides that activity should mirror current like state and removes read history.
