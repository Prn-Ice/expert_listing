import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

    final pressable = Theme.of(context).platform == TargetPlatform.iOS
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
        : Material(
            // Transparency keeps hit testing on the full composed box; a
            // shaped Material would reject taps outside its rounded path.
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onPressed,
              containedInkWell: true,
              borderRadius: borderRadius,
              overlayColor: overlayColor == null
                  ? null
                  : WidgetStateProperty.all(overlayColor),
              child: surfaceColor == null
                  ? content
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: borderRadius,
                      ),
                      child: content,
                    ),
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
