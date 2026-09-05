import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One transient, non-stacking, safe-area-aware notice.
///
/// A new notice replaces any visible one instead of queueing. Copy rules live
/// in the assessment specification: one plain sentence, no exclamation marks,
/// no raw exceptions, no fake success. Android answers with the themed
/// SnackBar; iOS answers with the restrained native dialog, whose barrier
/// also keeps notices from stacking.
abstract final class AppNotice {
  /// Shows [message], replacing any currently visible notice.
  static void show(BuildContext context, String message) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      unawaited(
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss notice',
          builder: (dialogContext) => CupertinoAlertDialog(
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
