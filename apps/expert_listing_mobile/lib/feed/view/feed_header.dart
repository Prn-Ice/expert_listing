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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xlarge,
      ),
      child: SizedBox(
        height: AppIconSize.tapTarget,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              button: true,
              label: 'Expert Listing feed',
              onTap: onLogoPressed,
              child: ExcludeSemantics(
                child: SizedBox(
                  key: const ValueKey<String>('feed-wordmark'),
                  width: 169,
                  height: AppIconSize.tapTarget,
                  child: InkWell(
                    onTap: onLogoPressed,
                    borderRadius: AppRadii.image,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppBrandWordmark(color: colors.brandDeep),
                    ),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Messages',
              child: Semantics(
                button: true,
                label: 'Messages',
                onTap: () => onNotice('Messages are not part of this preview.'),
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: AppIconSize.tapTarget,
                  child: TextButton(
                    onPressed: () =>
                        onNotice('Messages are not part of this preview.'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
