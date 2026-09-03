import 'dart:ui' show Tristate;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    });

    test('subtle light surface preserves the documented alpha', () {
      expect(AppColors.light.subtleSurface, const Color(0x05000000));
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

      final region = tester.getSize(find.byType(SizedBox).first);
      expect(region.width, AppIconSize.tapTarget);
      expect(region.height, AppIconSize.tapTarget);

      // The visible glyph keeps its measured size.
      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.size, AppIconSize.small);

      // Tapping the edge of the region still activates the control.
      await tester.tapAt(tester.getTopLeft(find.byType(SizedBox).first));
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
  });

  group('OfflineStatusBar', () {
    testWidgets('renders provenance text on a themed surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: OfflineStatusBar(message: 'Showing saved posts.'),
          ),
        ),
      );

      expect(find.text('Showing saved posts.'), findsOneWidget);
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(OfflineStatusBar),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, AppColors.dark.surface);
    });
  });
}
