/// Radius and border tokens for the Expert Listing design system.
library;

import 'package:flutter/widgets.dart';

/// The repeated corner radii observed in the Figma reference.
abstract final class AppRadii {
  /// Fully rounded stadium shape for pills (filters, tags, prompt card).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Raised cards and sheets.
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));

  /// Modal sheets round only the edge that meets the app canvas.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(16),
  );

  /// Post imagery corners.
  static const BorderRadius image = BorderRadius.all(Radius.circular(12));
}
