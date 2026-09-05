import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one committed vector or raster icon from the design inventory.
///
/// Never redraw or substitute icons: [asset] must come from [AppIcons].
/// [size] preserves the measured Figma glyph geometry; hit regions are the
/// caller's concern (see `AppIconButton` for the 48px contract).
class AppIcon extends StatelessWidget {
  /// Creates an icon from a committed [AppIcons] asset.
  const AppIcon(
    this.asset, {
    super.key,
    this.size = AppIconSize.medium,
    this.color,
    this.semanticLabel,
  });

  /// The committed asset path, one of [AppIcons].
  final String asset;

  /// The visible glyph size in logical pixels.
  final double size;

  /// The semantic colour; defaults to the neutral primary content colour.
  final Color? color;

  /// Accessibility description when the icon conveys meaning alone.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.of(context).textPrimary;

    // Raster status exports receive the same semantic tint as the vector
    // icons and decode at the rendered physical size.
    final glyph = asset.endsWith('.svg')
        ? SvgPicture.asset(
            asset,
            package: 'app_ui',
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
            placeholderBuilder: (_) => SizedBox.square(dimension: size),
          )
        : Image.asset(
            asset,
            package: 'app_ui',
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: effectiveColor,
            colorBlendMode: BlendMode.srcIn,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                .round(),
          );

    // Decorative icons stay out of the semantics tree; only icons that
    // convey meaning alone expose a label.
    final label = semanticLabel;
    if (label == null || label.isEmpty) {
      return ExcludeSemantics(child: glyph);
    }
    return Semantics(
      label: label,
      image: true,
      child: glyph,
    );
  }
}
