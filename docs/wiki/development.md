# Development

Use this page to enter the development environment, run the app and backend,
and work safely with local or linked Supabase projects.

## Quick start

Enter the project environment once. With the direnv shell hook installed:

~~~sh
direnv allow
~~~

Without the hook, open a Nix development shell instead:

~~~sh
nix develop
~~~

Then start OrbStack on macOS and verify the app toolchain, function runtime,
Supabase CLI, and container engine:

~~~sh
orb start
flutter doctor
deno --version
supabase --version
docker info
~~~

On Linux, start Docker Engine instead of running `orb start`.

These commands verify both executable discovery and the running container
engine.

## Tool ownership

| Nix provides | The host provides |
| --- | --- |
| Deno, Supabase CLI, Docker CLI, PostgreSQL client, JDK 21, GitHub CLI, resvg, pngcrush, and direnv | Flutter/Dart, Android SDK and device assets, standard Xcode, Docker daemon state, and account authentication |
| OrbStack CLI on macOS | OrbStack VM state and Docker Compose integration |

The flake supports Apple Silicon macOS and x86-64 Linux. macOS uses OrbStack;
Linux uses Docker Engine. Flutter, Android tools, emulators, system images, and
Xcode remain host prerequisites and are never downloaded when entering the
shell. `adb` is a host prerequisite before device or emulator work.

On macOS, `.envrc` clears Nix's Apple SDK overrides so Flutter continues to use
the standard host-selected Xcode. The reasoning behind this boundary is recorded
once in [decisions.md](decisions.md#what-belongs-to-nix-and-what-remains-on-the-host).

## Local Supabase

Project-specific ports allow local stacks to coexist:

| Service | Address |
| --- | --- |
| API and Storage | http://127.0.0.1:56321 |
| Edge Function | http://127.0.0.1:56321/functions/v1/api |
| PostgreSQL | 127.0.0.1:56322 |
| Studio | http://127.0.0.1:56323 |
| Mailpit | http://127.0.0.1:56324 |

Start the stack and serve the Hono function in separate terminals:

~~~sh
supabase start
supabase functions serve api --no-verify-jwt
~~~

`supabase start` already serves the function at the address above, but its
runtime caches worker code; after editing `supabase/functions/api/`, either
restart the runtime container (`docker restart
supabase_edge_runtime_expert_listing`) or use the separate `functions serve`
terminal, which reloads on change.

Run real local API checks from another terminal:

~~~sh
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

After the exact check passes, run only the required command:

~~~sh
supabase db push
supabase seed buckets --linked
supabase functions deploy api
~~~

No other linked mutation is approved. Never run a remote reset or delete, and
never print credentials while checking the public project reference.

## Flutter and devices

Run Flutter checks from `apps/expert_listing_mobile`:

~~~sh
cd apps/expert_listing_mobile
flutter analyze
flutter test
~~~

Run the app from the same directory with an explicit public Hono endpoint:

~~~sh
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:56321/functions/v1/api
~~~

~~~sh
flutter run --dart-define=API_BASE_URL=https://chvhwausefhvaceygppc.supabase.co/functions/v1/api
~~~

The local command requires the local Supabase stack. The hosted command uses
only the public API URL and contains no credential.

On Android, `127.0.0.1` refers to the device rather than the development
computer. When testing against local Supabase, forward the app's local port to
the same port on the computer:

~~~sh
adb reverse tcp:56321 tcp:56321
~~~

Run this after connecting the device or emulator. It is not used with the
hosted backend or in release builds.

Cleartext access is permitted only by the Android debug manifest. A physical iOS
device uses the deployed HTTPS backend. Standard host Xcode remains the iOS
toolchain.
