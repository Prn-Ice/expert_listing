# Release

This runbook covers the required Android GitHub Release and the owner-approved,
optional TestFlight delivery channel. The assessment specification remains the
authority: App Store publication is out of scope, and TestFlight never replaces
or blocks the signed Android release.

## Release lineage

`v0.1.0` is the immutable release delivered for the assessment review. Its
curated record remains at `docs/releases/v0.1.0.md`; it is historical evidence,
not a template or gate for later releases. Subsequent versions are follow-up
improvements.

The Android Release and TestFlight workflows listen for `v*` tags and reject a
tag that does not match the application version. Android generates release notes
from GitHub history and does not require a matching file under `docs/releases/`.
For a later release:

1. Update and verify the application version.
2. Tag the intended commit as `v<version>`.
3. Push the tag and monitor both the **Release** and **TestFlight** workflows.

## Release gate

`.github/workflows/ci.yml` runs for pushes to `main` and pull requests. It is
also called by both release workflows before they build an artifact.

| Job | Evidence |
| --- | --- |
| Flutter and Dart checks | Enforced mobile and `app_ui` lockfiles, formatting, analysis, and tests |
| Hono and Supabase checks | Enforced Deno lockfile, formatting, lint, frozen type-checking, local migrations, deterministic seed, pgTAP, and real API tests |
| Release APK build probe | A disposable keystore signs a release APK configured against the verified hosted API; its signer digest must match the generated keystore |

The probe uses the same verified public hosted API URL as an artifact release,
so its preserved APK can launch normally. It remains non-distributable because
its signature is disposable, and it does not prove hosted runtime behavior. CI
does not run the required named-device journeys; those remain separately
required evidence.

## Android GitHub configuration

| Name | Kind | Purpose |
| --- | --- | --- |
| `PUBLIC_API_BASE_URL` | repository variable | Required for Android probe and release artifacts; it must exactly equal `https://chvhwausefhvaceygppc.supabase.co/functions/v1/api` |
| `ANDROID_KEYSTORE_BASE64` | `android-release` environment secret | Release keystore encoded as base64 |
| `ANDROID_KEYSTORE_PASSWORD` | `android-release` environment secret | Keystore password |
| `ANDROID_KEY_ALIAS` | `android-release` environment secret | Signing key alias |
| `ANDROID_KEY_PASSWORD` | `android-release` environment secret | Key password |

The `release` job references `android-release`; reusable CI and `release-gate`
jobs do not. `PUBLIC_API_BASE_URL` stays a shared repository variable because it
is public configuration used by both Android artifact jobs. They reject any
other value so a signed build cannot target a lookalike or unrelated hosted API.

## Android signing

Gradle reads only ignored `android/key.properties` with `storeFile`,
`storePassword`, `keyAlias`, and `keyPassword`. Release builds fail closed when
any value is missing; debug builds keep their normal debug signing.

CI reconstructs the secret keystore in `$RUNNER_TEMP`, writes that ignored file
for the current runner, and removes both after the job. The disposable CI probe
uses the same `key.properties` contract with a generated temporary keystore.

For a local build, create ignored `apps/expert_listing_mobile/android/key.properties`
with restrictive permissions. Use an editor or secure automation that does not
place secret values in shell history:

~~~properties
storeFile=/absolute/path/to/expert-listing-release.jks
storePassword=<secret>
keyAlias=<key-alias>
keyPassword=<secret>
~~~

Then build from the mobile app directory:

~~~sh
cd apps/expert_listing_mobile
chmod 600 android/key.properties
flutter pub get --enforce-lockfile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://chvhwausefhvaceygppc.supabase.co/functions/v1/api
~~~

Set `ANDROID_SDK_ROOT` to the directly installed Android SDK. Verify the APK and
obtain the matching keystore digest:

~~~sh
"$ANDROID_SDK_ROOT/build-tools/<version>/apksigner" verify \
  --print-certs build/app/outputs/flutter-apk/app-release.apk
keytool -list -v -keystore /absolute/path/to/expert-listing-release.jks \
  -alias <key-alias> | sed -n 's/.*SHA256: //p'
~~~

The repository ignores `key.properties`, `*.jks`, and `*.keystore`; neither the
keystore nor its passwords enters Git.

## TestFlight GitHub configuration

