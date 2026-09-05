# Release

This page is the runbook for the checked-in CI and release machinery. It
describes what exists and how the final `v0.1.0` release is produced. The
assessment specification remains the authority for required behaviour.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and on pull requests with
three jobs:

| Job | What it runs |
| --- | --- |
| Flutter and Dart checks | `dart format --output=none --set-exit-if-changed`, `flutter analyze`, and `flutter test` in `apps/expert_listing_mobile` and `packages/app_ui` |
| Hono and Supabase checks | `deno fmt --check`, `deno lint`, `deno check`, then the local stack: `supabase start`, `supabase db reset --local`, `supabase seed buckets --local`, `supabase test db --local`, and `scripts/run-api-tests` |
| Release APK build probe | builds a release APK against a disposable CI-generated keystore and verifies the APK signature matches that keystore |

The commands are the documented development commands, run with Flutter
3.47.0 (Dart 3.13.0), Deno 2.9.5, and Supabase CLI 2.111.0. A tree that was
not formatted with the same toolchain fails the formatting gates.

No Android emulator job is checked in. The three named device journeys run on
a local device; CI never claims them.

## GitHub configuration

| Name | Kind | Purpose |
| --- | --- | --- |
| `PUBLIC_API_BASE_URL` | variable | The deployed HTTPS Hono URL, injected into release builds as `--dart-define=API_BASE_URL` and validated to be an HTTPS URL ending with `/functions/v1/api` |
| `ANDROID_KEYSTORE_BASE64` | secret | The release keystore encoded as base64 |
| `ANDROID_KEYSTORE_PASSWORD` | secret | The keystore password |
| `ANDROID_KEY_ALIAS` | secret | The signing key alias |
| `ANDROID_KEY_PASSWORD` | secret | The key password |

The public API URL is a variable, not a secret: it is sent to every client
and carries no credential.

## Android release signing

`apps/expert_listing_mobile/android/app/build.gradle.kts` signs release
builds from either source, in this order:

1. `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`,
   and `keyPassword` (`storeFile` may be an absolute path or a path relative
   to `android/app`);
2. the `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` environment variables, with
   the base64 value decoded to a temporary file.

Debug builds keep debug signing and never read either source. A release build
with no signing configuration fails immediately with instructions instead of
falling back to the debug key. The repository ignores `key.properties`,
`*.jks`, and `*.keystore`; the keystore and its passwords never enter Git.

The release workflow reconstructs the keystore inside the runner's
`$RUNNER_TEMP` directory: it decodes `ANDROID_KEYSTORE_BASE64` to
`$RUNNER_TEMP/expert-listing-release.jks`, writes `android/key.properties`
pointing at that absolute path, and confirms the password with `keytool`
before building. The file lives only for the workflow run.

The CI probe instead generates a disposable keystore in `$RUNNER_TEMP` with
`keytool`, exports it through the same environment variables, and deletes
nothing from Git because nothing was written to the repository.

## Building a release APK locally

A developer with signing material outside the repository can reproduce the
release build:

~~~sh
export ANDROID_KEYSTORE_BASE64="$(base64 -i /path/to/keystore.jks | tr -d '\n')"
export ANDROID_KEYSTORE_PASSWORD=...
export ANDROID_KEY_ALIAS=...
export ANDROID_KEY_PASSWORD=...
flutter build apk --release --dart-define=API_BASE_URL=https://<project-ref>.supabase.co/functions/v1/api
~~~

Verify the signature against the keystore:

~~~sh
~/Library/Android/sdk/build-tools/<version>/apksigner verify \
  --print-certs build/app/outputs/flutter-apk/app-release.apk
~~~

The printed certificate SHA-256 digest must match the keystore's own
certificate. Compare digests with colons, spaces, and case normalized away.

## What triggers a release

Pushing a `v*` tag starts `.github/workflows/release.yml`. The workflow:

1. checks out the exact tag;
2. rejects the run when the tag does not match the application version
   (`v0.1.0` requires `version: 0.1.0+1` in `apps/expert_listing_mobile/pubspec.yaml`)
   or when `docs/releases/v0.1.0.md` is not committed — that file is the
   release body and must contain the final record before tagging;
3. installs Flutter 3.47.0 and runs the same non-device checks as CI:
   formatting, analysis, package tests, Deno checks, local Supabase
   migrations, deterministic seed, pgTAP, and the real HTTP API tests;
4. reconstructs the keystore into `$RUNNER_TEMP` as described above;
5. builds one universal release APK against `PUBLIC_API_BASE_URL`;
6. verifies the APK signature certificate matches the reconstructed keystore;
7. names the artifact `expert-listing-v0.1.0-android.apk` (the tag is spliced
   in: `expert-listing-<tag>-android.apk`);
8. writes `SHA256SUMS.txt` with `sha256sum` next to the artifact;
9. creates one GitHub Release with both assets and
   `docs/releases/v0.1.0.md` as the body, using the built-in `GITHUB_TOKEN`.

Top-level workflow permission is `contents: read`; only the release job
receives `contents: write`. No personal access token is involved. Until the
final tag is pushed, the workflow is inert.

## Preparing the final release

The release owner, after the feature and verification milestones close:

1. commit the final `docs/releases/v0.1.0.md` — product description, light and
   dark screenshots, Android install steps, backend and health URL, feature
   highlights, walkthrough link, tested device, scope notes, source commit,
   and checksum instructions;
2. set the `PUBLIC_API_BASE_URL` variable and the four Android secrets on the
   GitHub repository;
3. confirm CI is green on the release commit, including the formatting gates
   and the release APK probe;
4. push the `v0.1.0` tag;
5. wait for the release workflow to publish, then verify the published
   artifact end to end:

~~~sh
curl -L -o expert-listing-v0.1.0-android.apk <release-asset-url>
curl -L -o SHA256SUMS.txt <release-asset-url>
sha256sum -c SHA256SUMS.txt      # or: shasum -a 256 -c SHA256SUMS.txt
adb install -r expert-listing-v0.1.0-android.apk
~~~

Launch the installed app and confirm the feed loads from the hosted HTTPS
backend. A locally built APK is not equivalent evidence; only the downloaded
release artifact counts.

The release owner also owns everything this machinery deliberately does not
do: creating the real keystore and its secrets, deploying the backend and its
hosted smoke checks, the walkthrough and screenshots, and pushing the tag.
