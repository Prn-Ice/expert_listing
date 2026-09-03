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
      secondary: colors.brand,
      onSecondary: colors.onBrand,
      error: const Color(0xffb3261e),
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      outline: colors.border,
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
