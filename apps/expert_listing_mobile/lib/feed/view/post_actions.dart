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
    final like = AppIconButton(
      icon: AppIcons.heart,
      iconSize: AppIconSize.small,
      color: colors.textSecondary,
      label: post.likeCount == 0 ? null : '${post.likeCount}',
      tooltip: 'Like',
      onPressed: () => onNotice('Likes are part of the next preview step.'),
    );
    final comments = AppIconButton(
      icon: AppIcons.comment,
      iconSize: AppIconSize.small,
      color: colors.textSecondary,
      label: post.commentCount == 0 ? null : '${post.commentCount}',
      tooltip: 'Comments',
      onPressed: () => onNotice('Comments are part of the next preview step.'),
    );
    final share = AppIconButton(
      icon: AppIcons.share,
      iconSize: AppIconSize.small,
      color: colors.textSecondary,
      tooltip: 'Share',
      onPressed: () => onNotice('Sharing is not available right now.'),
    );
    final bookmark = AppIconButton(
      icon: AppIcons.bookmark,
      iconSize: AppIconSize.small,
      color: colors.textSecondary,
      label: post.bookmarkCount == 0 ? null : '${post.bookmarkCount}',
      tooltip: 'Bookmark',
      onPressed: () => onNotice('Bookmarks are part of the next preview step.'),
    );
    final views = Text(
      '${_viewCount(post.viewCount)} Views',
      key: ValueKey<String>('post-views-${post.id}'),
      style: AppTypography.caption(colors),
    );

    if (MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.xsmall,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          like,
          comments,
          share,
          if (post.viewCount > 0) views,
          bookmark,
        ],
      );
    }

    return Row(
      children: [
        like,
        comments,
        share,
        if (post.viewCount > 0)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: views,
            ),
          )
        else
          const Spacer(),
        bookmark,
      ],
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
