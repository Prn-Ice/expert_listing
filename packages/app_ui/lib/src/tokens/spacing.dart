/// Spacing scale for the Expert Listing design system.
///
/// Only values that repeat across the Figma reference earn a token. One-off
/// geometry stays local to its widget with a Figma-node comment.
library;

/// The finite spacing scale. All values are logical pixels.
abstract final class AppSpacing {
  /// 4 logical pixels. Tight inline gaps: icon-to-count, badge offsets.
  static const double xsmall = 4;

  /// 8 logical pixels. Small inline gaps: chip internals, stacked metadata.
  static const double small = 8;

  /// 12 logical pixels. Default gap between related elements.
  static const double medium = 12;

  /// 16 logical pixels. Card padding and section gaps.
  static const double large = 16;

  /// 20 logical pixels. Generous section spacing.
  static const double xlarge = 20;

  /// 24 logical pixels. Content inset used by feed rows and pills.
  static const double xxlarge = 24;

  /// 32 logical pixels. Major section separation.
  static const double xxxlarge = 32;
}
