# Expert Listing Flutter app

This directory contains the Flutter client. It is currently a foundation
scaffold; feed features are not yet implemented, and device journeys are not
yet verified.

The approved architecture uses Riverpod for dependency lifecycles, Bloc/Cubit
for feature behaviour, and Riverbloc to connect them. JSON requests and
mutations go through Hono; media may be fetched only from public URLs returned
by Hono. Flutter does not access Supabase directly.

Run commands from the repository root. See
[development.md](../../docs/wiki/development.md) for setup,
[expert-listing-assessment.md](../../docs/spec/expert-listing-assessment.md) for
required behaviour, and [architecture.md](../../docs/wiki/architecture.md) for
ownership boundaries.
