import 'dart:async';

import 'package:app_ui/src/tokens/icons.dart';
import 'package:app_ui/src/tokens/motion.dart';
import 'package:app_ui/src/widgets/app_icon.dart';
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
            ? _IosPressOpacity(
                onTap: onPressed == null ? null : _handleTap,
                child: child,
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

class _IosPressOpacity extends StatefulWidget {
  const _IosPressOpacity({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_IosPressOpacity> createState() => _IosPressOpacityState();
}

class _IosPressOpacityState extends State<_IosPressOpacity> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1,
        duration: reduceMotion ? Duration.zero : AppMotion.fast,
        child: widget.child,
      ),
    );
  }
}
