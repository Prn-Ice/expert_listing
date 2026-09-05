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
Widgets use semantic asset names, not design-tool identifiers. Do not substitute
or redraw the committed exports.

| Semantic asset | Source file | Provenance |
| --- | --- | --- |
| Brand mark | `../../apps/expert_listing_mobile/assets/brand/brand-mark.svg` | User-supplied header export |
| Full wordmark | `../../packages/app_ui/assets/brand/expert-listing-wordmark.svg` | User-supplied header export |
| Search navigation | `../../packages/app_ui/assets/icons/search.svg` | Figma MagnifyingGlass export retrieved with the feed design context |
| For Sale tag | `../../packages/app_ui/assets/icons/for-sale.png` | Complete Figma Tag export at 4x |
| Looking to Buy tag | `../../packages/app_ui/assets/icons/looking-to-buy.png` | Complete Figma Tag export at 4x |
| For Rent tag | `../../packages/app_ui/assets/icons/for-rent.png` | Complete Figma Key export at 4x |
| Looking to Rent tag | `../../packages/app_ui/assets/icons/looking-to-rent.png` | Complete Figma Key export at 4x |

The four status glyphs are 48-pixel raster exports of the complete Figma
Tag/Key components. No complete vector export is obtainable for these
components, so they render as tinted rasters sized from the measured 12px
glyph geometry. Do not redraw or substitute them.

Open Runde weights 400, 500, 600, and 700 plus its OFL 1.1 licence are bundled
at `../../packages/app_ui/assets/fonts/open_runde/`. `app_ui` registers them as
the `Open Runde` family and intentionally provides no fallback family.

Native splash and launcher rasters are generated from `brand-mark.svg` with the
dev shell's `resvg` renderer. Android uses adaptive foreground, background, and
monochrome layers. iOS uses Xcode's single-size App Icon slot with light, dark,
and tinted 1024-pixel appearances. The default iOS asset is opaque; its dark
variant has a transparent background, and its tinted artwork is grayscale, as
required by Apple's current asset-catalog guidance.

Regenerate native rasters from the repository root with the dev-shell tools.
These commands preserve the committed safe-zone geometry and write to the
committed destinations. The generated dark mark uses the existing lime brand
role (`#a8dc66`) in place of the source export's deep green (`#105b48`); the
tinted mark uses white:

~~~sh
perl -pe 's/#105B48/#A8DC66/g' apps/expert_listing_mobile/assets/brand/brand-mark.svg > /tmp/brand-mark-dark.svg
perl -pe 's/#105B48/#FFFFFF/g' apps/expert_listing_mobile/assets/brand/brand-mark.svg > /tmp/brand-mark-tinted.svg
resvg --width 144 --height 144 apps/expert_listing_mobile/assets/brand/brand-mark.svg apps/expert_listing_mobile/android/app/src/main/res/drawable-nodpi/brand_mark_light.png
resvg --width 144 --height 144 /tmp/brand-mark-dark.svg apps/expert_listing_mobile/android/app/src/main/res/drawable-nodpi/brand_mark_dark.png
resvg --width 180 --height 180 apps/expert_listing_mobile/assets/brand/brand-mark.svg /tmp/adaptive-light.png
sips --padToHeightWidth 432 432 /tmp/adaptive-light.png --out apps/expert_listing_mobile/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png
resvg --width 180 --height 180 /tmp/brand-mark-tinted.svg /tmp/adaptive-monochrome.png
sips --padToHeightWidth 432 432 /tmp/adaptive-monochrome.png --out apps/expert_listing_mobile/android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png
resvg --width 117 --height 117 apps/expert_listing_mobile/assets/brand/brand-mark.svg /tmp/legacy-light.png
sips --padToHeightWidth 192 192 /tmp/legacy-light.png --out apps/expert_listing_mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
sips --resampleHeightWidth 144 144 apps/expert_listing_mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png --out apps/expert_listing_mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
sips --resampleHeightWidth 96 96 apps/expert_listing_mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png --out apps/expert_listing_mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
sips --resampleHeightWidth 72 72 apps/expert_listing_mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png --out apps/expert_listing_mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png
sips --resampleHeightWidth 48 48 apps/expert_listing_mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png --out apps/expert_listing_mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png
resvg --width 60 --height 60 apps/expert_listing_mobile/assets/brand/brand-mark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-light.png
resvg --width 120 --height 120 apps/expert_listing_mobile/assets/brand/brand-mark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-light@2x.png
resvg --width 180 --height 180 apps/expert_listing_mobile/assets/brand/brand-mark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-light@3x.png
resvg --width 60 --height 60 /tmp/brand-mark-dark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-dark.png
resvg --width 120 --height 120 /tmp/brand-mark-dark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-dark@2x.png
resvg --width 180 --height 180 /tmp/brand-mark-dark.svg apps/expert_listing_mobile/ios/Runner/Assets.xcassets/LaunchMark.imageset/launch-mark-dark@3x.png
resvg --width 512 --height 512 apps/expert_listing_mobile/assets/brand/brand-mark.svg /tmp/app-icon-light.png
sips --padToHeightWidth 1024 1024 --padColor ffffff /tmp/app-icon-light.png --out apps/expert_listing_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
pngcrush -ow -c 2 -rem alla apps/expert_listing_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
resvg --width 512 --height 512 /tmp/brand-mark-dark.svg /tmp/app-icon-dark.png
sips --padToHeightWidth 1024 1024 /tmp/app-icon-dark.png --out apps/expert_listing_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-Dark-1024x1024@1x.png
resvg --width 512 --height 512 /tmp/brand-mark-tinted.svg /tmp/app-icon-tinted.png
sips --padToHeightWidth 1024 1024 /tmp/app-icon-tinted.png --out apps/expert_listing_mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-Tinted-1024x1024@1x.png
~~~

