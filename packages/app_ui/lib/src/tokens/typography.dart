/// Typography tokens for the Expert Listing design system.
///
/// The family is the committed Open Runde (OFL 1.1, bundled by this package).
/// Role sizes follow docs/wiki/design-system.md and the committed design
/// reference.
library;

import 'package:app_ui/src/tokens/colors.dart';
import 'package:flutter/widgets.dart';

/// The text role scale. Widgets read these through [AppTypography] helpers so
/// no widget repeats a raw font size or weight.
abstract final class AppTypography {
  /// Open Runde, referenced with this package's asset prefix.
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

  /// Open Runde, 20 logical pixels, 24px line height, weight 600.
  ///
  /// Used for the brand wordmark and rare headings.
  static TextStyle brand(AppColors colors, {Color? color}) => _role(
    colors,
    size: 20,
    weight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  /// Open Runde, 16 logical pixels, 20px line height, weight 600.
  ///
  /// Used for author names and semibold content.
  static TextStyle title(AppColors colors, {Color? color}) => _role(
    colors,
    size: 16,
    weight: FontWeight.w600,
    height: 1.25,
    color: color,
  );

  /// Open Runde, 16 logical pixels, 19.2px line height, weight 500.
  ///
  /// Used for primary feed post copy.
  static TextStyle postBody(AppColors colors, {Color? color}) => _role(
    colors,
    size: 16,
    weight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// Open Runde, 14 logical pixels, 20.3px line height, weight 400.
  ///
  /// Used for post body copy.
  static TextStyle body(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  /// Open Runde, 14 logical pixels, 20.3px line height, weight 600.
  ///
  /// Used for emphasized rows, for example "View all comments".
  static TextStyle bodyStrong(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w600,
    height: 1.45,
    color: color,
  );

  /// Open Runde, 13 logical pixels, 16.9px line height, weight 400.
  ///
  /// Used for secondary metadata: role, timestamps, and liked-by.
  static TextStyle meta(AppColors colors, {Color? color}) => _role(
    colors,
    size: 13,
    weight: FontWeight.w400,
    height: 1.3,
    color: color ?? colors.textSecondary,
  );

  /// Open Runde, 12 logical pixels, 15px line height, weight 500.
  ///
  /// Used for tags, locations, and counts.
  static TextStyle caption(AppColors colors, {Color? color}) => _role(
    colors,
    size: 12,
    weight: FontWeight.w500,
    height: 1.25,
    color: color ?? colors.textSecondary,
  );

  /// Open Runde, 13 logical pixels, 16.9px line height, weight 500.
  ///
  /// Used for concise hint copy in dense controls.
  static TextStyle hint(AppColors colors, {Color? color}) => _role(
    colors,
    size: 13,
    weight: FontWeight.w500,
    height: 1.3,
    color: color ?? colors.textTertiary,
  );

  /// Open Runde, 12 logical pixels, 15px line height, weight 400.
  ///
  /// Used for the labels below story previews.
  static TextStyle storyLabel(AppColors colors, {Color? color}) => _role(
    colors,
    size: 12,
    weight: FontWeight.w400,
    height: 1.25,
    color: color ?? colors.textSecondary,
  );

  /// Open Runde, 14 logical pixels, 16.8px line height, weight 400.
  ///
  /// Used for inactive bottom-navigation labels (Figma Nav, node [private design node removed]).
  static TextStyle navLabel(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w400,
    height: 1.2,
    color: color ?? colors.textSecondary,
  );

  /// Open Runde, 14 logical pixels, 16.8px line height, weight 500.
  ///
  /// The selected bottom-navigation label role (Figma Nav, node [private design node removed]).
  static TextStyle navLabelSelected(AppColors colors, {Color? color}) => _role(
    colors,
    size: 14,
    weight: FontWeight.w500,
    height: 1.2,
    color: color ?? colors.textPrimary,
  );
}
