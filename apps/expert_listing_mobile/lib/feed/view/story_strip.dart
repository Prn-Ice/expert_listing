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
      height: 83,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlarge),
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
    return SizedBox(
      width: 76,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.brand),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      asset,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (isCurrentUser)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.canvas, width: 2),
                      ),
                      child: const SizedBox.square(
                        dimension: AppIconSize.large,
                        child: Center(
                          child: AppIcon(
                            AppIcons.storyAdd,
                            size: AppIconSize.small,
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
