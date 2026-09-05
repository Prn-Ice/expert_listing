import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:app_ui/src/widgets/app_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar with a stable initials fallback.
class AppAvatar extends StatelessWidget {
  /// Creates a shared avatar surface.
  const AppAvatar({
    required this.imageUrl,
    required this.displayName,
    this.onPressed,
    this.size = 40,
    super.key,
  }) : assetName = null;

  /// Creates an avatar from a bundled asset.
  const AppAvatar.asset({
    required this.assetName,
    required this.displayName,
    this.onPressed,
    this.size = 40,
    super.key,
  }) : imageUrl = null;

  /// An optional public avatar URL.
  final String? imageUrl;

  /// The optional bundled avatar asset.
  final String? assetName;

  /// The name used for fallback initials and accessibility.
  final String displayName;

  /// An optional feature-owned avatar action.
  final VoidCallback? onPressed;

  /// The visible avatar diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _InitialsAvatar(displayName: displayName);
    final url = imageUrl?.trim();
    Widget image = initials;
    if (assetName != null) {
      // Bundled avatars are square; decoding at the rendered physical size
      // keeps large source files out of the image cache.
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheDimension = (size * devicePixelRatio).round();
      image = Image.asset(
        assetName!,
        fit: BoxFit.cover,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
      );
    } else if (url != null && url.isNotEmpty) {
      image = AppNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        placeholder: initials,
        fallback: initials,
      );
    }
    final visual = SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: image,
      ),
    );
    final label = '$displayName avatar';
    if (onPressed == null) {
      return Semantics(
        image: true,
        label: label,
        child: ExcludeSemantics(child: visual),
      );
    }
    // The visual stays top-aligned with the post heading while the hit region
    // keeps its 48px minimum; the semantic node owns the tap action so
    // assistive technology activates the same handler.
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size < AppIconSize.tapTarget ? AppIconSize.tapTarget : size,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: visual,
          ),
        ),
      ),
    );
  }
}

final class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.brandTint,
      child: Center(
        child: Text(
          _initials(displayName),
          style: AppTypography.caption(colors, color: colors.brandDeep),
        ),
      ),
    );
  }
}

String _initials(String displayName) {
  final words = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final initials = words.take(2).map((word) => word.characters.first).join();
  return initials.isEmpty ? '?' : initials.toUpperCase();
}
