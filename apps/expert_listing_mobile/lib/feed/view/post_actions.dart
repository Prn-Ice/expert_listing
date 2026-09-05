import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:flutter/material.dart';

/// The engagement, views, and bookmark row for one feed post.
class PostActions extends StatelessWidget {
  /// Creates the post action row.
  const PostActions({required this.post, required this.onNotice, super.key});

  /// The post whose counts are rendered.
  final FeedPost post;

  /// Shows the current boundary response for deferred actions.
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        _PostActionButton(
          icon: AppIcons.heart,
          label: post.likeCount == 0 ? null : '${post.likeCount}',
          tooltip: 'Like',
          onPressed: () => onNotice('Likes are part of the next preview step.'),
        ),
        _PostActionButton(
          icon: AppIcons.comment,
          label: post.commentCount == 0 ? null : '${post.commentCount}',
          tooltip: 'Comments',
          onPressed: () =>
              onNotice('Comments are part of the next preview step.'),
        ),
        _PostActionButton(
          icon: AppIcons.share,
          tooltip: 'Share',
          onPressed: () => onNotice('Sharing is not available right now.'),
        ),
        if (post.viewCount > 0)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_viewCount(post.viewCount)} Views',
                  key: ValueKey<String>('post-views-${post.id}'),
                  style: AppTypography.caption(colors),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        _PostActionButton(
          icon: AppIcons.bookmark,
          label: post.bookmarkCount == 0 ? null : '${post.bookmarkCount}',
          tooltip: 'Bookmark',
          onPressed: () =>
              onNotice('Bookmarks are part of the next preview step.'),
        ),
      ],
    );
  }
}

final class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final semanticLabel = label == null ? tooltip : '$tooltip, $label';
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: SizedBox(
        height: AppIconSize.tapTarget,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            alignment: Alignment.center,
            minimumSize: const Size.square(AppIconSize.tapTarget),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Semantics(
            label: semanticLabel,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: AppIconSize.small,
                  color: colors.textSecondary,
                ),
                if (label != null) ...[
                  const SizedBox(width: AppSpacing.xsmall),
                  Text(label!, style: AppTypography.caption(colors)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _viewCount(int count) {
  if (count >= 1000) {
    final compact = (count / 1000).toStringAsFixed(1);
    final withoutTrailingDecimal = compact.endsWith('.0')
        ? compact.substring(0, compact.length - 2)
        : compact;
    return '${withoutTrailingDecimal}K';
  }
  return '$count';
}
