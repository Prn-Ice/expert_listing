/// Motion tokens for the Expert Listing design system.
///
/// The approved set is deliberately small. Motion exists to explain state or
/// continuity; widgets must honour reduced-motion settings by removing
/// translation, scale, bounce, shimmer, and repetitive animation.
library;

import 'package:flutter/animation.dart';

/// The approved durations and curves.
abstract final class AppMotion {
  /// Immediate feedback such as press opacity.
  static const Duration fast = Duration(milliseconds: 120);

  /// State transitions such as like and bookmark updates.
  static const Duration medium = Duration(milliseconds: 200);

  /// Continuity transitions such as sheet presentation.
  static const Duration slow = Duration(milliseconds: 300);

  /// The single approved emphasis curve.
  static const Curve curve = Curves.easeOutCubic;
}
