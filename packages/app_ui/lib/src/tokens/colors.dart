/// Semantic colour roles for the Expert Listing design system.
///
/// Light values are the committed design reference recorded in
/// docs/wiki/design-system.md. Dark values are the deliberate derived palette
/// documented with contrast evidence on the same page.
library;

import 'package:flutter/material.dart';

/// The set of semantic colour roles every appearance must provide.
///
/// Widgets read these through `AppColors.of(context)`; they never embed raw
/// colour literals.
final class AppColors extends ThemeExtension<AppColors> {
  /// Creates a complete set of semantic roles.
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brand,
    required this.onBrand,
    required this.brandText,
    required this.brandTint,
    required this.brandDeep,
    required this.accent,
    required this.accentTint,
    required this.warm,
    required this.warmTint,
  });

  /// Page background.
  final Color canvas;

  /// Raised cards, chips, and inset surfaces.
  final Color surface;

  /// Hairline-faint fill for separators and quiet rows.
  final Color subtleSurface;

  /// Hairline borders.
  final Color border;

  /// Primary content text.
  final Color textPrimary;

  /// Supporting metadata text.
  final Color textSecondary;

  /// Quiet placeholder and hint text.
  final Color textTertiary;

  /// The lime brand accent: active states, rings, key highlights.
  final Color brand;

  /// Text and icons placed on a [brand] fill.
  final Color onBrand;

  /// Brand-green text on light surfaces.
  final Color brandText;

  /// Brand-green tinted fill behind brand tags.
  final Color brandTint;

  /// The deep green of the committed brand mark and wordmark.
  final Color brandDeep;

  /// The violet accent used by request-type tags.
  final Color accent;

  /// Violet tinted fill behind accent tags.
  final Color accentTint;

  /// The warm amber used by looking-to-rent tags.
  final Color warm;

  /// Warm tinted fill behind amber tags.
  final Color warmTint;

  /// The light appearance, matching the committed Figma reference.
  static const light = AppColors(
    canvas: Color(0xffffffff),
    surface: Color(0xfff4f4f4),
    subtleSurface: Color(0x05000000),
    border: Color(0xffe8e8e8),
    textPrimary: Color(0xff1a1a1a),
    textSecondary: Color(0xff434343),
    textTertiary: Color(0xff7c7c7c),
    brand: Color(0xffa8dc66),
    onBrand: Color(0xff1a1a1a),
    brandText: Color(0xff4f7a1f),
    brandTint: Color(0xfff6fbef),
    brandDeep: Color(0xff105b48),
    accent: Color(0xff5b21b6),
    accentTint: Color(0xfff7f3ff),
    warm: Color(0xff655143),
    warmTint: Color(0xfff2efe3),
  );

  /// The deliberate dark appearance, derived from the same roles.
  ///
  /// Brand lime stays untouched for identity; text-facing greens lighten to
  /// keep contrast on dark surfaces. See docs/wiki/design-system.md for the
  /// contrast evidence table.
  static const dark = AppColors(
    canvas: Color(0xff101211),
    surface: Color(0xff1c1e1c),
    subtleSurface: Color(0x0affffff),
    border: Color(0xff2b2d2b),
    textPrimary: Color(0xfff3f4f3),
    textSecondary: Color(0xffb9bbb9),
    textTertiary: Color(0xff7e807e),
    brand: Color(0xffa8dc66),
    onBrand: Color(0xff101211),
    brandText: Color(0xffc7ec96),
    brandTint: Color(0xff24311a),
    brandDeep: Color(0xff9ad7ba),
    accent: Color(0xffc9b8f5),
    accentTint: Color(0xff251e3d),
    warm: Color(0xffd8c4a8),
    warmTint: Color(0xff33301f),
  );

  /// Reads the active roles from the nearest theme.
  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? AppColors.light;
  }

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? subtleSurface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? brand,
    Color? onBrand,
    Color? brandText,
    Color? brandTint,
    Color? brandDeep,
    Color? accent,
    Color? accentTint,
    Color? warm,
    Color? warmTint,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandText: brandText ?? this.brandText,
      brandTint: brandTint ?? this.brandTint,
      brandDeep: brandDeep ?? this.brandDeep,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      warm: warm ?? this.warm,
      warmTint: warmTint ?? this.warmTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      warmTint: Color.lerp(warmTint, other.warmTint, t)!,
    );
  }
}
