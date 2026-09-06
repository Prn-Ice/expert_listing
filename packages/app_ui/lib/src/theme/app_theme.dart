/// ThemeData assembly from the semantic tokens.
library;

import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/radii.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the light and dark appearances from the shared semantic roles.
abstract final class AppTheme {
  /// The Figma-faithful light appearance. This is the design reference.
  static ThemeData light({TargetPlatform? platform}) {
    return _buildMaterial(AppColors.light, Brightness.light, platform);
  }

  /// The deliberate dark appearance derived from the same semantic roles.
  static ThemeData dark({TargetPlatform? platform}) {
    return _buildMaterial(AppColors.dark, Brightness.dark, platform);
  }

  /// The Material appearance for [brightness] on [platform].
  static ThemeData material(
    Brightness brightness, {
    TargetPlatform? platform,
  }) => brightness == Brightness.dark
      ? dark(platform: platform)
      : light(platform: platform);

  /// The Cupertino appearance built from the same semantic roles.
  ///
  /// The text style keeps the committed Open Runde family so branded content
  /// reads the same under either native root.
  static CupertinoThemeData cupertino(Brightness brightness) =>
      brightness == Brightness.dark
      ? _buildCupertino(AppColors.dark)
      : _buildCupertino(AppColors.light);

  static ThemeData _buildMaterial(
    AppColors colors,
    Brightness brightness,
    TargetPlatform? platform,
  ) {
    final isDark = brightness == Brightness.dark;
    final textTheme = TextTheme(
      titleMedium: AppTypography.title(colors),
      bodyMedium: AppTypography.body(colors),
      bodySmall: AppTypography.meta(colors),
      labelSmall: AppTypography.caption(colors),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: colors.onBrand,
      primaryContainer: colors.brandTint,
      onPrimaryContainer: colors.brandText,
      primaryFixed: AppColors.light.brand,
      primaryFixedDim: AppColors.light.brand,
      onPrimaryFixed: AppColors.light.onBrand,
      onPrimaryFixedVariant: AppColors.light.brandDeep,
      secondary: colors.brand,
      onSecondary: colors.onBrand,
      secondaryContainer: colors.brandTint,
      onSecondaryContainer: colors.brandText,
      secondaryFixed: AppColors.light.brand,
      secondaryFixedDim: AppColors.light.brand,
      onSecondaryFixed: AppColors.light.onBrand,
      onSecondaryFixedVariant: AppColors.light.brandDeep,
      tertiary: colors.accent,
      onTertiary: isDark ? colors.accentTint : colors.canvas,
      tertiaryContainer: colors.accentTint,
      onTertiaryContainer: colors.accent,
      tertiaryFixed: AppColors.light.accent,
      tertiaryFixedDim: AppColors.light.accent,
      onTertiaryFixed: AppColors.light.canvas,
      onTertiaryFixedVariant: AppColors.light.accent,
      error: isDark ? const Color(0xffffb4ab) : const Color(0xffba1a1a),
      onError: isDark ? const Color(0xff690005) : colors.canvas,
      errorContainer: isDark
          ? const Color(0xff93000a)
          : const Color(0xffffdad6),
      onErrorContainer: isDark
          ? const Color(0xffffdad6)
          : const Color(0xff410002),
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceDim: isDark ? colors.canvas : colors.surface,
      surfaceBright: isDark ? colors.surface : colors.canvas,
      surfaceContainerLowest: colors.canvas,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surface,
      surfaceContainerHighest: colors.surface,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? AppColors.light.canvas : AppColors.dark.surface,
      onInverseSurface: isDark
          ? AppColors.light.textPrimary
          : AppColors.dark.textPrimary,
      inversePrimary: colors.brand,
      surfaceTint: colors.brand,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: platform,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      colorScheme: colorScheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textPrimary),
      splashColor: colors.subtleSurface,
      highlightColor: Colors.transparent,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.pressed)
                ? colors.subtleSurface
                : null;
          }),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: colors.canvas,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarColor: colors.canvas,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.subtleSurface,
        thickness: 2,
        space: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: AppTypography.meta(colors).copyWith(
          color: colors.canvas,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.image),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      extensions: [colors],
    );
  }

  static CupertinoThemeData _buildCupertino(AppColors colors) {
    return CupertinoThemeData(
      primaryColor: colors.brand,
      primaryContrastingColor: colors.onBrand,
      scaffoldBackgroundColor: colors.canvas,
      barBackgroundColor: colors.canvas,
      textTheme: CupertinoTextThemeData(
        primaryColor: colors.brand,
        textStyle: AppTypography.body(colors),
      ),
    );
  }
}
