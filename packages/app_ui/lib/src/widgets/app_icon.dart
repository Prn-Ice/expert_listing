import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one exact committed SVG icon from the design-system inventory.
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

  /// The semantic colour; defaults to the theme's icon colour.
  final Color? color;

  /// Accessibility description when the icon conveys meaning alone.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ??
        IconTheme.of(context).color ??
        AppColors.of(context).textPrimary;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SvgPicture.asset(
        asset,
        package: 'app_ui',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        placeholderBuilder: (_) => SizedBox.square(dimension: size),
      ),
    );
  }
}
