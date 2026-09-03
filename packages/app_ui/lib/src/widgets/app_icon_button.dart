import 'dart:async';

import 'package:app_ui/src/tokens/icons.dart';
import 'package:app_ui/src/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An icon control that keeps the exact Figma glyph geometry inside a hit
/// region of at least 48 by 48 logical pixels.
///
/// The enlarged region never distorts the visible row geometry: the glyph
/// stays its measured [AppIconSize] while padding expands the tap area.
/// Android responds with ink; iOS responds with restrained press opacity.
class AppIconButton extends StatelessWidget {
  /// Creates the icon control.
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.iconSize = AppIconSize.medium,
    this.color,
    this.hapticFeedback = false,
  });

  /// The committed [AppIcons] asset to render.
  final String icon;

  /// The action performed on activation; `null` disables the control.
  final VoidCallback? onPressed;

  /// The tooltip and default semantic label.
  final String tooltip;

  /// The measured glyph size; layout geometry never grows with the hit region.
  final double iconSize;

  /// Glyph colour; defaults to the theme's icon colour.
  final Color? color;

  /// Whether a confirmed activation adds a restrained selection haptic.
  final bool hapticFeedback;

  void _handleTap() {
    if (hapticFeedback) {
      unawaited(HapticFeedback.selectionClick());
    }
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final child = SizedBox.square(
      dimension: AppIconSize.tapTarget,
      child: Center(
        child: AppIcon(icon, size: iconSize, color: color),
      ),
    );

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: isIos
            ? CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  primaryColor: color ?? IconTheme.of(context).color,
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(AppIconSize.tapTarget),
                  pressedOpacity: 0.6,
                  onPressed: onPressed == null ? null : _handleTap,
                  child: child,
                ),
              )
            : Material(
                type: MaterialType.transparency,
                child: InkResponse(
                  onTap: onPressed == null ? null : _handleTap,
                  radius: AppIconSize.tapTarget / 2,
                  // Circular ink kept inside the square region.
                  borderRadius: BorderRadius.circular(
                    AppIconSize.tapTarget / 2,
                  ),
                  child: child,
                ),
              ),
      ),
    );
  }
}
