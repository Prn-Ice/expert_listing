# Development

Use this page to understand the repository infrastructure, enter the development
environment, run the app and backend, and work safely with local or linked
Supabase projects.

## Quick start

Flutter, Xcode, and the Android SDK and device tools are installed directly on
the development machine. Verify that host toolchain first:

~~~sh
flutter doctor
~~~

The current release-candidate toolchain is:

| Tool | Version | Source of truth |
| --- | --- | --- |
| Flutter | `3.47.0` stable | Pinned by the CI, release, and TestFlight workflows |
| Dart | `3.13.0` | Bundled with Flutter `3.47.0` and required by both Dart packages |
| Xcode | `26.6` (`17F113`) | Verified on the macOS development host |
| Android | SDK/API `36`; Build Tools `36.0.0` | Flutter supplies compile and target SDK 36; verified on the development host |

These are the versions used to verify the release candidate, not broad
compatibility claims. Run `flutter doctor -v` to confirm the local host before
building or testing.

Start OrbStack on macOS, then verify the backend command-line tools and
container engine:

~~~sh
orb start
deno --version
supabase --version
docker info
~~~

On Linux, start Docker Engine instead of running `orb start`.

## Tool ownership

| Owned directly by the host | Directly installed or optionally exposed by Nix |
| --- | --- |
| Flutter/Dart, Android SDK and device assets, `adb`, standard Xcode, the OrbStack application and VM state, and account authentication | Deno, Supabase CLI, Docker CLI, PostgreSQL client, JDK 21, GitHub CLI, resvg, pngcrush, direnv, and the OrbStack CLI package on macOS |

The optional flake targets Apple Silicon macOS and x86-64 Linux, but it does not
own Flutter, Android tooling, emulator assets, system images, or Xcode. macOS
uses OrbStack; Linux uses Docker Engine.

### Optional Nix and direnv files

`flake.nix` declares an optional development shell for selected backend and
release command-line tools. `flake.lock` pins the `nixpkgs` input revision and
hash from which those packages resolve. Flutter and the Android tools are
commented out deliberately because the host installation owns them; this shell
does not supply Xcode and requires the host installation. Although the flake
declares `orbstack` on macOS, the host application and its VM state remain
authoritative.

`.envrc` is the optional direnv entry point. After a contributor explicitly
allows it, direnv enters the flake. On macOS it unsets `DEVELOPER_DIR`, `SDKROOT`,
and `LD`, then puts `/usr/bin` first so the host Xcode tools win. It also loads
ignored values from `.env.local` when that file exists. Inspect it before
allowing it: entering the shell can evaluate or download Nix inputs and exports
`.env.local` values into the current shell.

Nix and direnv are not prerequisites for running, building, or testing this
repository, and no documented command depends on them. The shell does not start
OrbStack or Docker, mutate data, open applications, or install mobile SDKs.

## Repository infrastructure

Application code lives in `apps/expert_listing_mobile/`, shared visual contracts
live in `packages/app_ui/`, and the database, seed data, and Hono Edge Function
live in `supabase/`. `docs/spec/` owns the product contract, `docs/wiki/` owns
durable workflows and decisions, and `scripts/` contains checked-in command
entry points such as the real API test runner.

The less obvious support files have these roles:

