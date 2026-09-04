// PostCard fields are the directly rendered post and notice callback.
// ignore_for_file: public_member_api_docs

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Figma-aligned feed row for every hydrated post variant.
class PostCard extends StatelessWidget {
  /// Creates a feed post card.
  const PostCard({
    required this.post,
    required this.onNotice,
    super.key,
  });

  final FeedPost post;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.medium,
            AppSpacing.xlarge,
            AppSpacing.medium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: ValueKey<String>('author-avatar-${post.id}'),
                child: AppAvatar(
                  imageUrl: post.author.avatarUrl,
                  displayName: post.author.displayName,
                  onPressed: _showProfileNotice,
                ),
              ),
              const SizedBox(width: AppSpacing.xsmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostHeading(post: post, onNotice: onNotice),
                    const SizedBox(height: AppSpacing.xsmall),
                    Text(post.body, style: AppTypography.postBody(colors)),
                    const SizedBox(height: AppSpacing.small),
                    _PostDetails(post: post),
                    if (post case final PropertyFeedPost property
                        when property.images.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.small),
                      _PropertyMedia(images: property.images),
                    ],
                    const SizedBox(height: AppSpacing.small),
                    _PostActions(post: post, onNotice: onNotice),
                    if (post.commentCount > 0) ...[
                      const SizedBox(height: AppSpacing.xsmall),
                      SizedBox(
                        height: AppIconSize.tapTarget,
                        child: TextButton(
                          onPressed: () => onNotice(
                            'Comments are part of the next preview step.',
                          ),
                          child: Text(
                            'View all ${post.commentCount} comments',
                            style: AppTypography.bodyStrong(colors),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _showProfileNotice() =>
      onNotice('Profiles are not part of this preview.');
}

final class _PostHeading extends StatelessWidget {
  const _PostHeading({required this.post, required this.onNotice});

  final FeedPost post;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: AppIconSize.tapTarget,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: ValueKey<String>('author-name-${post.id}'),
              onPressed: () =>
                  onNotice('Profiles are not part of this preview.'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
          ),
          SizedBox.square(
            key: ValueKey<String>('post-overflow-${post.id}'),
            dimension: AppIconSize.tapTarget,
            child: AppIconButton(
              icon: AppIcons.postOverflow,
              iconSize: AppIconSize.small,
              tooltip: 'Post options',
              onPressed: () =>
                  onNotice('Post options are part of the next preview step.'),
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
            Text(post.location, style: AppTypography.caption(colors)),
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

final class _PropertyMedia extends StatefulWidget {
  const _PropertyMedia({required this.images});

  final List<PropertyImage> images;

  @override
  State<_PropertyMedia> createState() => _PropertyMediaState();
}

final class _PropertyMediaState extends State<_PropertyMedia> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images.where((image) => image.url != null).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Figma's property media box is 388 by 260 at the reference width.
        final height = constraints.maxWidth * 260 / 388;
        return Column(
          children: [
            SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: AppRadii.image,
                child: PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return InkWell(
                      onTap: () => _showImage(
                        context,
                        image.url!,
                        index: index,
                        imageCount: images.length,
                      ),
                      child: AppNetworkImage(
                        imageUrl: image.url!,
                        semanticLabel:
                            'Property photo ${index + 1} of ${images.length}',
                        placeholder: ColoredBox(
                          color: AppColors.of(context).surface,
                        ),
                        fallback: ColoredBox(
                          color: AppColors.of(context).surface,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: AppSpacing.xsmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppColors.of(context).brandDeep
                          : AppColors.of(context).border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showImage(
    BuildContext context,
    String url, {
    required int index,
    required int imageCount,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: url,
          semanticLabel: 'Property photo ${index + 1} of $imageCount',
        ),
      ),
    );
  }
}

final class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.semanticLabel,
  });

  final String imageUrl;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: overlayStyle,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => InteractiveViewer(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: AppNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              fallback: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PostActions extends StatelessWidget {
  const _PostActions({required this.post, required this.onNotice});

  final FeedPost post;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        _Action(
          icon: AppIcons.heart,
          label: post.likeCount == 0 ? null : '${post.likeCount}',
          tooltip: 'Like',
          onPressed: () => onNotice('Likes are part of the next preview step.'),
        ),
        _Action(
          icon: AppIcons.comment,
          label: post.commentCount == 0 ? null : '${post.commentCount}',
          tooltip: 'Comments',
          onPressed: () =>
              onNotice('Comments are part of the next preview step.'),
        ),
        _Action(
          icon: AppIcons.share,
          tooltip: 'Share',
          onPressed: () => onNotice('Sharing is not available right now.'),
        ),
        if (post.viewCount > 0)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_viewCount(post.viewCount)} Views',
                  style: AppTypography.caption(colors),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        _Action(
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

final class _Action extends StatelessWidget {
  const _Action({
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
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
