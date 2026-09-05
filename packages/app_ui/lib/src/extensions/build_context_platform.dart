import 'package:flutter/material.dart';

/// Platform traits resolved from the active, testable Flutter theme.
extension AppPlatformContext on BuildContext {
  /// Whether this subtree uses iOS interaction conventions.
  bool get isIos => Theme.of(this).platform == TargetPlatform.iOS;
}
