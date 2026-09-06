import 'package:app_ui/src/tokens/motion.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A bounded, semantic public network image with stable loading geometry.
class AppNetworkImage extends StatelessWidget {
  /// Creates a shared public-image surface.
  const AppNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.fallback,
    this.semanticLabel,
    super.key,
  });

  /// The public URL returned by Hono.
  final String imageUrl;

  /// An optional fixed logical width.
  final double? width;

  /// An optional fixed logical height.
  final double? height;

  /// How the image occupies its reserved geometry.
  final BoxFit fit;

  /// The stable widget rendered while bytes load.
  final Widget? placeholder;

  /// The stable widget rendered when loading fails.
  final Widget? fallback;

  /// An optional single semantic description of the image.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final reducedMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        final fadeDuration = reducedMotion ? Duration.zero : AppMotion.fast;
        final imageWidth = _layoutDimension(width, constraints.maxWidth);
        final imageHeight = _layoutDimension(height, constraints.maxHeight);
        final image = CachedNetworkImage(
          imageUrl: imageUrl,
          width: imageWidth,
          height: imageHeight,
          fit: fit,
          memCacheWidth: _decodeWidth(
            width,
            constraints.maxWidth,
            devicePixelRatio,
          ),
          // ResizeImage treats two dimensions as an exact decode size. Decode
          // from width only so a fixed-ratio preview crops rather than
          // stretches a portrait or landscape source.
          placeholder: (_, _) => placeholder ?? const SizedBox.expand(),
          errorWidget: (_, _, _) => fallback ?? const SizedBox.expand(),
          placeholderFadeInDuration: fadeDuration,
          fadeOutDuration: fadeDuration,
          fadeInDuration: fadeDuration,
          fadeOutCurve: AppMotion.curve,
          fadeInCurve: AppMotion.curve,
          useOldImageOnUrlChange: true,
        );
        final label = semanticLabel;
        if (label == null || label.isEmpty) return image;
        return Semantics(
          image: true,
          label: label,
          child: ExcludeSemantics(child: image),
        );
      },
    );
  }
}

double? _layoutDimension(double? explicit, double constrained) {
  if (explicit?.isFinite == true) return explicit;
  return constrained.isFinite ? constrained : null;
}

int? _decodeWidth(
  double? explicit,
  double constrained,
  double devicePixelRatio,
) {
  final logicalPixels = _layoutDimension(explicit, constrained);
  if (logicalPixels == null || logicalPixels <= 0) return null;
  return (logicalPixels * devicePixelRatio).round();
}
