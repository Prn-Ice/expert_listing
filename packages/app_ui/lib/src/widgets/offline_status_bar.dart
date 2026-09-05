import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/icons.dart';
import 'package:app_ui/src/tokens/spacing.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A persistent strip describing saved or stale feed provenance.
///
/// Unlike AppNotice this stays on screen while its condition holds; the
/// owning feature decides visibility.
class OfflineStatusBar extends StatelessWidget {
  /// Creates the provenance strip.
  const OfflineStatusBar({
    required this.message,
    super.key,
    this.onRetry,
  });

  /// The provenance description, for example "Showing saved posts.".
  final String message;

  /// Retries the active network request without hiding saved provenance.
  final VoidCallback? onRetry;

  /// The measured strip height: a 32px text-button control with 4px of
  /// breathing room on each side. Retry keeps the 32px text-button hit
  /// region, like every other text control in the design system.
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.xsmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.meta(colors),
                ),
              ),
              if (onRetry != null)
                SizedBox(
                  height: AppIconSize.textButtonTapTarget,
                  child: Center(
                    child: TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(
                          AppIconSize.textButtonTapTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.small,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
