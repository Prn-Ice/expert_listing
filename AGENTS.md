# Expert Listing agent rules

These rules govern this repository. If a generic skill, template, or tool
recommendation conflicts with them, this file and the approved specification
win. Ask before changing an explicit product decision.

## Start every session

- Run bd quickstart, inspect the active bead, and follow its dependencies and
  acceptance criteria.
- Run git status --short. Preserve unrelated staged, unstaged, untracked, and
  ignored work.
- Read the full specification when context is new or stale. Otherwise read its
  authority and scope plus the sections relevant to the active bead.
- Use Beads as the only operational tracker. Temporary plans belong in ignored
  .agent/plans/, never committed docs/.
- Record new or changed scope in Beads before implementation. Do not commit,
  push, sync Beads, deploy, or change external state without current user
  authorization.

## Build simple, legible software

- Prefer direct if, for, switch, standard Flutter controls, small named
  functions, and visible sequential flow when they state the behaviour plainly.
- Use product-language names. The feature is create_post; the feed row is
  CreatePostPrompt; the opened surface is CreatePostSheet.
- Admit an abstraction only when it centralizes a repeated contract, isolates
  an external boundary, or contains a meaningful business rule—and makes its
  callers easier to read.
- Reuse a standard control or an existing app_ui component before inventing a
  widget. Never make a button from only Container and GestureDetector.
- Preserve suitable algorithms, lazy rendering, bounded work, and image sizing.
  If measured performance requires less-obvious code, isolate and document it.
- Do not copy another application's code, schema, ports, dependency constraints,
  or architecture. This repository contains the required context.

## Architecture and data

- Riverpod owns configuration and object lifecycles. Bloc/Cubit owns feature
  behaviour. Riverbloc connects them. Do not add flutter_bloc, a second state
  system, provider generation, or a service locator.
- Flutter JSON/data operations go through the Hono API. Flutter may fetch media
  only from public URLs returned by Hono; it never imports the Supabase client,
  builds Storage paths, writes tables or Storage, or contains a service-role key.
- Keep Hono thin: readable routes, small middleware, centralized safe errors,
  and plain database or Storage operations. No ORM, controller layer, or DI
  container is justified for this assessment.
- Make every database change a migration and every test dataset deterministic.
- The feed is network-first. Cached content must retain saved or stale
  provenance; only a successful first-page network feed request for the active
  filter may clear it. Never cache or silently queue mutations.

## UI and product quality

- Treat committed Figma measurements and exact assets as the visual contract.
  Do not approximate an available SVG or scatter repeated design values.
- For Figma-to-Flutter implementation or layout correction, load and follow the
  repository `figma-to-flutter-layout` skill before editing UI code.
- Keep canonical Figma references in the specification and agent guidance;
  user-facing README and wiki pages use semantic asset names and measurements,
  never Figma IDs or links.
- Choose controls in this order: reuse a suitable app_ui component; otherwise
  use the platform's standard or adaptive Flutter control; build a custom
  control only when the branded design or required behaviour cannot be
  expressed by either. Custom controls keep native semantics and feedback.
- app_ui owns repeated semantic colours, spacing, type, radii, icon and tap
  geometry, motion, and genuinely repeated controls—not app data or feature
  state.
- Light mode is the Figma reference and default. Dark mode is required and uses
  the same semantic roles. Do not add a theme selector absent from the design.
- Preserve visible Figma icon dimensions inside ordinary controls with at least
  48 by 48 logical-pixel hit regions. Adjust normal parent padding, alignment,
  and spacing to approach the design; when an exact measurement conflicts, the
  accessible target wins.
- Do not use overflow boxes, overlapping or invisible targets, custom hit
  testing, or stacked controls solely to preserve compact design geometry.
- Every visible interactive control must produce a real action, native surface,
  or short useful boundary notice. Never fake success or select an unavailable
  destination.
- Preserve retryable comment and create-post input. Roll back failed optimistic
  state. Notices are short, calm, helpful, and non-stacking.
- Prefer stable geometry, native mechanics, restrained motion, sharp imagery,
  correct keyboard and safe-area behaviour, accessibility semantics, and
  reduced motion. Never claim pixel perfection or 120 Hz without evidence.

## Tests that earn their keep

- Test user promises, race conditions, and system invariants. There is no
  coverage target and no rule to test every widget, getter, or copyWith.
- State tests replace repository boundaries, not Dio internals. Widget tests
  normally retain real provider and Bloc/Cubit wiring while overriding the
  repository. Mocked Bloc streams are only for narrow visual-state tests.
- Do not replace Hono, Postgres, Storage, durable disk persistence, or the
  required user journeys with mocks and then claim those boundaries work.
- Golden tests begin only after the current required scope is published and
  independently verified, the required journeys pass, and the manual Figma
  overlay is accepted. Until then, use valuable behaviour, semantics,
  integration, manual overlay, and named-device evidence.
- Generic skill defaults such as Widgetbook, Formz, code generation, exhaustive
  widget tests, or universal API documentation are opt-in only when an active
  requirement proves they simplify this project.

## Tooling and safety

- Before adding or upgrading a dependency, verify its current stable API and
  resolve the latest mutually compatible stable graph. Prove and lock that graph
  before relying on it.
- Use the directly installed host tools. Flutter, Android tooling, existing
  emulator assets, Xcode, and OrbStack are host-managed on macOS; Linux uses
  Docker Engine. Never add Colima.
- Nix and direnv are optional, and the current Nix setup is incomplete. They
  must never gate running, building, testing, or completing the repository.
  Optional shell entry must not start daemons, mutate data, open GUIs, or
  download emulator or system-image assets.
- Verify only the tools needed by the active work and run their commands
  directly. Require `adb` only for device or emulator work.
- Use Context7 (`ctx7` CLI or MCP) for version-sensitive APIs. Use the accepted
  Figma MCP when existing captures do not answer the design question, and record
  provenance for new measurements or exports. If either tool is unavailable
  when needed, install or configure it in the agent environment; do not add a
  repository bootstrap script.
- Never run `supabase link` without explicit current user approval. Before any
  linked mutation, read `supabase/.temp/project-ref`, require a non-empty exact
  match with `EXPECTED_SUPABASE_PROJECT_REF`, and print only that public ref.
  The only approved remote commands are `supabase db push`,
  `supabase seed buckets --linked`, and `supabase functions deploy api`.
- Never reset or delete a remote Supabase project. A local reset is allowed only
  when `supabase/config.toml` identifies `expert_listing` and
  `supabase/.temp/project-ref` is absent; use exactly
  `supabase db reset --local`, then `supabase seed buckets --local`.
- Keep secrets out of source, Flutter builds, git, logs, screenshots, videos,
  Beads notes, and release assets.
- Avoid destructive file commands. Resolve exact targets first and preserve
  recoverability.

## Documentation and completion

- The specification defines required behaviour, Beads records live work and
  evidence, and the wiki explains durable decisions and workflows. Do not
  duplicate those roles.
- Record a decision, its reason or trade-off, and its concrete revisit condition
  in concise prose.
- Document behaviour in the same change that implements it. Do not claim
  unimplemented endpoints, tests, devices, releases, or support.
- Close a bead only with exact commands, outcomes, environment, and remaining
  unverified surfaces. Designed, dry run, and verified are different states.

## Sources

- Product contract: `docs/spec/expert-listing-assessment.md`
- Documentation map: `README.md`
- Full Beads workflow: `bd prime`
