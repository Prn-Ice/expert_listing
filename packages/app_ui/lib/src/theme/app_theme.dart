/// ThemeData assembly from the semantic tokens.
library;

import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/radii.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the light and dark appearances from the shared semantic roles.
abstract final class AppTheme {
  /// The Figma-faithful light appearance. This is the design reference.
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  /// The deliberate dark appearance derived from the same semantic roles.
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
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
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      colorScheme: colorScheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textPrimary),
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
}
