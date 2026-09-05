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
      height: 87,
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
            onPressed: () => onNotice(
              story.isCurrentUser
                  ? 'Story posting is not part of this preview.'
                  : 'Story viewing is not part of this preview.',
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
    required this.onPressed,
  });

  final String label;
  final String asset;
  final bool isCurrentUser;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = (60 * devicePixelRatio).round();
    return SizedBox(
      width: 66,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Column(
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
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.storyLabel(colors),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
