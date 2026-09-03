# Design system

This page records measured design facts and shared UI contracts. Product scope
is defined by the [assessment specification](../spec/expert-listing-assessment.md).

## Design source and provenance

The primary reference is the Figma “iPhone 14 Plus - 1312” mobile frame at 428
logical pixels wide. Its header contains the full Expert Listing logo and
distinct mark.

Use that frame for measurements, variables, screenshots, and exact exports. The
local screenshot at
`../../apps/expert_listing_mobile/assets/design/[private reference removed]` is an
overlay aid, never an app asset.

Captured SVG icons live under `../../packages/app_ui/assets/icons/`; reference
imagery remains under `../../apps/expert_listing_mobile/assets/images/`.
Widgets use semantic asset names, not Figma IDs. Figma MCP reached its
Starter-plan call limit on 2026-09-03, so the user manually supplied the exact
brand exports below; do not substitute or redraw them.

| Semantic asset | Source file | Provenance |
| --- | --- | --- |
| Brand mark | `../../apps/expert_listing_mobile/assets/brand/brand-mark.svg` | User-supplied header export |
| Full wordmark | `../../apps/expert_listing_mobile/assets/brand/expert-listing-wordmark.svg` | User-supplied header export |

Open Runde weights 400, 500, 600, and 700 plus its OFL 1.1 licence are bundled
at `../../packages/app_ui/assets/fonts/open_runde/`. `app_ui` registers them as
the `Open Runde` family and intentionally provides no fallback family.

Native splash and launcher rasters are generated from `brand-mark.svg` with the
dev shell's `resvg` renderer; `pngcrush` removes the unused alpha channel only
from Apple's required opaque light App Icon. Android uses adaptive foreground,
background, and monochrome layers. iOS uses Xcode's single-size App Icon slot
with light, dark, and tinted 1024-pixel appearances.

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

Additional shared roles are border `#e8e8e8`, brand deep `#105b48`, warm text
`#655143`, and warm tint `#f2efe3`. `#7c7c7c` is the observed light Figma
tertiary colour; reserve it for non-essential hints rather than normal small
copy because it is below 4.5:1 on white.

These values become named theme roles in app_ui; widgets do not repeat raw
colour literals.

Light mode is the Figma target. Dark mode follows system brightness and reuses
the same semantic roles without per-widget inversion or an invented theme
selector. The dark canvas/surface are deliberately neutral-green (`#101211` /
`#1c1e1c`) so the lime brand remains recognisable without a bright launch or
sheet flash. Text-facing tag colours are lightened for dark surfaces.

| Dark role | Value | Contrast on canvas |
| --- | --- | --- |
| Primary text | #f3f4f3 | 17.06:1 |
| Secondary text | #b9bbb9 | 9.74:1 |
| Tertiary text | #7e807e | 4.72:1 |
| Brand text | #c7ec96 | 14.21:1 |
| Accent text | #c9b8f5 | 10.44:1 |
| Warm text | #d8c4a8 | 11.09:1 |
| On-brand text | #101211 on #a8dc66 | 11.73:1 |

Contrast values use the WCAG sRGB relative-luminance formula. `AppTheme` also
sets canvas-coloured status/navigation bars with brightness-appropriate icons;
the native splash must use the same active appearance once the mark is
available.

## Spacing, type, shape, and motion

Observed roles use Open Runde: caption 12/500 at 1.25, metadata 13/400 at 1.3,
body 14/400 at 1.45, and title 16/600 at 1.25. The 20/600 brand role has a 1.2
line height. These measurements came from the committed 428-pixel overlay aid
and need Figma re-verification when access returns.

Define finite spacing, radius, border, icon, and interaction scales from
repeated measurements. Keep one-off geometry as a named local constant with its
source measurement described.

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