Use the dark source for Android dark splash and adaptive output. Android API
31+ uses the committed `drawable/splash_mark_light.xml` and
`drawable/splash_mark_dark.xml` VectorDrawables: their 432-pixel viewport
centers a 144-pixel mark so system masking cannot blur or clip it. Pre-31 uses
the 144-pixel mark directly. Downsample the 192-pixel legacy source to 144, 96,
72, and 48 pixels with `sips --resampleHeightWidth`. The commands strip unused
alpha only from the opaque default iOS asset and retain transparency for dark
and tinted variants. Validate the generated output's canvas, safe-zone, and
active appearance before commit.

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
| Info text | #1257b0 |
| Info tint | #f3f8ff |
| Accent text | #5b21b6 |
| Accent tint | #f7f3ff |
| Warm text | #8a5b00 |
| Warm tint | #fff9e5 |

Additional shared roles are border `#e8e8e8` and brand deep `#105b48`.
`#7c7c7c` is the observed light Figma tertiary colour; reserve it for
non-essential hints rather than normal small copy because it is below 4.5:1 on
white.

These values become named theme roles in app_ui; widgets do not repeat raw
colour literals.

The warm text role deliberately deepens the observed light Figma value
`#b07800`, which measures 3.6:1 on its tint. `#8a5b00` measures 5.6:1 on the
warm tint and canvas so Looking to Rent tag copy meets WCAG AA. Revisit if the
reference design publishes an accessible amber.

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
| Warm text | #ffcf72 | 9.00:1 |
| On-brand text | #101211 on #a8dc66 | 11.73:1 |

Contrast values use the WCAG sRGB relative-luminance formula. `AppTheme` also
sets canvas-coloured status/navigation bars with brightness-appropriate icons;
the native splash must use the same active appearance once the mark is
available.

## Native platform roots

`AppColors.light` and `AppColors.dark` are the single palette sources. Pure
`AppTheme` builders turn them into Material `ThemeData` and
`CupertinoThemeData`; no other theme state exists.

The application selects its native root from `defaultTargetPlatform` at the
root widget, never `Platform.isIOS`: iOS builds a `CupertinoApp` and receives
its active Cupertino theme directly; every other platform builds a
`MaterialApp` with `theme` and `darkTheme` passed directly. Tests inject the
platform through the root widgets' override parameter instead of reaching
into the tree, and the configuration-error surface follows the same policy.
The root reads the system appearance from the root view's `MediaQuery`, so a
brightness change restyles both native roots.

`CupertinoApp.builder` installs a standard Flutter `Theme` built from the
active palette and selected platform. It supplies the shared semantic
`AppColors` extension and platform lookup for the Material widgets still
hosted under the Cupertino root; it is configuration only and does not turn
Cupertino controls into Material controls.

Branded feed content keeps the committed Open Runde family and supplied
tokens under either root; genuinely native platform surfaces may use platform
typography unless the design explicitly fixes it. Subtrees below the roots
select behaviour with `Theme.of(context).platform`, never `Platform.isIOS`.

## Spacing, type, shape, and motion

Observed roles use Open Runde: caption 13/500 at 1.2 (owned locations, status
tags, and engagement counts), metadata 13/400 at 1.3, body 14/400 at 1.45, post
body 16/500 at 1.2, and title 16/500 at 1.2. The 20/600 brand role has a 1.2
line height. Bottom-navigation labels are 14px at 1.2 (weight 400 unselected
over `text-secondary`, weight 500 selected over `primary-text`), measured on
the Figma Nav frame.

Measured feed geometry: the story strip uses a 60px avatar inside its ring as a
64px-wide item with 16px separation and a 4px label gap; the header links row
pads 12px vertically around a 48px control row; the create-post prompt
insets 16px on the sides with 8px above and 12px below, and leaves a 4px gap
between its 40px avatar and hint text; the filter pill insets 24px; status-tag
pills pad 8px horizontally and 4px vertically around a 4px glyph gap.

The dashboard bottom bar uses a 0.5px hairline top border, 16px top padding,
20px side insets, 24px glyphs, an 11px glyph-to-label gap, and content anchored
to the top; the device safe-area inset supplies the space reserved for the home
indicator.

Define finite spacing, radius, border, icon, and interaction scales from
repeated measurements. Keep one-off geometry as a named local constant with its
source measurement described.

Motion tokens remain small and explain touch feedback, state, or continuity.
Reduced-motion settings remove translation, scale, bounce, shimmer, and
repetitive animation.

## Shared component contracts

Implement these only where the repeated contract is used:

- AppIcon renders committed vector and raster icons with correct semantics.
- AppIconButton preserves the Figma glyph size inside at least a 48 by 48
  logical-pixel hit region, including focus, tooltip, semantics, platform press
  feedback, and optional restrained haptic feedback.
- AppBrandWordmark owns the exact 169 by 22 Expert Listing wordmark asset;
  feature widgets own its surrounding hit target and action.
- AppSheet applies the shared design identity with current platform mechanics.
- AppNotice provides one safe-area-aware transient message and prevents queues.
- OfflineStatusBar persistently describes saved-feed provenance.
- AppNetworkImage is the only production owner of `CachedNetworkImage`; it
  derives decode dimensions from finite layout constraints and device pixel
  ratio, supports stable loading/error surfaces, reduced-motion fades, and one
  optional image semantic label.
- AppAvatar renders a 40px circular public image or initials fallback, and wraps
  an interactive avatar in a 48px semantic hit target.

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
