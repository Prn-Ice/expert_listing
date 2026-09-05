# Design system

This page records measured design facts and shared UI contracts. Product scope
is defined by the [assessment specification](../spec/expert-listing-assessment.md).

Paths on this page are relative to the repository root. The implementation
lives in `packages/app_ui`. It owns visual and interaction rules that repeat
across features: semantic tokens, light and dark themes, committed assets, and
shared controls. Feature packages still own product state, content, and geometry
that appears only once.

## Start here

Import the package's public library rather than files under `lib/src`:

~~~dart
import 'package:app_ui/app_ui.dart';
~~~

When building or changing a screen:

1. Read colours from `AppColors.of(context)` and use the `AppSpacing`,
   `AppRadii`, `AppTypography`, `AppIcons`, `AppIconSize`, and `AppMotion`
   tokens.
2. Reuse a suitable shared component from the table below.
3. If no shared component fits, use Flutter's standard Material or Cupertino
   control before creating a custom control.
4. Keep one-off measured geometry in the feature widget with a descriptive
   local constant and a Figma-node comment. Add a shared token only when the
   value expresses a repeated contract.
5. Check light and dark appearances, text scaling, semantics, focus, keyboard
   insets, safe areas, and reduced motion before treating the UI as complete.

Do not put repositories, Bloc/Cubit state, API models, or feature-specific copy
in `app_ui`.

## Where to look

| Need | Source |
| --- | --- |
| Public API | `packages/app_ui/lib/app_ui.dart` |
| Light and dark themes | `packages/app_ui/lib/src/theme/app_theme.dart` |
| Colours, type, spacing, radii, icons, and motion | `packages/app_ui/lib/src/tokens/` |
| Shared controls | `packages/app_ui/lib/src/widgets/` |
| Shared wordmark, icon, and font assets | `packages/app_ui/assets/` |
| App-owned brand mark and reference images | `apps/expert_listing_mobile/assets/` |
| Feature-specific layout | `apps/expert_listing_mobile/lib/` |

## Component chooser

| Component | Use it for |
| --- | --- |
| `AppIcon` | A committed vector or raster icon with correct semantics |
| `AppIconButton` | An icon action, optionally with a count, inside a 48 by 48 logical-pixel target |
| `AppButton` | A compact labelled action using native iOS or Android press behaviour |
| `AppPressable` | A composed branded row, tile, or image that needs native press behaviour without owned layout |
| `AppScaffold` | An adaptive page surface with optional bottom navigation |
| `AppSheet` | A Cupertino or Material route with safe-area, keyboard, and dismissal handling; callers own Android scrollable content |
| `AppNotice` | One replacing, safe-area-aware transient notice |
| `OfflineStatusBar` | Persistent saved-feed provenance with an optional Retry action; the feature owns its state |
| `AppNetworkImage` | Bounded network imagery with stable loading, error, decode, and semantic behaviour |
| `AppAvatar` | A public avatar or initials fallback, with a 48-pixel target when interactive |
| `AppBrandWordmark` | The exact Expert Listing wordmark; the caller owns its action and hit target |

Ordinary buttons and fields use themed Flutter controls. In product language,
the feed entry is `CreatePostPrompt` and the opened surface is
`CreatePostSheet`; avoid the ambiguous term "composer."

## Design source and provenance

The primary reference is the Figma “iPhone 14 Plus - 1312” mobile frame at 428
logical pixels wide. Its header contains the full Expert Listing logo and
distinct mark.

Use that frame for measurements, variables, screenshots, and exact exports. The
local screenshot at
`apps/expert_listing_mobile/assets/design/[private reference removed]` is an
overlay aid, never an app asset.

Captured SVG icons live under `packages/app_ui/assets/icons/`; reference
imagery remains under `apps/expert_listing_mobile/assets/images/`.
Widgets use semantic asset names, not design-tool identifiers. Do not substitute
or redraw the committed exports.

| Semantic asset | Source file | Provenance |
| --- | --- | --- |
| Brand mark | `apps/expert_listing_mobile/assets/brand/brand-mark.svg` | User-supplied header export |
| Full wordmark | `packages/app_ui/assets/brand/expert-listing-wordmark.svg` | User-supplied header export |
| Search navigation | `packages/app_ui/assets/icons/search.svg` | Figma MagnifyingGlass export retrieved with the feed design context |
| For Sale tag | `packages/app_ui/assets/icons/for-sale.png` | Complete Figma Tag export at 4x |
| Looking to Buy tag | `packages/app_ui/assets/icons/looking-to-buy.png` | Complete Figma Tag export at 4x |
| For Rent tag | `packages/app_ui/assets/icons/for-rent.png` | Complete Figma Key export at 4x |
| Looking to Rent tag | `packages/app_ui/assets/icons/looking-to-rent.png` | Complete Figma Key export at 4x |

The four status glyphs are 48-pixel raster exports of the complete Figma
Tag/Key components. No complete vector export is obtainable for these
components, so they render as tinted rasters sized from the measured 12px
glyph geometry. Do not redraw or substitute them.

