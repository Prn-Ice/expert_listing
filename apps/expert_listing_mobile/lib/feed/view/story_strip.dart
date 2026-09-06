import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// The horizontally scrolling story-preview strip.
class StoryStrip extends StatelessWidget {
  /// Creates the story-preview strip.
  const StoryStrip({required this.onNotice, super.key});

  /// Shows a non-stacking boundary notice.
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleDelta = (textScale - 1).clamp(0, 2).toDouble();
    final scaledTextAllowance = scaleDelta > 0 ? 16.0 : 0.0;
    const stories = <({String label, String asset, bool isCurrentUser})>[
      (
        label: 'Your Story',
        asset: 'assets/images/current-user.jpg',
        isCurrentUser: true,
      ),
      (
        label: 'Abba',
        asset: 'assets/images/abba.jpg',
        isCurrentUser: false,
      ),
      (
        label: 'Bizzaro',
        asset: 'assets/images/bizzaro.jpg',
        isCurrentUser: false,
      ),
      (
        label: 'Ifeoma',
        asset: 'assets/images/ifeoma.jpg',
        isCurrentUser: false,
      ),
      (
        label: 'Ayo',
        asset: 'assets/images/ayo.jpg',
        isCurrentUser: false,
      ),
    ];

    return SizedBox(
      // Figma [private design node removed] uses a 60px avatar, 1px inner gap, 2px ring,
      // 4px label gap, and 12px label.
      height: 87 + scaledTextAllowance + (46 * scaleDelta),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlarge,
          2,
          AppSpacing.xlarge,
          0,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.large),
        itemBuilder: (context, index) {
          final story = stories[index];
          return _Story(
            label: story.label,
            asset: story.asset,
            isCurrentUser: story.isCurrentUser,
            width: 66 + (32 * scaleDelta),
            onPressed: () => onNotice(
              story.isCurrentUser
                  ? 'Story posting isn’t part of this preview.'
                  : 'Story viewing isn’t part of this preview.',
            ),
          );
        },
      ),
    );
  }
}

final class _Story extends StatelessWidget {
  const _Story({
    required this.label,
    required this.asset,
    required this.isCurrentUser,
    required this.width,
    required this.onPressed,
  });

  final String label;
  final String asset;
  final bool isCurrentUser;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = (60 * devicePixelRatio).round();
    return SizedBox(
      width: width,
      child: AppPressable(
        semanticLabel: isCurrentUser
            ? 'Open Your Story'
            : 'Open $label’s story',
        onPressed: onPressed,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isCurrentUser)
                    // Your Story has no brand ring; its add badge marks it.
                    Padding(
                      padding: const EdgeInsets.all(1),
                      child: ClipOval(
                        child: Image.asset(
                          asset,
                          key: ValueKey<String>('story-image-$label'),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          cacheWidth: cacheDimension,
                          cacheHeight: cacheDimension,
                        ),
                      ),
                    )
                  else
                    Container(
                      key: ValueKey<String>('story-ring-$label'),
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.brand, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          asset,
                          key: ValueKey<String>('story-image-$label'),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          cacheWidth: cacheDimension,
                          cacheHeight: cacheDimension,
                        ),
                      ),
                    ),
                  if (isCurrentUser)
                    Positioned(
                      right: 0,
                      bottom: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.canvas, width: 2),
                        ),
                        child: SizedBox.square(
                          dimension: AppIconSize.large,
                          child: Center(
                            child: AppIcon(
                              AppIcons.storyAdd,
                              size: AppIconSize.small,
                              color: colors.onBrand,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xsmall),
              if (MediaQuery.textScalerOf(context).scale(1) <= 1)
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: AppTypography.storyLabel(colors),
                    ),
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: AppTypography.storyLabel(colors),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
