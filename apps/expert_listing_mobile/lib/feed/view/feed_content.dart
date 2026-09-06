import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:flutter/material.dart';

/// Renders the feed posts and their loading, empty, and failure states.
class FeedContent extends StatelessWidget {
  /// Creates the feed content sliver.
  const FeedContent({
    required this.state,
    required this.onNotice,
    required this.onRetryFirstPage,
    required this.onRetryNextPage,
    required this.onClearFilters,
    required this.onCreatePost,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onBookmark,
    required this.onOptions,
    super.key,
  });

  /// The current feed state.
  final FeedState state;

  /// Shows a short feed notice.
  final ValueChanged<String> onNotice;

  /// Retries the first feed page.
  final VoidCallback onRetryFirstPage;

  /// Retries the next feed page.
  final VoidCallback onRetryNextPage;

  /// Clears the active filters.
  final VoidCallback onClearFilters;

  /// Opens the create-post surface.
  final VoidCallback onCreatePost;

  /// Changes the desired like state for a post ID.
  final ValueChanged<int> onLike;

  /// Opens comments for a post.
  final ValueChanged<FeedPost> onComments;

  /// Shares a post from the source control's render context.
  final void Function(FeedPost post, BuildContext context) onShare;

  /// Changes the local bookmark state for a post ID.
  final ValueChanged<int> onBookmark;

  /// Opens post options from the source control's render context.
  final void Function(FeedPost post, BuildContext context) onOptions;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (state.failure != null && state.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _FeedFailure(
          failure: state.failure!,
          onRetry: onRetryFirstPage,
        ),
      );
    }

    if (state.visiblePosts.isEmpty && state.posts.isNotEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No posts left in this session.'),
              if (state.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.large),
                  child: CircularProgressIndicator.adaptive(),
                )
              else if (state.canLoadMore)
                AppButton(
                  minimumSize: const Size(64, 48),
                  onPressed: onRetryNextPage,
                  child: Text(state.nextPageFailed ? 'Try again' : 'Load more'),
                ),
            ],
          ),
        ),
      );
    }

    if (state.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _FeedEmpty(
          isFiltered: !state.filter.isEmpty,
          onClear: onClearFilters,
          onCreatePost: onCreatePost,
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: state.visiblePosts.length,
          itemBuilder: (context, index) => KeyedSubtree(
            key: ValueKey(state.visiblePosts[index].id),
            child: PostCard(
              post: state.visiblePosts[index],
              onNotice: onNotice,
              bookmarked: state.bookmarkedPostIds.contains(
                state.visiblePosts[index].id,
              ),
              onLike: () => onLike(state.visiblePosts[index].id),
              onComments: () => onComments(state.visiblePosts[index]),
              onShare: (sourceContext) =>
                  onShare(state.visiblePosts[index], sourceContext),
              onBookmark: () => onBookmark(state.visiblePosts[index].id),
              onOptions: (sourceContext) =>
                  onOptions(state.visiblePosts[index], sourceContext),
            ),
          ),
        ),
        if (state.canLoadMore || state.isLoadingMore || state.nextPageFailed)
          SliverToBoxAdapter(
            child: SizedBox(
              key: const ValueKey<String>('feed-pagination-footer'),
              height: AppIconSize.tapTarget + (AppSpacing.large * 2),
              child: Center(
                child: state.isLoadingMore
                    ? const CircularProgressIndicator.adaptive()
                    : state.nextPageFailed
                    ? AppButton(
                        onPressed: onRetryNextPage,
                        minimumSize: const Size(64, 48),
                        child: const Text('Try again'),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

final class _FeedFailure extends StatelessWidget {
  const _FeedFailure({required this.failure, required this.onRetry});

  final FeedLoadFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
      FeedFailureKind.connection =>
        "You're offline. Reconnect to load the feed.",
      FeedFailureKind.service => 'Feed unavailable. Try again.',
      FeedFailureKind.unavailable => "Couldn't load the feed.",
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxlarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.medium),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

final class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({
    required this.isFiltered,
    required this.onClear,
    required this.onCreatePost,
  });

  final bool isFiltered;
  final VoidCallback onClear;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isFiltered ? 'No posts match these filters.' : 'No posts yet.'),
          const SizedBox(height: AppSpacing.medium),
          FilledButton(
            onPressed: isFiltered ? onClear : onCreatePost,
            child: Text(isFiltered ? 'Clear filters' : 'Create a post'),
          ),
        ],
      ),
    );
  }
}
