import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/radii.dart';
import 'package:flutter/material.dart';

/// The shared modal sheet with the design identity and current platform
/// mechanics.
///
/// Filter, comment, and create-post sheets are not supplied in Figma; this
/// surface supplies their restrained, token-built identity. It is
/// scroll-controlled, safe-area aware, and keeps the keyboard off actions.
abstract final class AppSheet {
  /// Presents [child] in the shared sheet and returns its result.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
  }) {
    final colors = AppColors.of(context);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      useSafeArea: true,
      backgroundColor: colors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      // The sheet keeps clear of the keyboard; callers lay out their own
      // scrollable content and bottom actions.
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      ),
    );
  }
}
