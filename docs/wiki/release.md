# Release

This runbook covers the required Android GitHub Release and the owner-approved,
optional TestFlight delivery channel. The assessment specification remains the
authority: App Store publication is out of scope, and TestFlight never replaces
or blocks the signed Android release.

## Release gate

`.github/workflows/ci.yml` runs for pushes to `main` and pull requests. It is
also called by both release workflows before they build an artifact.

| Job | Evidence |
| --- | --- |
| Flutter and Dart checks | Enforced mobile and `app_ui` lockfiles, formatting, analysis, and tests |
| Hono and Supabase checks | Enforced Deno lockfile, formatting, lint, frozen type-checking, local migrations, deterministic seed, pgTAP, and real API tests |
| Release APK build probe | A disposable keystore signs a release APK; its signer digest must match the generated keystore |

The probe intentionally has no deployed API URL. It proves that a release APK
can be built and signed, not that a hosted backend works at runtime. CI does not
run the required named-device journeys; those remain separately required
evidence.

## Android GitHub configuration

| Name | Kind | Purpose |
| --- | --- | --- |
| `PUBLIC_API_BASE_URL` | repository variable | Required only for artifact release builds; it must exactly equal `https://chvhwausefhvaceygppc.supabase.co/functions/v1/api` |
| `ANDROID_KEYSTORE_BASE64` | `android-release` environment secret | Release keystore encoded as base64 |
| `ANDROID_KEYSTORE_PASSWORD` | `android-release` environment secret | Keystore password |
| `ANDROID_KEY_ALIAS` | `android-release` environment secret | Signing key alias |
| `ANDROID_KEY_PASSWORD` | `android-release` environment secret | Key password |

The `release` job references `android-release`; reusable CI and `release-gate`
jobs do not. `PUBLIC_API_BASE_URL` stays a shared repository variable because it
is public configuration used by both artifact jobs. They reject any other value
so a signed build cannot target a lookalike or unrelated hosted API.

## Android signing

Gradle reads only ignored `android/key.properties` with `storeFile`,
`storePassword`, `keyAlias`, and `keyPassword`. Release builds fail closed when
any value is missing; debug builds keep their normal debug signing.

CI reconstructs the secret keystore in `$RUNNER_TEMP`, writes that ignored file
for the current runner, and removes both after the job. The disposable CI probe
uses the same `key.properties` contract with a generated temporary keystore.

For a local build, work from the mobile app directory and point the ignored file
at signing material outside Git:

~~~sh
cd apps/expert_listing_mobile
cat > android/key.properties <<'EOF'
storeFile=/absolute/path/to/expert-listing-release.jks
storePassword=...
keyAlias=...
keyPassword=...
EOF
flutter pub get --enforce-lockfile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://chvhwausefhvaceygppc.supabase.co/functions/v1/api
~~~

Verify the APK and obtain the matching keystore digest:

~~~sh
~/Library/Android/sdk/build-tools/<version>/apksigner verify \
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
matching profile at Xcode's current user profile directory only for the job. It
passes `DEVELOPMENT_TEAM`, manual signing, Apple Distribution, and the decoded
profile name through Flutter's `FLUTTER_XCODE_` build-setting bridge. The `.p8`,
`.p12`, and profile stay in `$RUNNER_TEMP` or the temporary keychain and are
removed by an `always()` cleanup step. No IPA artifact is retained automatically.

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

Use **Actions → TestFlight → Run workflow** from the intended commit. It is
`workflow_dispatch` only; merges and Android release tags cannot upload iOS
builds. The workflow waits for the reusable release gate and serializes uploads.
Its run number becomes `CFBundleVersion`; start a new dispatch instead of
rerunning an upload that may have reached App Store Connect.

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

## Final verification checklist

1. Before the required Android release, confirm the reusable gate is green,
   `docs/releases/v0.1.0.md` is committed, the exact API variable and Android
   secrets are configured, then push only the `v0.1.0` tag. The workflow creates
   the named APK and `SHA256SUMS.txt` with the built-in GitHub token.
2. Download the published APK, verify its checksum, install it, and launch it
   against the hosted API. A locally built APK is not equivalent release evidence.
3. If optional TestFlight delivery is used, complete the Apple steps above and
   record signed-build, processing, tester assignment, installation, and launch
   evidence separately. App Store publication remains out of scope.
