// PostCard fields are the directly rendered post and notice callback.
// ignore_for_file: public_member_api_docs

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/feed/view/post_actions.dart';
import 'package:expert_listing/feed/view/property_media.dart';
import 'package:flutter/material.dart';

const double _postInset = AppSpacing.xlarge;
const _postAvatarSize = 40.0;
const double _postContentInset =
    _postInset + _postAvatarSize + AppSpacing.small;

/// A Figma-aligned feed row for every hydrated post variant.
class PostCard extends StatelessWidget {
  /// Creates a feed post card.
  const PostCard({
    required this.post,
    required this.onNotice,
    super.key,
    this.bookmarked = false,
    this.onLike,
    this.onComments,
    this.onShare,
    this.onBookmark,
    this.onOptions,
  });

  final FeedPost post;
  final ValueChanged<String> onNotice;
  final bool bookmarked;
  final VoidCallback? onLike;
  final VoidCallback? onComments;
  final ValueChanged<BuildContext>? onShare;
  final VoidCallback? onBookmark;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Let centered edge targets use the adjacent outer space so their visible
    // content stays on the post edge whether or not a count is present.
    final actionTargetLeftInset =
        _postContentInset -
        (post.likeCount == 0 ? AppSpacing.large : AppSpacing.small);
    final actionTargetRightInset = post.bookmarkCount == 0
        ? _postInset - AppSpacing.large
        : _postInset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _postInset,
            AppSpacing.medium,
            _postInset,
            0,
          ),
          child: _PostHeader(
            post: post,
            onNotice: onNotice,
            onOptions: onOptions,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: _postContentInset,
            right: _postInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xsmall),
              Text(post.body, style: AppTypography.postBody(colors)),
              const SizedBox(height: AppSpacing.small),
              _PostDetails(post: post),
              if (post case final PropertyFeedPost property
                  when property.images.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.small),
                PropertyMedia(images: property.images),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            actionTargetLeftInset,
            0,
            actionTargetRightInset,
            0,
          ),
          child: PostActions(
            key: ValueKey<String>('post-actions-${post.id}'),
            post: post,
            onNotice: onNotice,
            bookmarked: bookmarked,
            onLike: onLike,
            onComments: onComments,
            onShare: onShare,
            onBookmark: onBookmark,
          ),
        ),
        if (post.likeCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _postContentInset,
            ),
            child: _LikePreview(post: post),
          ),
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.only(
              left: _postContentInset,
              right: _postInset,
            ),
            child: _CommentsPreview(
              post: post,
              onPressed:
                  onComments ??
                  () => onNotice(
                    'Comments are part of the next preview step.',
                  ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

final class _LikePreview extends StatelessWidget {
  const _LikePreview({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final firstLiker = post.likePreview.isEmpty ? null : post.likePreview.first;
    final others = post.likeCount - 1;
    return ConstrainedBox(
      key: const ValueKey<String>('post-like-preview'),
      constraints: const BoxConstraints(minHeight: 24),
      child: Row(
        children: [
          if (post.likePreview.isNotEmpty) ...[
            _LikerAvatars(authors: post.likePreview.take(3).toList()),
            const SizedBox(width: AppSpacing.small),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTypography.body(colors, color: colors.textSecondary),
                children: [
                  const TextSpan(text: 'Liked by '),
                  if (firstLiker == null)
                    TextSpan(
                      text:
                          '${post.likeCount} '
                          '${post.likeCount == 1 ? 'person' : 'people'}',
                      style: AppTypography.bodyMedium(
                        colors,
                        color: colors.textSecondary,
                      ),
                    )
                  else ...[
                    TextSpan(
                      text: firstLiker.handle,
                      style: AppTypography.bodyMedium(
                        colors,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (others > 0)
                      TextSpan(
                        text:
                            ' and $others '
                            '${others == 1 ? 'other' : 'others'}',
                        style: AppTypography.bodyMedium(
                          colors,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

final class _LikerAvatars extends StatelessWidget {
  const _LikerAvatars({required this.authors});

  final List<FeedAuthor> authors;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const avatarSize = 24.0;
    const avatarRing = 2.0;
    const visibleStep = avatarSize - 6;
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey<String>('post-liker-avatars'),
        width: avatarSize + visibleStep * (authors.length - 1),
        height: avatarSize,
        child: Stack(
          children: [
            for (final (index, author) in authors.indexed)
              Positioned(
                left: visibleStep * index,
                child: SizedBox.square(
                  key: ValueKey<String>('post-liker-avatar-$index'),
                  dimension: avatarSize,
                  child: DecoratedBox(
                    key: ValueKey<String>('post-liker-avatar-ring-$index'),
                    decoration: BoxDecoration(
                      color: colors.canvas,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(avatarRing),
                      child: AppAvatar(
                        imageUrl: author.avatarUrl,
                        displayName: author.displayName,
                        size: avatarSize - avatarRing * 2,
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

final class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({required this.post, required this.onPressed});

  final FeedPost post;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final latest = post.latestComment;
    final commentsLabel = post.commentCount == 1
        ? 'View comments'
        : 'View all ${post.commentCount} comments';
    final semanticsLabel = latest == null
        ? commentsLabel
        : '${latest.author.handle} commented: ${latest.body}. '
              '$commentsLabel';
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        child: AppButton(
          key: ValueKey<String>('post-comments-${post.id}'),
          onPressed: onPressed,
          minimumSize: const Size(0, AppIconSize.tapTarget),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (latest != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.author.handle,
                      style: AppTypography.bodyMedium(colors),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        latest.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(colors),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xsmall),
              ],
              Text(
                commentsLabel,
                style: AppTypography.bodyMedium(
                  colors,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onNotice,
    this.onOptions,
  });

  final FeedPost post;
  final ValueChanged<String> onNotice;
  final VoidCallback? onOptions;

  void _showProfileNotice() =>
      onNotice('Profiles aren’t part of this preview.');

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppIconSize.tapTarget),
      child: Row(
        children: [
          Expanded(
            child: AppPressable(
              key: ValueKey<String>('post-profile-${post.id}'),
              onPressed: _showProfileNotice,
              borderRadius: AppRadii.pill,
              overlayColor: colors.subtleSurface,
              semanticLabel: '${post.author.displayName}, view profile',
              child: Row(
                children: [
                  SizedBox(
                    width: _postAvatarSize,
                    height: AppIconSize.tapTarget,
                    child: Center(
                      child: AppAvatar(
                        imageUrl: post.author.avatarUrl,
                        displayName: post.author.displayName,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                post.author.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.title(colors),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xsmall),
                            Text('·', style: AppTypography.meta(colors)),
                            const SizedBox(width: AppSpacing.xsmall),
                            Flexible(
                              child: Text(
                                post.author.role,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                  colors,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_postTypeLabel(post.postType)}  ·  '
                          '${_timeAgo(post.createdAt)}',
                          style: AppTypography.meta(colors),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppIconButton(
            key: ValueKey<String>('post-overflow-${post.id}'),
            icon: AppIcons.postOverflow,
            iconSize: AppIconSize.small,
            tooltip: 'Post options',
            onPressed:
                onOptions ??
                () => onNotice(
                  'Post options are part of the next preview step.',
                ),
          ),
        ],
      ),
    );
  }
}

final class _PostDetails extends StatelessWidget {
  const _PostDetails({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.mapPin,
              size: AppIconSize.small,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xsmall),
            Flexible(
              child: Text(
                post.location,
                style: AppTypography.caption(colors),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        _PostTag(post: post),
      ],
    );
  }
}

final class _PostTag extends StatelessWidget {
  const _PostTag({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tag = switch (post) {
      PropertyFeedPost(status: PropertyStatus.forSale) => (
        'For Sale',
        AppIcons.postTag,
        colors.info,
        colors.infoTint,
      ),
      PropertyFeedPost(status: PropertyStatus.forRent) => (
        'For Rent',
        AppIcons.propertyRentKey,
        colors.brandText,
        colors.brandTint,
      ),
      RequestFeedPost(requestType: RequestType.lookingToBuy) => (
        'Looking to Buy',
        AppIcons.lookingToBuyTag,
        colors.accent,
        colors.accentTint,
      ),
      RequestFeedPost(requestType: RequestType.lookingToRent) => (
        'Looking to Rent',
        AppIcons.lookingToRentKey,
        colors.warm,
        colors.warmTint,
      ),
      GeneralFeedPost() => null,
    };
    if (tag == null) return const SizedBox.shrink();
    final (label, icon, foreground, background) = tag;

    return Container(
      key: ValueKey<String>('post-tag-${post.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.xsmall,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.xsmall),
          Text(label, style: AppTypography.caption(colors, color: foreground)),
        ],
      ),
    );
  }
}

String _postTypeLabel(PostType postType) => switch (postType) {
  PostType.general => 'General',
  PostType.request => 'Request',
  PostType.property => 'Property',
};

String _timeAgo(DateTime value) {
  final elapsed = DateTime.now().toUtc().difference(value);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  return '${elapsed.inDays}d';
}
