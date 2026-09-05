import 'dart:math' show max, min, pow, sqrt;
import 'dart:ui' show Tristate, instantiateImageCodec;

import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget harness(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppTheme', () {
    test('light and dark themes share the Open Runde family', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
      expect(dark.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
      expect(AppTypography.fontFamily, contains('Open Runde'));
    });

    test('light and dark themes carry the same semantic roles', () {
      final lightColors = AppTheme.light().extension<AppColors>()!;
      final darkColors = AppTheme.dark().extension<AppColors>()!;

      // Same roles, different values: identity roles stay stable.
      expect(lightColors.brand, darkColors.brand);
      expect(lightColors.canvas, isNot(darkColors.canvas));
      expect(lightColors.textPrimary, isNot(darkColors.textPrimary));
      expect(lightColors.accentTint, isNot(darkColors.accentTint));
    });

    test('themed surfaces and system bars follow their active roles', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.colorScheme.surface, AppColors.light.surface);
      expect(dark.colorScheme.surface, AppColors.dark.surface);
      expect(light.colorScheme.tertiary, AppColors.light.accent);
      expect(dark.colorScheme.tertiary, AppColors.dark.accent);
      expect(light.colorScheme.outlineVariant, AppColors.light.border);
      expect(dark.colorScheme.outlineVariant, AppColors.dark.border);
      expect(light.bottomSheetTheme.backgroundColor, AppColors.light.canvas);
      expect(dark.bottomSheetTheme.backgroundColor, AppColors.dark.canvas);
      expect(
        light.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        dark.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        light.appBarTheme.systemOverlayStyle?.statusBarBrightness,
        Brightness.light,
      );
      expect(
        dark.appBarTheme.systemOverlayStyle?.statusBarBrightness,
        Brightness.dark,
      );
    });

    test('subtle light surface preserves the documented alpha', () {
      expect(AppColors.light.subtleSurface, const Color(0x05000000));
    });

    test('the Cupertino themes are built from the shared palettes', () {
      final light = AppTheme.cupertino(Brightness.light);
      final dark = AppTheme.cupertino(Brightness.dark);

      expect(light.scaffoldBackgroundColor, AppColors.light.canvas);
      expect(dark.scaffoldBackgroundColor, AppColors.dark.canvas);
      expect(light.primaryColor, AppColors.light.brand);
      expect(dark.primaryColor, AppColors.dark.brand);
      expect(light.textTheme.textStyle.fontFamily, AppTypography.fontFamily);
    });

    test('the material helper selects brightness and platform', () {
      final light = AppTheme.material(
        Brightness.light,
        platform: TargetPlatform.iOS,
      );
      final dark = AppTheme.material(
        Brightness.dark,
        platform: TargetPlatform.iOS,
      );

      expect(light.platform, TargetPlatform.iOS);
      expect(dark.platform, TargetPlatform.iOS);
      expect(light.extension<AppColors>(), AppColors.light);
      expect(dark.extension<AppColors>(), AppColors.dark);
    });
  });

  group('AppIconButton', () {
    testWidgets('keeps the measured glyph inside a 48x48 hit region', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          AppIconButton(
            icon: AppIcons.heart,
            tooltip: 'Like',
            iconSize: AppIconSize.small,
            onPressed: () => taps++,
          ),
        ),
      );

      final region = tester.getSize(find.byType(AppIconButton));
      expect(region.width, AppIconSize.tapTarget);
      expect(region.height, AppIconSize.tapTarget);

      // The visible glyph keeps its measured size.
      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.size, AppIconSize.small);

      // Tapping the edge of the region still activates the control.
      await tester.tapAt(tester.getTopLeft(find.byType(AppIconButton)));
      expect(taps, 1);
    });

    testWidgets('exposes tooltip and button semantics', (tester) async {
      await tester.pumpWidget(
        harness(
          AppIconButton(
            icon: AppIcons.bookmark,
            tooltip: 'Bookmark',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byTooltip('Bookmark'), findsOneWidget);
      final semantics = tester.getSemantics(find.bySemanticsLabel('Bookmark'));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
    });

    testWidgets('disabled state announces itself', (tester) async {
      await tester.pumpWidget(
        harness(
          const AppIconButton(
            icon: AppIcons.share,
            tooltip: 'Share',
            onPressed: null,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.bySemanticsLabel('Share'));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('iOS control receives focus and activates from the keyboard', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var taps = 0;

      try {
        await tester.pumpWidget(
          harness(
            AppIconButton(
              icon: AppIcons.filter,
              tooltip: 'Filter',
              onPressed: () => taps++,
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        expect(taps, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('native interaction boundaries', () {
    // Only these focused boundary tests assert concrete native control
    // types; behaviour tests stay on semantics and user actions.
    Future<void> pumpPlatform(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(harness(child));
      await tester.pump();
    }

    testWidgets('AppIconButton picks the real control family', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpPlatform(
          tester,
          AppIconButton(
            icon: AppIcons.heart,
            tooltip: 'Like',
            onPressed: () {},
          ),
        );
        expect(find.byType(CupertinoButton), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await pumpPlatform(
          tester,
          AppIconButton(
            icon: AppIcons.heart,
            tooltip: 'Like',
            onPressed: () {},
          ),
        );
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byType(CupertinoButton), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('AppButton picks the real control family', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpPlatform(
          tester,
          AppButton(onPressed: () {}, child: const Text('Retry')),
        );
        expect(find.byType(CupertinoButton), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await pumpPlatform(
          tester,
          AppButton(onPressed: () {}, child: const Text('Retry')),
        );
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.byType(CupertinoButton), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('AppPressable picks the real control family', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpPlatform(
          tester,
          AppPressable(
            color: AppColors.light.subtleSurface,
            borderRadius: AppRadii.pill,
            onPressed: () {},
            child: const Text('surface'),
          ),
        );
        expect(find.byType(CupertinoButton), findsOneWidget);
        expect(find.byType(InkResponse), findsNothing);
        final button = tester.widget<CupertinoButton>(
          find.byType(CupertinoButton),
        );
        expect(button.color, AppColors.light.subtleSurface);
        expect(button.borderRadius, AppRadii.pill);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await pumpPlatform(
          tester,
          AppPressable(onPressed: () {}, child: const Text('surface')),
        );
        expect(find.byType(InkResponse), findsOneWidget);
        expect(find.byType(CupertinoButton), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('AppPressable keeps corner taps on rounded surfaces', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 56,
            child: AppPressable(
              color: AppColors.light.subtleSurface,
              borderRadius: AppRadii.pill,
              onPressed: () => taps++,
              child: const Text('Prompt'),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(AppPressable));
      await tester.tapAt(rect.topLeft + const Offset(1, 1));
      expect(taps, 1, reason: 'a shaped surface never rejects corner taps');
    });

    testWidgets('AppScaffold picks the native page surface', (tester) async {
      const scaffold = AppScaffold(
        body: Text('body'),
        bottomNavigationBar: Text('bar'),
      );
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: scaffold),
        );
        expect(find.byType(CupertinoPageScaffold), findsOneWidget);
        expect(find.byType(Scaffold), findsNothing);
        expect(find.text('body'), findsOneWidget);
        expect(find.text('bar'), findsOneWidget);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: scaffold),
        );
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(CupertinoPageScaffold), findsNothing);
        expect(find.text('body'), findsOneWidget);
        expect(find.text('bar'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('AppIcon', () {
    testWidgets('does not inherit a branded ambient icon colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          IconTheme(
            data: IconThemeData(color: AppColors.light.brand),
            child: const AppIcon(AppIcons.heart),
          ),
        ),
      );

      final icon = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        icon.colorFilter,
        ColorFilter.mode(AppColors.light.textPrimary, BlendMode.srcIn),
      );
    });
  });

  group('AppNetworkImage and AppAvatar', () {
    testWidgets('derives a 40px decode target from finite constraints', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: harness(
            const SizedBox(
              width: 40,
              height: 40,
              child: AppNetworkImage(
                imageUrl: 'https://images.example/avatar.jpg',
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.memCacheWidth, 80);
      expect(image.memCacheHeight, 80);
    });

    testWidgets('derives both rectangular decode axes from layout and DPR', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: harness(
            const SizedBox(
              width: 160,
              height: 90,
              child: AppNetworkImage(
                imageUrl: 'https://images.example/property.jpg',
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.memCacheWidth, 320);
      expect(image.memCacheHeight, 180);
    });

    testWidgets('uses a 40px initials fallback when no avatar URL exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppAvatar(imageUrl: null, displayName: 'Ada Doe')),
      );

      expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
      expect(find.text('AD'), findsOneWidget);
    });

    testWidgets('gives an interactive avatar a genuine 48px hit region', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          AppAvatar(
            imageUrl: null,
            displayName: 'Ada Doe',
            onPressed: () => taps++,
          ),
        ),
      );

      final region = tester.getSize(find.byType(TextButton));
      expect(region, const Size(48, 48));
      await tester.tapAt(tester.getTopLeft(find.byType(TextButton)));
      expect(taps, 1);
    });

    testWidgets('removes image fades when reduced motion is requested', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: harness(
            const SizedBox.square(
              dimension: 40,
              child: AppNetworkImage(
                imageUrl: 'https://images.example/avatar.jpg',
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.fadeInDuration, Duration.zero);
      expect(image.fadeOutDuration, Duration.zero);
      expect(image.placeholderFadeInDuration, Duration.zero);
    });

    testWidgets('exposes one image semantic label', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          harness(
            const SizedBox.square(
              dimension: 40,
              child: AppNetworkImage(
                imageUrl: 'https://images.example/property.jpg',
                semanticLabel: 'Property photo 1 of 2',
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Property photo 1 of 2'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('AppBrandWordmark', () {
    testWidgets('keeps the committed 169 by 22 visual geometry', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const AppBrandWordmark()));

      expect(
        tester.getSize(find.byType(AppBrandWordmark)),
        const Size(169, 22),
      );
    });
  });

  group('AppSheet', () {
    testWidgets('protects bottom actions from keyboard and device insets', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: harness(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.show<void>(
                  context,
                  child: const SizedBox(height: 48),
                ),
                child: const Text('Show sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea).last);
      expect(safeArea.top, isFalse);
      expect(safeArea.minimum.bottom, 300);
    });

    testWidgets('uses the requested compact iOS presentation', (tester) async {
      final observer = _PushedRouteObserver();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AppSheet.show<void>(
                    context,
                    cupertinoTopGap: 0.5,
                    child: const SizedBox(height: 48),
                  ),
                  child: const Text('Show compact sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show compact sheet'));
        await tester.pumpAndSettle();

        final route = observer.lastPushed;
        expect(route, isA<CupertinoSheetRoute<void>>());
        expect((route! as CupertinoSheetRoute<void>).topGap, 0.5);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('AppNotice', () {
    testWidgets('a second notice replaces the first instead of stacking', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => AppNotice.show(context, 'First notice.'),
                  child: const Text('show'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final context = tester.element(find.text('show'));
      AppNotice.show(context, 'Second notice.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('First notice.'), findsNothing);
      expect(find.text('Second notice.'), findsOneWidget);
    });

    testWidgets('iOS answers with the restrained native dialog', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => AppNotice.show(
                      context,
                      'Search is not part of this preview.',
                    ),
                    child: const Text('show'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('show'));
        await tester.pumpAndSettle();
        expect(
          find.text('Search is not part of this preview.'),
          findsOneWidget,
        );

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(
          find.text('Search is not part of this preview.'),
          findsNothing,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('OfflineStatusBar', () {
    testWidgets('renders provenance text and an optional retry action', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: OfflineStatusBar(
              message: 'Showing saved posts.',
              onRetry: () => retries++,
            ),
          ),
        ),
      );

      expect(find.text('Showing saved posts.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(OfflineStatusBar),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, AppColors.dark.surface);
    });

    testWidgets('the strip is 40px tall with the 32px retry control', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OfflineStatusBar(
              message: 'Showing saved posts.',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(OfflineStatusBar)).height, 40);
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        AppIconSize.textButtonTapTarget,
      );
    });
  });

  group('semantic colour contrast', () {
    double contrastRatio(Color foreground, Color background) {
      final lighter = max(
        foreground.computeLuminance(),
        background.computeLuminance(),
      );
      final darker = min(
        foreground.computeLuminance(),
        background.computeLuminance(),
      );
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('the composer-hint foreground meets AA on its surfaces', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final appearance = colors == AppColors.light ? 'light' : 'dark';
        expect(
          contrastRatio(colors.textSecondary, colors.canvas),
          greaterThanOrEqualTo(4.5),
          reason: 'hint copy on canvas must stay readable ($appearance)',
        );
        expect(
          contrastRatio(colors.textSecondary, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('every status-tag foreground meets AA on its tint', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final pairs = [
          (colors.info, colors.infoTint, 'For Sale'),
          (colors.brandText, colors.brandTint, 'For Rent'),
          (colors.accent, colors.accentTint, 'Looking to Buy'),
          (colors.warm, colors.warmTint, 'Looking to Rent'),
        ];
        for (final (foreground, background, label) in pairs) {
          expect(
            contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$label tag copy must stay readable',
          );
        }
      }
    });
  });

  group('status icon assets', () {
    // A complete Figma tag/key glyph fills nearly the whole 48px export;
    // the lone inner Vector dot spans a fraction of the canvas.
    const minimumGlyphSpan = 30.0;
    const minimumInkedPixels = 200;

    const statusAssets = <String, Color>{
      AppIcons.postTag: Color(0xff1257b0),
      AppIcons.lookingToBuyTag: Color(0xff5b21b6),
      AppIcons.propertyRentKey: Color(0xff4f7a1f),
      AppIcons.lookingToRentKey: Color(0xffb07800),
    };

    test(
      'each committed glyph fills its canvas with its design colour',
      () async {
        for (final entry in statusAssets.entries) {
          final data = await rootBundle.load('packages/app_ui/${entry.key}');
          final codec = await instantiateImageCodec(data.buffer.asUint8List());
          final frame = await codec.getNextFrame();
          final width = frame.image.width;
          final height = frame.image.height;
          final bytes = await frame.image.toByteData();
          frame.image.dispose();
          codec.dispose();
          expect(bytes, isNotNull, reason: '${entry.key} must decode');
          final pixels = bytes!.buffer.asUint8List();

          // The new component colour model exposes 0..1 channels.
          final targetR = entry.value.r * 255;
          final targetG = entry.value.g * 255;
          final targetB = entry.value.b * 255;
          var minX = width.toDouble();
          var minY = height.toDouble();
          var maxX = 0.0;
          var maxY = 0.0;
          var inked = 0;
          var colourDistance = double.infinity;
          for (var offset = 0; offset < pixels.length; offset += 4) {
            final alpha = pixels[offset + 3];
            if (alpha <= 16) continue;
            inked++;
            final index = offset ~/ 4;
            final x = (index % width).toDouble();
            final y = (index ~/ width).toDouble();
            minX = min(minX, x);
            minY = min(minY, y);
            maxX = max(maxX, x);
            maxY = max(maxY, y);
            final distance = sqrt(
              pow(pixels[offset] - targetR, 2) +
                  pow(pixels[offset + 1] - targetG, 2) +
                  pow(pixels[offset + 2] - targetB, 2),
            );
            colourDistance = min(colourDistance, distance);
          }

          final reason = '${entry.key} is not the complete status glyph';
          expect(
            maxX - minX,
            greaterThanOrEqualTo(minimumGlyphSpan),
            reason: reason,
          );
          expect(
            maxY - minY,
            greaterThanOrEqualTo(minimumGlyphSpan),
            reason: reason,
          );
          expect(
            inked,
            greaterThanOrEqualTo(minimumInkedPixels),
            reason: reason,
          );
          expect(
            colourDistance,
            lessThan(48),
            reason: '${entry.key} must carry its design colour',
          );
        }
      },
    );
  });
}

final class _PushedRouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}
