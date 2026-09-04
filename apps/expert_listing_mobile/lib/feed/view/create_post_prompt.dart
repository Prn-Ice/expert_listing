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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        0,
        AppSpacing.xlarge,
        AppSpacing.medium,
      ),
      child: SizedBox(
        height: 56,
        child: Material(
          color: colors.subtleSurface,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: () => onNotice(
              'Post creation is part of the next preview step.',
            ),
            borderRadius: AppRadii.pill,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Row(
                children: [
                  const AppAvatar.asset(
                    assetName: 'assets/images/current-user.jpg',
                    displayName: 'Prince Adeyemi',
                  ),
                  const SizedBox(width: AppSpacing.small),
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
      ),
    );
  }
}
