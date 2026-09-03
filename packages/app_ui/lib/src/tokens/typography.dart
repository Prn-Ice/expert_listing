/// Typography tokens for the Expert Listing design system.
///
/// The family is the committed Open Runde (OFL 1.1, bundled by this package).
/// Role sizes follow docs/wiki/design-system.md; sizes and heights were first
/// measured from [private reference removed] and await Figma re-verification (the
/// MCP was rate-limited on 2026-09-03).
library;

import 'package:app_ui/src/tokens/colors.dart';
import 'package:flutter/widgets.dart';

/// The text role scale. Widgets read these through [AppTypography] helpers so
/// no widget repeats a raw font size or weight.
abstract final class AppTypography {
  /// The bundled family, referenced with this package's asset prefix.
  static const String fontFamily = 'packages/app_ui/Open Runde';

  static TextStyle _role(
    AppColors colors, {
    required double size,
    required FontWeight weight,
    required double height,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? colors.textPrimary,
      // The design ships no italic or fallback substitutes.
      fontFamilyFallback: const [],
    );
  }

  /// Brand wordmark and rare 20px headings.
  static TextStyle brand(AppColors colors, {Color? color}) => _role(
    colors,
    size: 20,
    weight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  /// Author names and 16px semibold content.
  static TextStyle title(AppColors colors, {Color? color}) => _role(
    colors,
    size: 16,
    weight: FontWeight.w600,
    height: 1.25,
    color: color,
  );

  /// Post body copy.
  static TextStyle body(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  /// Emphasised 14px rows (for example "View all comments").
  static TextStyle bodyStrong(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w600,
    height: 1.45,
    color: color,
  );

  /// Secondary metadata: role, timestamps, liked-by.
  static TextStyle meta(AppColors colors, {Color? color}) => _role(
    colors,
    size: 13,
    weight: FontWeight.w400,
    height: 1.3,
    color: color ?? colors.textSecondary,
  );

  /// Tags, locations, counts, and navigation labels.
  static TextStyle caption(AppColors colors, {Color? color}) => _role(
    colors,
    size: 12,
    weight: FontWeight.w500,
    height: 1.25,
    color: color ?? colors.textSecondary,
  );
}
