import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// The feed entry point for the later create-post flow.
class CreatePostPrompt extends StatelessWidget {
  /// Creates the prompt.
  const CreatePostPrompt({required this.onNotice, super.key});

  /// Shows a non-stacking boundary notice.
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      // Measured prompt geometry: 16px side insets, 8px above, 12px below.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.small,
        AppSpacing.large,
        AppSpacing.medium,
      ),
      child: SizedBox(
        height: 56,
        child: AppPressable(
          color: colors.subtleSurface,
          borderRadius: AppRadii.pill,
          onPressed: () => onNotice(
            'Post creation is part of the next preview step.',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.small,
              AppSpacing.small,
              12,
              AppSpacing.small,
            ),
            child: Row(
              children: [
                const AppAvatar.asset(
                  assetName: 'assets/images/current-user.jpg',
                  displayName: 'Prince Adeyemi',
                ),
                const SizedBox(width: AppSpacing.xsmall),
                Expanded(
                  child: Text(
                    'Share a property, Make a request or say something...',
                    style: AppTypography.hint(colors),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
