import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/create_post/create_post_sheet.dart';
import 'package:expert_listing/feed/bloc/feed_bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/comments/comments_sheet.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/post_details.dart';
import 'package:expert_listing/feed/view/create_post_prompt.dart';
import 'package:expert_listing/feed/view/feed_header.dart';
import 'package:expert_listing/feed/view/filter_sheet.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/feed/view/story_strip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// The network-first Expert Listing feed body.
class FeedView extends ConsumerStatefulWidget {
  /// Creates the feed view.
  const FeedView({required this.scrollController, super.key});

  /// The dashboard-owned primary controller for this feed.
  final ScrollController scrollController;

  @override
  ConsumerState<FeedView> createState() => FeedViewState();
}

/// Owns feed scroll position and the feed-specific lifecycle.
class FeedViewState extends ConsumerState<FeedView> {
  FeedBloc? _startedBloc;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_loadMoreWhenNeeded);
  }

  @override
  void didUpdateWidget(FeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == widget.scrollController) return;
    oldWidget.scrollController.removeListener(_loadMoreWhenNeeded);
    widget.scrollController.addListener(_loadMoreWhenNeeded);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_loadMoreWhenNeeded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<FeedState>(feedBlocProvider, _showSavedFeedTransition)
      ..listen<FeedState>(feedBlocProvider, _showEngagementNotice);
    final bloc = ref.watch(feedBlocProvider.bloc);
    if (!identical(bloc, _startedBloc)) {
      _startedBloc = bloc;
      scheduleMicrotask(() {
        if (mounted && identical(bloc, _startedBloc)) {
          bloc.add(const FeedStarted());
        }
      });
    }
    final state = ref.watch(feedBlocProvider);
    final usesCupertinoRefresh = context.isIos;
    final feed = CustomScrollView(
      controller: widget.scrollController,
      key: const PageStorageKey<String>('feed-scroll'),
      // AlwaysScrollable enables refresh on a short feed while the app root
      // still supplies the platform's bouncing or clamping behavior.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (usesCupertinoRefresh)
          CupertinoSliverRefreshControl(onRefresh: _refresh),
        SliverToBoxAdapter(
          child: FeedHeader(
            onLogoPressed: scrollToTop,
            onNotice: _showNotice,
          ),
        ),
        SliverToBoxAdapter(child: StoryStrip(onNotice: _showNotice)),
        SliverToBoxAdapter(
          child: _FilterControl(
            activeCount: state.filter.activeCount,
            onPressed: _openFilters,
          ),
        ),
        SliverToBoxAdapter(
          child: CreatePostPrompt(
            actorIdentity: previewActorIdentity(
              ref.watch(previewActorProvider),
            ),
            onPressed: _openCreatePost,
            showInvitation: state.posts.isNotEmpty,
          ),
        ),
        if (state.isShowingSavedPosts)
          SliverPersistentHeader(
            pinned: true,
            delegate: _OfflineBarDelegate(
              height: OfflineStatusBar.heightFor(context),
              message: state.fallbackReason == FeedFallbackReason.connection
                  ? 'Offline · Showing saved posts'
                  : 'Showing saved posts',
              onRetry: _retryFirstPage,
            ),
          ),
        if (state.refreshFailed)
          const SliverToBoxAdapter(
            child: _InlineStatus(
              message: "Couldn't refresh. Showing the posts already loaded.",
            ),
          ),
        _FeedContent(
          state: state,
          onNotice: _showNotice,
          onRetryFirstPage: _retryFirstPage,
          onRetryNextPage: _retryNextPage,
          onClearFilters: _clearFilters,
          onCreatePost: _openCreatePost,
          onLike: (postId) => bloc.add(FeedLikeToggled(postId)),
          onComments: _openComments,
          onShare: _sharePost,
          onBookmark: (postId) => bloc.add(FeedBookmarkToggled(postId)),
          onOptions: _openPostOptions,
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: usesCupertinoRefresh
          ? feed
          : RefreshIndicator(onRefresh: _refresh, child: feed),
    );
  }

  /// Returns the feed to its top, or refreshes while it is already at top.
  void returnToTopOrRefresh() {
    final controller = widget.scrollController;
    if (!controller.hasClients || controller.offset <= 0) {
      _retryFirstPage();
      return;
    }
    scrollToTop();
  }

  /// Smoothly returns the feed to its top without triggering a refresh.
  void scrollToTop() {
    final controller = widget.scrollController;
    if (!controller.hasClients || controller.offset <= 0) return;
    _moveToTop(controller);
  }

  Future<void> _refresh() async {
    final bloc = ref.read(feedBlocProvider.bloc);
    await (bloc..add(const FeedRefreshed())).stream.firstWhere(
      (state) => !state.isRefreshing && !state.isInitialLoading,
    );
  }

  void _retryFirstPage() =>
      ref.read(feedBlocProvider.bloc).add(const FeedRetryRequested());

  void _retryNextPage() =>
      ref.read(feedBlocProvider.bloc).add(const FeedNextPageRequested());

  void _loadMoreWhenNeeded() {
    if (widget.scrollController.position.extentAfter < 360) {
      // A failed next page waits for the visible Try again control; automatic
      // pagination must not retry on its own.
      if (ref.read(feedBlocProvider).nextPageFailed) return;
      _retryNextPage();
    }
  }

  Future<void> _openFilters() async {
    final state = ref.read(feedBlocProvider);
    final filter = await showFeedFilterSheet(context, filter: state.filter);
    if (!mounted || filter == null) return;
    ref
        .read(feedBlocProvider.bloc)
        .add(
          filter.isEmpty
              ? const FeedFiltersCleared()
              : FeedFiltersApplied(filter),
        );
    if (widget.scrollController.hasClients) {
      _moveToTop(widget.scrollController);
    }
  }

  void _clearFilters() =>
      ref.read(feedBlocProvider.bloc).add(const FeedFiltersCleared());

  Future<void> _openCreatePost() async {
    final post = await showCreatePostSheet(context);
    if (!mounted || post == null) return;
    ref.read(feedBlocProvider.bloc).add(FeedPostCreated(post));
    AppNotice.show(context, 'Post published.');
    if (ref.read(feedBlocProvider).filter.isEmpty &&
        widget.scrollController.hasClients) {
      scrollToTop();
    }
  }

  void _showSavedFeedTransition(FeedState? previous, FeedState next) {
    if (previous == null) return;
    if (context.isIos && !previous.refreshFailed && next.refreshFailed) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          "Couldn't refresh. Showing the posts already loaded.",
          Directionality.of(context),
        ),
      );
    }
    if (!previous.isShowingSavedPosts &&
        next.isShowingSavedPosts &&
        next.fallbackReason == FeedFallbackReason.service) {
      AppNotice.show(context, 'Service unavailable. Showing saved posts.');
    }
    if (previous.isShowingSavedPosts &&
        !next.isShowingSavedPosts &&
        previous.fallbackReason == FeedFallbackReason.connection &&
        next.source == FeedDataSource.network) {
      AppNotice.show(context, 'Back online. Feed updated.');
    }
  }

  void _showEngagementNotice(FeedState? previous, FeedState next) {
    if (previous?.noticeSequence == next.noticeSequence ||
        next.notice == null) {
      return;
    }
    AppNotice.show(context, next.notice!);
  }

  Future<void> _openComments(FeedPost post) async {
    await AppSheet.show<void>(
      context,
      child: CommentsSheet(postId: post.id),
    );
  }

  Future<void> _sharePost(FeedPost post, BuildContext sourceContext) async {
    final box = sourceContext.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: postDetailsText(post),
          sharePositionOrigin: origin,
        ),
      );
    } on Object {
      if (mounted) {
        AppNotice.show(context, "Sharing isn't available right now.");
      }
    }
  }

  Future<void> _openPostOptions(FeedPost post) async {
    final action = await AppSheet.show<_PostOption>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Post options',
              style: AppTypography.title(AppColors.of(context)),
            ),
            const SizedBox(height: AppSpacing.medium),
            AppButton(
              minimumSize: const Size.fromHeight(AppIconSize.tapTarget),
              alignment: Alignment.centerLeft,
              onPressed: () => Navigator.pop(
                context,
                _PostOption.copyDetails,
              ),
              child: const Text('Copy post details'),
            ),
            AppButton(
              minimumSize: const Size.fromHeight(AppIconSize.tapTarget),
              alignment: Alignment.centerLeft,
              onPressed: () => Navigator.pop(context, _PostOption.hide),
              child: const Text('Hide this post'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PostOption.copyDetails:
        await Clipboard.setData(ClipboardData(text: postDetailsText(post)));
        if (mounted) AppNotice.show(context, 'Post details copied.');
      case _PostOption.hide:
        ref.read(feedBlocProvider.bloc).add(FeedPostHidden(post.id));
        AppNotice.show(
          context,
          'Post hidden.',
          actionLabel: 'Undo',
          onAction: () =>
              ref.read(feedBlocProvider.bloc).add(FeedPostRestored(post.id)),
        );
    }
  }

  void _showNotice(String message) => AppNotice.show(context, message);

  void _moveToTop(ScrollController controller) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      controller.jumpTo(0);
      return;
    }
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

final class _OfflineBarDelegate extends SliverPersistentHeaderDelegate {
  const _OfflineBarDelegate({
    required this.height,
    required this.message,
    required this.onRetry,
  });

  final double height;
  final String message;
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
  bool shouldRebuild(_OfflineBarDelegate oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.message != message ||
      oldDelegate.onRetry != onRetry;
}

final class _FilterControl extends StatelessWidget {
  const _FilterControl({required this.activeCount, required this.onPressed});

  final int activeCount;
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

final class _FeedContent extends StatelessWidget {
  const _FeedContent({
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
  });

  final FeedState state;
  final ValueChanged<String> onNotice;
  final VoidCallback onRetryFirstPage;
  final VoidCallback onRetryNextPage;
  final VoidCallback onClearFilters;
  final VoidCallback onCreatePost;
  final ValueChanged<int> onLike;
  final ValueChanged<FeedPost> onComments;
  final void Function(FeedPost post, BuildContext context) onShare;
  final ValueChanged<int> onBookmark;
  final ValueChanged<FeedPost> onOptions;

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
              onOptions: () => onOptions(state.visiblePosts[index]),
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

enum _PostOption { copyDetails, hide }

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

final class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message});

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
