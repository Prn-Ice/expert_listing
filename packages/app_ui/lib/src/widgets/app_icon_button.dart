import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:app_ui/src/tokens/spacing.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:app_ui/src/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// An icon control that keeps the exact Figma glyph geometry inside a hit
/// region of at least 48 by 48 logical pixels.
///
/// The enlarged region never distorts the visible row geometry: the glyph
/// stays its measured [AppIconSize] while padding expands the tap area. The
/// control is a genuine platform button: iOS responds with restrained press
/// opacity and Android with the contained ink of [IconButton].
class AppIconButton extends StatelessWidget {
  /// Creates the icon control.
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.iconSize = AppIconSize.medium,
    this.color,
    this.label,
    this.alignment = Alignment.center,
  });

  /// The committed [AppIcons] asset to render.
  final String icon;

  /// The action performed on activation; `null` disables the control.
  final VoidCallback? onPressed;

  /// The tooltip and default semantic label.
  final String tooltip;

  /// The measured glyph size; layout geometry never grows with the hit region.
  final double iconSize;

  /// Glyph colour; defaults to the neutral primary content colour.
  final Color? color;

  /// Optional count rendered beside the glyph and announced after the label.
  final String? label;

  /// Alignment of the visible content inside the minimum hit region.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final glyphColor = color ?? colors.textPrimary;
    final count = label;
    final child = count == null
        ? AppIcon(icon, size: iconSize, color: glyphColor)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: iconSize, color: glyphColor),
              const SizedBox(width: AppSpacing.xsmall),
              Text(
                count,
                style: AppTypography.caption(colors, color: glyphColor),
              ),
            ],
          );
    final semanticLabel = count == null ? tooltip : '$tooltip, $count';

    if (context.isIos) {
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: semanticLabel,
          excludeSemantics: true,
          child: CupertinoTheme(
            data: CupertinoTheme.of(context).copyWith(primaryColor: glyphColor),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppIconSize.tapTarget),
              alignment: alignment,
              pressedOpacity: 0.6,
              onPressed: onPressed,
              child: child,
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(
        minWidth: AppIconSize.tapTarget,
        minHeight: AppIconSize.tapTarget,
      ),
      padding: EdgeInsets.zero,
      alignment: alignment,
      icon: Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: child,
      ),
    );
  }
}
