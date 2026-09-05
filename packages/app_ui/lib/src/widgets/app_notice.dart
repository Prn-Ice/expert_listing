import 'dart:async';

import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One transient, non-stacking, safe-area-aware notice.
///
/// A new notice replaces any visible one instead of queueing. Copy rules live
/// in the assessment specification: one plain sentence, no exclamation marks,
/// no raw exceptions, no fake success. Android answers with the themed
/// SnackBar; iOS answers with the restrained native dialog.
abstract final class AppNotice {
  static Route<void>? _cupertinoNoticeRoute;

  /// Shows [message], replacing any currently visible notice.
  static void show(BuildContext context, String message) {
    if (context.isIos) {
      final previousRoute = _cupertinoNoticeRoute;
      if (previousRoute?.isActive ?? false) {
        previousRoute!.navigator?.removeRoute(previousRoute);
      }

      late final CupertinoDialogRoute<void> route;
      route = CupertinoDialogRoute<void>(
        context: context,
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
      );
      _cupertinoNoticeRoute = route;
      unawaited(
        Navigator.of(
          context,
          rootNavigator: true,
        ).push<void>(route).whenComplete(
          () {
            if (identical(_cupertinoNoticeRoute, route)) {
              _cupertinoNoticeRoute = null;
            }
          },
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
