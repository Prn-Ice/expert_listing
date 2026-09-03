# Development

## Start the environment

```sh
direnv allow
direnv exec . orb start
direnv exec . supabase start
```

`orb start` is required on macOS before Docker or Supabase commands can connect.
Entering the development shell does not start containers or mutate local data.

The pinned Nix shell provides OrbStack on macOS, Docker CLI, Deno, Supabase
CLI, PostgreSQL client, GitHub CLI, JDK 21, and direnv. Start the macOS runtime
with `orb start`.

Flutter and Android platform tools are currently host prerequisites. Their Nix
artifacts are intentionally tabled on macOS after an interrupted cache download.

## Local API

The local Supabase stack uses ports `56321` through `56329` so it can coexist
with other local projects.

| Service | URL or port |
| --- | --- |
| API | `http://127.0.0.1:56321` |
| Edge Function | `http://127.0.0.1:56321/functions/v1/api` |
| Database | `127.0.0.1:56322` |
| Studio | `http://127.0.0.1:56323` |
| Mailpit | `http://127.0.0.1:56324` |

Serve the function in a dedicated terminal:

```sh
direnv exec . supabase functions serve api --no-verify-jwt
```

Run the health checks from another terminal:

```sh
direnv exec . scripts/run-api-tests
```

The test helper gets local API and service-role values from the running stack,
passes them to the Deno child process, and does not write or print credentials.

## Flutter

Flutter's generated dependency graph is locked in
`apps/expert_listing/pubspec.lock`. Direct dependencies are current as of the
initial resolution. The durable HTTP cache uses `dio_cache_interceptor` 4.0.7
with maintained `http_cache_file_store` 2.0.2; the discontinued legacy file
store package was not retained.

Run the application checks from `apps/expert_listing/`:

```sh
flutter analyze
flutter test
flutter build apk --release
```

The host currently has Flutter/Dart and the Android SDK. CocoaPods is absent,
and Figma has reached its Starter-plan MCP call limit.