| Name | Kind | Purpose |
| --- | --- | --- |
| `PUBLIC_API_BASE_URL` | repository variable | Must exactly equal the canonical deployed API URL above |
| `APPLE_TEAM_ID` | `testflight` environment variable | Apple Developer team ID; it must match the App Store profile |
| `APP_STORE_CONNECT_KEY_ID` | `testflight` environment secret | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | `testflight` environment secret | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `testflight` environment secret | Full downloaded `.p8` contents |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | `testflight` environment secret | Base64 Apple Distribution `.p12` with its private key |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | `testflight` environment secret | `.p12` password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `testflight` environment secret | Base64 explicit App Store `.mobileprovision` for `com.prnice.expertListing` |

The `upload` job references `testflight`; the reusable CI and `release-gate`
jobs do not receive Apple signing or upload credentials.

The Apple Distribution certificate and App Store profile sign the archive. The
App Store Connect API key only authorizes `altool` validation and upload; it
cannot sign code or replace the certificate/profile pair.

The workflow imports an Apple Distribution identity into a temporary keychain,
rejects profiles with debugging enabled or registered devices, and installs the
matching profile at Xcode's current user profile directory only for the job.
The Xcode Release configuration owns manual signing and the Apple Distribution
identity. The workflow supplies the team through
`FLUTTER_XCODE_DEVELOPMENT_TEAM` and the decoded profile name through
`RUNNER_PROVISIONING_PROFILE_SPECIFIER`. The `.p8`, `.p12`, and profile stay in
`$RUNNER_TEMP` or the temporary keychain and are removed by an `always()` cleanup
step. No IPA artifact is retained automatically.

## One-time Apple setup

1. Register or confirm the explicit App ID `com.prnice.expertListing` under the
   intended Apple Developer team.
2. Create the matching App Store Connect app record and complete required app
   metadata, agreements, and access.
3. Set the developer team ID as the `testflight` environment variable
   `APPLE_TEAM_ID` and create an App Store Connect API key with the least Apple
   role that permits build uploads.
4. Export a password-protected Apple Distribution `.p12` with its private key.
5. Create an explicit App Store profile for that bundle ID and certificate. It
   must have `get-task-allow` set to false and no device list.
6. Add the table's values to the named environments; only
   `PUBLIC_API_BASE_URL` is a shared repository variable. Apple offers the API
   private key for download once; keep no credential file in Git.
7. Complete TestFlight test information, export-compliance requirements, and the
   intended tester group in App Store Connect.

## TestFlight upload and states

Every `v*` tag triggers TestFlight delivery after the reusable release gate.
Merges do not upload iOS builds. **Actions → TestFlight → Run workflow** remains
available for an explicit retry or delivery from an intended commit. Uploads are
serialized, and each run number becomes `CFBundleVersion`; start a new dispatch
instead of rerunning an upload that may have reached App Store Connect.

| State | Meaning |
| --- | --- |
| Upload completed | CI and `altool` accepted the signed IPA. Apple processing has started. |
| Processing completed | The build appears under **App Store Connect → TestFlight → Builds** without a processing state or failure. |
| Internal testing available | Required compliance work is complete and the build is assigned to the internal tester group. |
| External testing available | The external group is configured and Beta App Review has passed when Apple requires it. |

A green workflow proves upload completion only. Do not claim TestFlight
verification until the build is processed, assigned to testers, installed, and
launched. Check export compliance and Beta App Review where applicable.

| Symptom | Check first |
| --- | --- |
| No valid signing identity or codesign error | The `.p12` must include its private key and an Apple Distribution identity for the profile's team. |
| Profile, team, or bundle mismatch | Recreate the explicit App Store profile for `com.prnice.expertListing` and `APPLE_TEAM_ID`. |
| Profile rejected before archive | Use an App Store profile with `get-task-allow` false and no registered devices. |
| API-key authentication error | Confirm key ID, issuer ID, `.p8` text, key status, and access to the app record. |
| Duplicate or rejected build number | Start a new workflow dispatch; do not reuse an accepted number. |
| Successful upload but no tester install | Check processing, export compliance, TestFlight information, group assignment, and Beta App Review. |

## Post-publication verification

For each delivery release, download the published APK and `SHA256SUMS.txt`,
verify the checksum and signing certificate, install that downloaded APK, and
launch it against the hosted API. Record the exact tag, artifact name, checksum,
device, and outcome in the release evidence. A locally built APK is not
equivalent evidence.

If optional TestFlight delivery is used, record signed-build upload, processing,
tester assignment, installation, and launch evidence separately. A green upload
workflow proves only that App Store Connect accepted the upload. App Store
publication remains out of scope.
