import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A labelled action rendered by the active platform's text button.
///
/// The text-control hit region stays the measured 32px minimum unless a call
/// site supplies larger geometry. iOS responds with restrained press opacity;
/// Android responds with contained ink, focus, and the TextButton disabled
/// state.
class AppButton extends StatelessWidget {
  /// Creates the labelled action.
  const AppButton({
    required this.child,
    required this.onPressed,
    super.key,
    this.minimumSize,
    this.padding,
    this.alignment,
    this.borderRadius,
    this.overlayColor,
    this.materialTapTargetSize,
  });

  /// The labelled content, usually a [Text] with its role style.
  final Widget child;

  /// The action performed on activation; `null` disables the control.
  final VoidCallback? onPressed;

  /// The minimum hit region; defaults to the 32px text-control contract.
  final Size? minimumSize;

  /// Padding around the labelled content.
  final EdgeInsetsGeometry? padding;

  /// Alignment of the content inside the resolved hit region.
  final AlignmentGeometry? alignment;

  /// Ink and press-highlight rounding; rectangular when null.
  final BorderRadius? borderRadius;

  /// The Android press-highlight colour, for surfaces with an accepted
  /// measured overlay.
  final Color? overlayColor;

  /// The Android tap-target sizing rule; defaults to shrink wrap so
  /// [minimumSize] and [padding] own the resolved geometry.
  final MaterialTapTargetSize? materialTapTargetSize;

  @override
  Widget build(BuildContext context) {
    final minimumSize =
        this.minimumSize ?? const Size.square(AppIconSize.textButtonTapTarget);
    final padding = this.padding ?? EdgeInsets.zero;

    if (context.isIos) {
      return CupertinoButton(
        padding: padding,
        minimumSize: minimumSize,
        pressedOpacity: 0.6,
        onPressed: onPressed,
        child: child,
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: minimumSize,
        padding: padding,
        alignment: alignment,
        tapTargetSize:
            materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.zero,
        ),
        overlayColor: overlayColor,
      ),
      child: child,
    );
  }
}
