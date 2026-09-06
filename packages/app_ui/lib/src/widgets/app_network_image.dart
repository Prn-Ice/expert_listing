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
        final preserveSourceAspectRatio = fit == BoxFit.contain;
        final image = CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: _decodeDimension(
            width,
            constraints.maxWidth,
            devicePixelRatio,
          ),
          // ResizeImage treats two dimensions as an exact decode size. A
          // contain preview must derive its height from the source image.
          memCacheHeight: preserveSourceAspectRatio
              ? null
              : _decodeDimension(
                  height,
                  constraints.maxHeight,
                  devicePixelRatio,
                ),
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

int? _decodeDimension(
  double? explicit,
  double constrained,
  double devicePixelRatio,
) {
  final logicalPixels = explicit?.isFinite == true
      ? explicit
      : constrained.isFinite
      ? constrained
      : null;
  if (logicalPixels == null || logicalPixels <= 0) return null;
  return (logicalPixels * devicePixelRatio).round();
}
