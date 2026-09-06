import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/radii.dart';
import 'package:app_ui/src/tokens/spacing.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Builds the shared Material field treatment used inside app sheets.
InputDecoration appSheetInputDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final colors = AppColors.of(context);
  final border = OutlineInputBorder(
    borderRadius: AppRadii.image,
    borderSide: BorderSide(color: colors.border),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: AppTypography.body(colors, color: colors.textTertiary),
    counterText: '',
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.medium,
      vertical: AppSpacing.small,
    ),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadii.image,
      borderSide: BorderSide(color: colors.brand, width: 2),
    ),
  );
}

/// The shared modal sheet with the design identity and current platform
/// mechanics.
///
/// Filter, comment, and create-post sheets are not supplied in Figma; this
/// surface supplies their restrained, token-built identity. It is
/// scroll-controlled, safe-area aware, and keeps the keyboard off actions.
abstract final class AppSheet {
  /// Presents [child] in the shared sheet and returns its result.
  ///
  /// [heightFactor] fixes the sheet to that fraction of the available height
  /// on both platforms. It must be between 0.1 and 1.0.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    double? heightFactor,
  }) {
    assert(
      heightFactor == null || (heightFactor >= 0.1 && heightFactor <= 1),
      'heightFactor must be between 0.1 and 1.0',
    );
    final colors = AppColors.of(context);

    if (context.isIos) {
      return showCupertinoSheet<T>(
        context: context,
        showDragHandle: true,
        enableDrag: isDismissible,
        topGap: heightFactor == null ? null : 1 - heightFactor,
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
      builder: (sheetContext) {
        final content = SafeArea(
          top: false,
          // SafeArea chooses the larger of this keyboard inset and the platform
          // bottom inset, protecting sheet actions in both states.
          minimum: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: child,
        );
        if (heightFactor == null) return content;
        return FractionallySizedBox(
          heightFactor: heightFactor,
          child: content,
        );
      },
    );
  }
}
