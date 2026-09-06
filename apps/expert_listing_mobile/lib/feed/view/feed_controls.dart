import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Pins the saved-feed status above feed content.
final class FeedOfflineBarDelegate extends SliverPersistentHeaderDelegate {
  /// Creates the saved-feed status delegate.
  const FeedOfflineBarDelegate({
    required this.height,
    required this.message,
    required this.onRetry,
  });

  /// The platform-adjusted status-bar height.
  final double height;

  /// The saved-feed status message.
  final String message;

  /// Retries the first feed page.
  final VoidCallback onRetry;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => OfflineStatusBar(message: message, onRetry: onRetry);

  @override
  bool shouldRebuild(FeedOfflineBarDelegate oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.message != message ||
      oldDelegate.onRetry != onRetry;
}

/// Opens feed filters and reports the number currently active.
final class FeedFilterControl extends StatelessWidget {
  /// Creates the feed filter control.
  const FeedFilterControl({
    required this.activeCount,
    required this.onPressed,
    super.key,
  });

  /// The number of active filters.
  final int activeCount;

  /// Opens the filter sheet.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = activeCount == 0 ? 'Filters' : 'Filters ($activeCount)';
    final semanticsLabel = activeCount == 0
        ? 'Filters'
        : 'Filters, $activeCount active';
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          AppIcons.filter,
          size: AppIconSize.small,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.small),
        Text(
          label,
          style: AppTypography.postBody(
            colors,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
    final borderRadius = BorderRadius.circular(AppIconSize.tapTarget / 2);
    final borderSide = BorderSide(
      color: colors.textPrimary.withValues(alpha: 0.1),
    );

    return Padding(
      // Measured filter row: 24px side insets, 16px above the pill, and no
      // bottom padding because the create-post prompt supplies the gap.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxlarge,
        AppSpacing.large,
        AppSpacing.xxlarge,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: context.isIos
            ? AppPressable(
                key: const ValueKey<String>('feed-filters'),
                onPressed: onPressed,
                semanticLabel: semanticsLabel,
                borderRadius: borderRadius,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppIconSize.tapTarget,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const ValueKey<String>('feed-filters-pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.fromBorderSide(borderSide),
                    ),
                    child: content,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: semanticsLabel,
                    button: true,
                    enabled: true,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      key: const ValueKey<String>('feed-filters'),
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.small,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        foregroundColor: colors.textSecondary,
                        side: borderSide,
                        shape: const StadiumBorder(),
                      ),
                      child: KeyedSubtree(
                        key: const ValueKey<String>('feed-filters-pill'),
                        child: content,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Announces a transient status inline with the feed slivers.
final class FeedInlineStatus extends StatelessWidget {
  /// Creates an inline feed status.
  const FeedInlineStatus({required this.message, super.key});

  /// The status message.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