| Path | Purpose and maintenance boundary |
| --- | --- |
| `AGENTS.md` | Repository-specific operating, architecture, safety, and permission rules for coding agents. It overrides generic agent guidance but does not replace the product specification. |
| `.agents/skills/` | Task-specific workflows that compatible coding agents load when relevant. `beads` and `figma-to-flutter-layout` are repository-local; the other six entries are imported. None is a Flutter dependency or app asset. |
| `skills-lock.json` | Source and integrity hashes for the six imported skills. No repository-approved refresh or validation command is currently documented, so do not regenerate or hand-edit it until that workflow is established. |
| `opencode.jsonc` | Project configuration for OpenCode. It enables the Context7 documentation and Figma MCP servers; it has no effect on the built app, and authentication remains outside the file. |
| `.env.example` | Checked-in inventory of variables, not runtime configuration. `API_BASE_URL` is public Flutter build configuration supplied through `--dart-define`; `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are server-only; `EXPECTED_SUPABASE_PROJECT_REF` is supplied independently before linked mutations. `.envrc` may load an optional ignored `.env.local`, but no workflow requires every variable there. |
| `.github/workflows/` | Project-maintained CI, Android release, and optional TestFlight automation. The [release runbook](release.md) owns invocation, signing, and evidence boundaries. |
| `.gitignore` | Excludes matching untracked generated output, local settings, credentials, signing material, raw test media, and local recording files by default. It does not protect tracked or force-added files, so review changes as security-sensitive. |
| App and package `.metadata` files | Flutter-owned migration metadata. Keep them committed and let Flutter update them; their revision is not the current SDK version declaration. |
| `apps/expert_listing_mobile/pubspec.lock`, `packages/app_ui/pubspec.lock`, and `supabase/functions/api/deno.lock` | Tool-generated resolved dependency graphs for the two Flutter packages and Hono API. Keep them committed and update them through their owning package tools, not manual edits. |

Local `.git/`, `.dart_tool/`, `.direnv/`, `build/`, `.vscode/`, `.DS_Store`, and
`raw_test_images/` content is repository metadata, generated state, personal
configuration, or ignored local test input. None is a project source of truth.

## Project tracking with Beads

[Beads](https://github.com/steveyegge/beads) is the repository's shared,
dependency-aware issue tracker. Contributors and agents use its `bd` CLI to
record active work, ownership, blockers, dependencies, risks, and exact
verification evidence. The specification defines required product behaviour;
Beads records the current operational state of delivering it.

The `.beads/` directory contains repository configuration, Git-hook shims, and
serialized issue and interaction records. Beads owns those files and its local
Dolt state; they are not an alternate set of product documents. Its checked-in
configuration names a Dolt sync remote. A local checkout can also set
`core.hooksPath` to `.beads/hooks`, causing ordinary Git operations to delegate
hook behavior to the installed `bd` version; check `git config core.hooksPath`
rather than assuming hooks are active in every clone.

Run Beads commands from the repository root:

~~~sh
bd prime
bd ready
bd list --status in_progress
bd show <issue-id>
bd update <issue-id> --claim
~~~

Use the CLI rather than editing files under `.beads/`. Treat Beads changes as
project state: do not commit or synchronize them without current authorization.
The generated `.beads/README.md` describes the tool generally; this development
guide and `AGENTS.md` own this repository's permissions and workflow.

## Local Supabase

Project-specific ports allow local stacks to coexist:

| Service | Address |
| --- | --- |
| API and Storage | http://127.0.0.1:56321 |
| Edge Function | http://127.0.0.1:56321/functions/v1/api |
| PostgreSQL | 127.0.0.1:56322 |
| Studio | http://127.0.0.1:56323 |
| Mailpit | http://127.0.0.1:56324 |

Start the local stack from the repository root:

~~~sh
supabase start
~~~

The Profile destination advertises the same four public demo personas locally
and on the hosted assessment backend. Selecting one sends its fixed alias on
subsequent requests; no UUID or credential is stored in the app.

The started stack serves the Hono function at the address above. Run the real
local database and API checks from another terminal:

~~~sh
supabase test db --local
scripts/run-api-tests
~~~

To deliberately rebuild only this known local, unlinked database, first verify
that `project_id = "expert_listing"` in `supabase/config.toml` and that
`supabase/.temp/project-ref` does not exist. Then run exactly:

~~~sh
supabase db reset --local
supabase seed buckets --local
~~~

Stop if either precondition is false. Never remove or ignore the linked-ref file
to make a reset pass.

## Linked Supabase

Do not run `supabase link` without explicit approval. Before every linked
mutation:

1. read the public project reference in `supabase/.temp/project-ref`;
2. require a non-empty `EXPECTED_SUPABASE_PROJECT_REF` supplied independently;
3. require the two values to match exactly;
4. stop if either value is absent or they differ.

Use the project list to identify the linked project when needed; its `LINKED`
marker is useful context, not a substitute for the exact reference check:

~~~sh
supabase projects list
~~~

After the exact check passes, choose and run only the required mutation.

Apply migrations:

~~~sh
supabase db push
~~~

Seed Storage fixtures:

~~~sh
supabase seed buckets --linked
~~~

Deploy the API function:

~~~sh
supabase functions deploy api
~~~

Repeat the exact reference check immediately before any later mutation. No other
linked mutation is approved. Never run a remote reset or delete, and never print
credentials while checking the public project reference.

## Flutter and devices

Run Flutter checks directly from each package:

~~~sh
cd apps/expert_listing_mobile
flutter analyze
flutter test
cd ../../packages/app_ui
flutter analyze
flutter test
~~~

Run the app from `apps/expert_listing_mobile` against the hosted public API:

~~~sh
flutter run --dart-define=API_BASE_URL=https://chvhwausefhvaceygppc.supabase.co/functions/v1/api
~~~

The URL is public configuration and contains no credential. Local Supabase
verification is performed by the host-run database and API checks above.
