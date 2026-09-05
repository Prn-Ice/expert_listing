import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/radii.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The shared modal sheet with the design identity and current platform
/// mechanics.
///
/// Filter, comment, and create-post sheets are not supplied in Figma; this
/// surface supplies their restrained, token-built identity. It is
/// scroll-controlled, safe-area aware, and keeps the keyboard off actions.
abstract final class AppSheet {
  /// Presents [child] in the shared sheet and returns its result.
  ///
  /// [cupertinoTopGap] leaves that fraction of the screen uncovered above an
  /// iOS sheet. It must be between 0.0 and 0.9 and has no effect elsewhere.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    double? cupertinoTopGap,
  }) {
    final colors = AppColors.of(context);

    if (context.isIos) {
      return showCupertinoSheet<T>(
        context: context,
        showDragHandle: true,
        enableDrag: isDismissible,
        topGap: cupertinoTopGap,
        scrollableBuilder: (sheetContext, controller) =>
            PrimaryScrollController(
              // The sheet's scroll controller drives the content's primary
              // scrollable so drag-to-dismiss cooperates with inner scrolling.
              controller: controller,
              child: ColoredBox(
                color: colors.canvas,
                child: SafeArea(
                  top: false,
                  // SafeArea chooses the larger of this keyboard inset and the
                  // platform bottom inset, protecting sheet actions in both
                  // states.
                  minimum: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: child,
                ),
              ),
            ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: colors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => SafeArea(
        top: false,
        // SafeArea chooses the larger of this keyboard inset and the platform
        // bottom inset, protecting sheet actions in both states.
        minimum: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: child,
      ),
    );
  }
}