Open Runde weights 400, 500, 600, and 700 plus its OFL 1.1 licence are bundled
at `packages/app_ui/assets/fonts/open_runde/`. `app_ui` registers them as
the `Open Runde` family and intentionally provides no fallback family.

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
warm tint and 5.87:1 on the canvas, so Looking to Rent tag copy meets WCAG AA.
Revisit if the reference design publishes an accessible amber.

Light mode is the Figma target. Dark mode follows system brightness and reuses
the same semantic roles without per-widget inversion or an invented theme
selector. The dark canvas/surface are deliberately neutral-green (`#101211` /
`#1c1e1c`) so the lime brand remains recognisable without a bright launch or
sheet flash. Text-facing tag colours are lightened for dark surfaces. Contrast
is measured on the canvas unless the table names another background.

| Dark role | Value | Contrast |
| --- | --- | --- |
| Primary text | #f3f4f3 | 17.06:1 |
| Secondary text | #b9bbb9 | 9.74:1 |
| Tertiary text | #7e807e | 4.72:1 |
| Brand text | #c7ec96 | 14.21:1 |
| Accent text | #c9b8f5 | 10.44:1 |
| Warm text | #ffcf72 | 9.00:1 on warm tint |
| On-brand text | #101211 on #a8dc66 | 11.73:1 |

Contrast values use the WCAG sRGB relative-luminance formula. `AppTheme` also
sets canvas-coloured status/navigation bars with brightness-appropriate icons;
the native splash uses the same active appearance.

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
select behaviour with `context.isIos`. That app_ui extension resolves the
active `ThemeData.platform`, so tests can override the platform without using
`dart:io`; feature widgets never call `Platform.isIOS`.

## Platform behavior

The branded feed keeps the same content order and measured geometry on iOS and
Android. Platform differences are limited to interaction mechanics and native
surfaces:

| Interaction | iOS | Android |
| --- | --- | --- |
| Pull to refresh | `CupertinoSliverRefreshControl` | `RefreshIndicator` |
| Filter surface | Dismissible `CupertinoSheetRoute` | Modal Material bottom sheet |
| Filters and location | Cupertino choices and field | Material choices and field |
| Boundary notice | Replacing dismissible Cupertino alert | Replacing SnackBar |
| Full-screen media route | `CupertinoPageRoute` with edge swipe-back | `MaterialPageRoute` with system back |
| Feed return to top | Primary scroll view supports the iOS status-bar gesture | Selecting the active Feed destination returns to top |

System back, keyboard dismissal, safe areas, focus, text scaling, dark mode,
screen-reader semantics, and reduced-motion preferences remain native. Media
carousels support swiping; full-screen property media also exposes visible
Previous and Next actions so paging never requires a drag gesture.

Two deliberate exceptions preserve the product reference. The iOS filter sheet
occupies the bottom 40% rather than Cupertino's taller default because the fixed
filter set otherwise leaves excessive empty space; compressed keyboard states
scroll. Compact labelled controls retain their measured 32px minimum where the
WCAG 2.2 AA 24px target requirement is met; icon-only controls retain at least a
48 by 48 logical-pixel target. Revisit either exception if content grows, device
testing finds clipping, or a platform review requires its larger recommended
target.

The bottom navigation retains its custom measured arrangement because neither
native bar reproduces the reference's icon, label, spacing, and safe-area
geometry; each destination still exposes native button, selection, focus, and
activation semantics. The iOS notice intentionally uses a replacing Cupertino
alert because iOS has no direct SnackBar equivalent and deferred destinations
need a short, dismissible response rather than silent failure.

Keep platform adaptation at the call site until a second independent feature
needs the same presentation, dismissal, semantics, and geometry. Only then move
that complete repeated contract into app_ui; visual similarity alone is not a
reason to add another shared component.

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
repeated measurements. Keep one-off geometry as a named local constant with a
Figma-node comment.

Motion tokens remain small and explain touch feedback, state, or continuity.
Reduced-motion settings remove translation, scale, bounce, shimmer, and
repetitive animation.

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

## Native asset regeneration

Native splash and launcher rasters are generated from `brand-mark.svg` with
`resvg`. Android uses adaptive foreground, background, and monochrome layers.
iOS uses Xcode's single-size App Icon slot with light, dark, and tinted
1024-pixel appearances. The default iOS asset is opaque; its dark variant has a
transparent background, and its tinted artwork is grayscale.

This regeneration recipe is macOS-only because it uses `sips`. Run it from the
repository root with `resvg`, `sips`, and `pngcrush` available. The generated
dark mark uses the lime brand role (`#a8dc66`) in place of the source export's
deep green (`#105b48`); the tinted mark uses white:

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

Use the dark source for the Android dark splash. The adaptive icon uses the
light foreground and tinted monochrome source generated above. Android API 31+
uses the committed `drawable/splash_mark_light.xml` and
`drawable/splash_mark_dark.xml` VectorDrawables: their 432-pixel viewport
centres a 144-pixel mark so system masking cannot blur or clip it. Pre-31 uses
the 144-pixel mark directly. Downsample the 192-pixel legacy source to 144, 96,
72, and 48 pixels with `sips --resampleHeightWidth`. The commands strip unused
alpha only from the opaque default iOS asset and retain transparency for dark
and tinted variants. Validate the generated output's canvas, safe zone, and
active appearance before committing it.
