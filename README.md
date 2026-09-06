# Expert Listing

Expert Listing is a Flutter mobile experience for browsing and discussing Lagos
real-estate posts. A thin Hono API serves relational PostgreSQL data and public
media from Supabase.

## Try it

- [Download Expert Listing v0.2.1 for Android](https://github.com/Prn-Ice/expert_listing/releases/tag/v0.2.1), including the signed APK and checksum.
- Watch the assessment [Android walkthrough](https://github.com/Prn-Ice/expert_listing/releases/download/v0.1.0/recording-android.webm) or [iOS walkthrough](https://github.com/Prn-Ice/expert_listing/releases/download/v0.1.0/recording-ios.mov).
- Check the [hosted API health endpoint](https://chvhwausefhvaceygppc.supabase.co/functions/v1/api/health).

`v0.2.1` contains the expanded assessment scope: the network-first feed,
filters, post creation with ordered property images, persistent likes and
comments, foreground activity notifications, sharing, local bookmarks,
property search and listings, profiles, and light and dark appearances.
`v0.1.0` remains the immutable original assessment-review release.

## Run the app

Flutter, Xcode, and the Android toolchain are installed directly on the
development machine. Nix and direnv are optional; the current Nix setup is
incomplete and is not a prerequisite.

~~~sh
cd apps/expert_listing_mobile
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=https://chvhwausefhvaceygppc.supabase.co/functions/v1/api
~~~

See [Development](docs/wiki/development.md) for the toolchain, Beads project
tracking, backend, test, and device workflows.

## Project documentation

- [Assessment specification](docs/spec/expert-listing-assessment.md): required
  product behaviour and delivery contract.
- [Architecture](docs/wiki/architecture.md): ownership and data flow.
- [API and data](docs/wiki/api-and-data.md): HTTP routes, relational schema, and
  media boundaries.
- [Database schema](docs/wiki/supabase-schema-chvhwausefhvaceygppc.png): visual
  overview of the Supabase relational schema.
- [Design system](docs/wiki/design-system.md): Figma measurements, assets, and
  shared UI contracts.
- [Offline and cache](docs/wiki/offline-and-cache.md): network-first reads and
  saved-feed provenance.
- [Decisions](docs/wiki/decisions.md): durable architectural trade-offs.
- [Release runbook](docs/wiki/release.md): CI, signing, and delivery workflows.
- [v0.1.0 review release](docs/releases/v0.1.0.md): assessment-submission scope
  and evidence.
- [Deferred roadmap](docs/wiki/roadmap.md): explicitly postponed work.
