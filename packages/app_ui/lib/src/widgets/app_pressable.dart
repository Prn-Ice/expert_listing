import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Resolves a contained Android ink boundary within a pressable surface.
typedef AppInkRect = Rect Function(Size size);

/// Press behaviour for composed branded surfaces.
///
/// Tiles, rows, and imagery that are more than a labelled button keep their
/// own layout and visuals; this boundary adds only the platform press
/// response: restrained iOS press opacity, contained Android ink on the
/// supplied radius.
class AppPressable extends StatelessWidget {
  /// Creates the pressable surface.
  const AppPressable({
    required this.child,
    required this.onPressed,
    super.key,
    this.borderRadius,
    this.color,
    this.overlayColor,
    this.inkRect,
    this.inkOnTop = false,
    this.semanticLabel,
    this.selected = false,
  });

  /// The composed surface content.
  final Widget child;

  /// The action performed on activation; `null` disables the control.
  final VoidCallback? onPressed;

  /// Ink and press-highlight rounding; rectangular when null.
  final BorderRadius? borderRadius;

  /// The surface fill; transparent when null.
  final Color? color;

  /// The Android press-highlight colour, for surfaces with an accepted
  /// measured overlay.
  final Color? overlayColor;

  /// Optional Android ink bounds within the full tappable surface.
  final AppInkRect? inkRect;

  /// Paints Android ink above opaque content such as imagery.
  final bool inkOnTop;

  /// Replaces the subtree semantics with one button label when supplied.
  final String? semanticLabel;

  /// Whether the control marks a currently selected destination.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel;
    final borderRadius = this.borderRadius;
    final surfaceColor = color;
    final content = label == null
        ? child
        : Semantics(label: label, excludeSemantics: true, child: child);

    final surface = surfaceColor == null
        ? content
        : DecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: borderRadius,
            ),
            child: content,
          );
    final pressable = context.isIos
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            pressedOpacity: 0.6,
            color: surfaceColor,
            borderRadius:
                borderRadius ?? const BorderRadius.all(Radius.circular(8)),
            onPressed: onPressed,
            child: content,
          )
        : inkOnTop
        ? Stack(
            fit: StackFit.passthrough,
            children: [
              surface,
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: _AppInkResponse(
                    onTap: onPressed,
                    borderRadius: borderRadius,
                    overlayColor: overlayColor,
                    inkRect: inkRect,
                  ),
                ),
              ),
            ],
          )
        : Material(
            // Transparency keeps hit testing on the full composed box; a
            // shaped Material would reject taps outside its rounded path.
            type: MaterialType.transparency,
            child: _AppInkResponse(
              onTap: onPressed,
              borderRadius: borderRadius,
              overlayColor: overlayColor,
              inkRect: inkRect,
              child: surface,
            ),
          );

    // InkResponse supplies a semantics tap action but no button flag; the
    // boundary owns the full control semantics either way. The container
    // boundary keeps the node owned here so labels resolve to this control.
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      excludeSemantics: label != null,
      child: pressable,
    );
  }
}

final class _AppInkResponse extends InkResponse {
  _AppInkResponse({
    required super.onTap,
    required this.inkRect,
    super.child,
    super.borderRadius,
    Color? overlayColor,
  }) : super(
         containedInkWell: true,
         overlayColor: overlayColor == null
             ? null
             : WidgetStatePropertyAll(overlayColor),
       );

  final AppInkRect? inkRect;

  @override
  RectCallback? getRectCallback(RenderBox referenceBox) {
    final resolveRect = inkRect;
    if (resolveRect == null) return null;
    return () => resolveRect(referenceBox.size);
  }
}
