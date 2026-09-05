# Development

Use this page to enter the development environment, run the app and backend,
and work safely with local or linked Supabase projects.

## Quick start

Flutter, Xcode, and the Android SDK and device tools are installed directly on
the development machine. Verify that host toolchain first:

~~~sh
flutter doctor
~~~

Start OrbStack on macOS, then verify the backend command-line tools and
container engine:

~~~sh
orb start
deno --version
supabase --version
docker info
~~~

On Linux, start Docker Engine instead of running `orb start`.

Nix and direnv are optional. The current Nix setup is incomplete and is not a
prerequisite for running, building, or testing the repository. No documented
command depends on either tool. If you choose to use the optional shell, verify
each required command rather than assuming it supplies the complete toolchain.

## Tool ownership

| Installed directly on the host | Directly installed or optionally supplied by Nix |
| --- | --- |
| Flutter/Dart, Android SDK and device assets, `adb`, standard Xcode, OrbStack and its VM state, and account authentication | Deno, Supabase CLI, Docker CLI, PostgreSQL client, JDK 21, GitHub CLI, resvg, pngcrush, and direnv |

The optional flake targets Apple Silicon macOS and x86-64 Linux, but it does not
own Flutter, Android tooling, emulator assets, system images, or Xcode. macOS
uses OrbStack; Linux uses Docker Engine.

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
