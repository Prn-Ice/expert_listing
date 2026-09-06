import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// The branded top row of the feed.
class FeedHeader extends StatelessWidget {
  /// Creates the header.
  const FeedHeader({
    required this.onLogoPressed,
    required this.onNotice,
    super.key,
  });

  /// Returns the active feed to its top position.
  final VoidCallback onLogoPressed;

  /// Shows a non-stacking boundary notice.
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      // The complete header is 72px: 12px around a genuine 48px control row.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xlarge,
        vertical: AppSpacing.medium,
      ),
      child: SizedBox(
        height: AppIconSize.tapTarget,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 169,
              height: AppIconSize.tapTarget,
              child: AppPressable(
                key: const ValueKey<String>('feed-wordmark'),
                onPressed: onLogoPressed,
                borderRadius: AppRadii.image,
                semanticLabel: 'Expert Listing feed',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppBrandWordmark(color: colors.brandDeep),
                ),
              ),
            ),
            Tooltip(
              message: 'Messages',
              excludeFromSemantics: true,
              child: SizedBox.square(
                dimension: AppIconSize.tapTarget,
                child: AppPressable(
                  onPressed: () =>
                      onNotice('Messages aren’t part of this preview.'),
                  borderRadius: BorderRadius.circular(
                    AppIconSize.tapTarget / 2,
                  ),
                  semanticLabel: 'Messages',
                  child: SizedBox.square(
                    dimension: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.subtleSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AppIcon(
                          AppIcons.messages,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
