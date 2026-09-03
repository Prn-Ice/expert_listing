# Development

Use `direnv allow`, then run project commands with `direnv exec .`.

The pinned Nix shell provides OrbStack on macOS, Docker CLI, Deno, Supabase
CLI, PostgreSQL client, GitHub CLI, JDK 21, and direnv. Start the macOS runtime
with `orb start`; entering the shell never starts it or mutates local data.

Flutter and Android platform tools are currently host prerequisites. Their Nix
artifacts are intentionally tabled on macOS after an interrupted cache download.

The local Supabase stack uses ports `56321` through `56329` so it can coexist
with other local projects. Run `direnv exec . supabase start`, serve the API
with `direnv exec . supabase functions serve api --no-verify-jwt`, and use
`direnv exec . scripts/run-api-tests` for direct and live health checks. Local
credentials are derived in memory and never written to project files.

Flutter's generated dependency graph is locked in
`apps/expert_listing/pubspec.lock`. Direct dependencies are current as of the
initial resolution. The durable HTTP cache uses `dio_cache_interceptor` 4.0.7
with maintained `http_cache_file_store` 2.0.2; the discontinued legacy file
store package was not retained.

The host currently has Flutter/Dart and the Android SDK. CocoaPods is absent,
and Figma has reached its Starter-plan MCP call limit.
