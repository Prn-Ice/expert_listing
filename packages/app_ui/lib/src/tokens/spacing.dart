/// Spacing scale for the Expert Listing design system.
///
/// Only values that repeat across the Figma reference earn a token. One-off
/// geometry stays local to its widget with a Figma-node comment.
library;

/// The finite spacing scale. All values are logical pixels.
abstract final class AppSpacing {
  /// Tight inline gaps: icon-to-count, badge offsets.
  static const double xsmall = 4;

  /// Small inline gaps: chip internals, stacked metadata.
  static const double small = 8;

  /// Default gap between related elements.
  static const double medium = 12;

  /// Card padding and section gaps.
  static const double large = 16;

  /// Generous section spacing.
  static const double xlarge = 20;

  /// Content inset used by feed rows and pills.
  static const double xxlarge = 24;

  /// Major section separation.
  static const double xxxlarge = 32;
}
