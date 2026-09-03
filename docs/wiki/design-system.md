# Design system

This page records measured design facts and shared UI contracts. Product scope
is defined by the [assessment specification](../spec/expert-listing-assessment.md).

## Design source and provenance

The primary reference is Figma node [private design node removed], “iPhone 14 Plus - 1312,” at 428
logical pixels wide. Header node [private design node removed] contains the full Expert Listing logo
and distinct mark.

Use that node for measurements, variables, screenshots, and exact exports. The
local screenshot at
`../../apps/expert_listing_mobile/assets/design/[private reference removed]` is an
overlay aid, never an app asset.

Captured icons live under
`../../apps/expert_listing_mobile/assets/icons/` and reference imagery under
`../../apps/expert_listing_mobile/assets/images/`. Before calling an asset
final, record its Figma node and verify the committed bytes. Widgets use
semantic asset names, not Figma IDs.

The exact brand mark, wordmark, Open Runde files in weights 400, 500, 600, and
700, and the OFL 1.1 licence must be committed before branded UI is complete.
Do not recreate unavailable assets, use google_fonts, or permit silent fallback.

## Semantic colour roles

The observed light reference currently establishes these roles:

| Role | Light value |
| --- | --- |
| Canvas | #ffffff |
| Surface | #f4f4f4 |
| Subtle surface | #00000005 |
| Primary text | #1a1a1a |
| Secondary text | #434343 |
| Tertiary text | #7c7c7c |
| Brand | #a8dc66 |
| Brand text | #4f7a1f |
| Brand tint | #f6fbef |
| Accent text | #5b21b6 |
| Accent tint | #f7f3ff |

These values become named theme roles in app_ui; widgets do not repeat raw
colour literals.

Light mode is the Figma target. Dark mode is also required, follows system
brightness, and reuses the same semantic roles without per-widget inversion or
an invented theme selector. Record the reviewed dark palette and contrast
evidence here when implemented.

## Spacing, type, shape, and motion

Observed text roles use 12, 13, 14, and 16 logical pixels with a 1.2 line
height. Record the role-to-size and weight mapping with font provenance when the
font files are committed.

Define finite spacing, radius, border, icon, and interaction scales from
repeated measurements. Keep one-off geometry as a named local constant with its
Figma node noted.

Motion tokens remain small and explain touch feedback, state, or continuity.
Reduced-motion settings remove translation, scale, bounce, shimmer, and
repetitive animation.

## Shared component contracts

Implement these only where the repeated contract is used:

- AppIcon renders an exact committed SVG with correct semantics.
- AppIconButton preserves the Figma glyph size inside at least a 48 by 48
  logical-pixel hit region, including focus, tooltip, semantics, platform press
  feedback, and optional restrained haptic feedback.
- AppSheet applies the shared design identity with current platform mechanics.
- AppNotice provides one safe-area-aware transient message and prevents queues.
- OfflineStatusBar persistently describes saved-feed provenance.

Ordinary buttons and fields use themed semantic Flutter controls. The product
feature is create_post: the feed row is CreatePostPrompt and the opened surface
is CreatePostSheet. Avoid the ambiguous term composer.

## Interaction quality

Every interactive element must perform its specified action or show the
specified boundary notice. Static metadata does not need a tap handler.

Validate stable geometry, immediate feedback, sharp imagery, keyboard and
safe-area behaviour, accessibility semantics, and restrained motion. Do not add
blur, glass effects, pervasive shimmer, parallax, or tap haptics without a
specific requirement.

Notices contain one plain sentence, do not stack, do not expose raw exceptions,
and do not announce success already visible on screen.

## Validation

Before release, record:

- a 428-pixel light-mode screenshot overlay;
- one 360-logical-pixel clipping and overflow check;
- complete feed and core-sheet dark-mode screenshots at 428 and 360 logical
  pixels;
- system appearance transition behaviour;
- icon family, stroke, spacing, typography, radii, and image ratio checks;

Filter, comments, and create-post sheets are not supplied in Figma. Their
restrained platform-appropriate design is an explicit assumption and must reuse
the shared tokens.

Use manual overlays plus behaviour and semantics tests for assessment evidence.
