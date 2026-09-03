import 'package:flutter/material.dart';

/// One transient, non-stacking, safe-area-aware notice.
///
/// A new notice replaces any visible one instead of queueing. Copy rules live
/// in the assessment specification: one plain sentence, no exclamation marks,
/// no raw exceptions, no fake success.
abstract final class AppNotice {
  /// Shows [message], replacing any currently visible notice.
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
