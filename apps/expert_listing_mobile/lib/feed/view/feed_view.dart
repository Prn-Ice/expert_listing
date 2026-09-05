import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/view/create_post_prompt.dart';
import 'package:expert_listing/feed/view/feed_header.dart';
import 'package:expert_listing/feed/view/filter_sheet.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/feed/view/story_strip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_loadMoreWhenNeeded);
    ref.read(feedBlocProvider.bloc).add(const FeedStarted());
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
    ref.listen<FeedState>(feedBlocProvider, _showSavedFeedTransition);
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
            onNotice: _showNotice,
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
        child: AppPressable(
          key: const ValueKey<String>('feed-filters'),
          onPressed: onPressed,
          semanticLabel: activeCount == 0
              ? 'Filters'
              : 'Filters, $activeCount active',
          borderRadius: BorderRadius.circular(AppIconSize.tapTarget / 2),
          child: Container(
            // The genuine 48px activation region surrounds the measured
            // 36px pill without moving visible content.
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
                borderRadius: BorderRadius.circular(AppIconSize.tapTarget / 2),
                border: Border.all(
                  color: colors.textPrimary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcons.filter,
                    size: AppIconSize.small,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Text(
                    activeCount == 0 ? 'Filters' : 'Filters ($activeCount)',
                    style: AppTypography.postBody(
                      colors,
                      color: colors.textSecondary,
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

final class _FeedContent extends StatelessWidget {
  const _FeedContent({
    required this.state,
    required this.onNotice,
    required this.onRetryFirstPage,
    required this.onRetryNextPage,
    required this.onClearFilters,
  });

  final FeedState state;
  final ValueChanged<String> onNotice;
  final VoidCallback onRetryFirstPage;
  final VoidCallback onRetryNextPage;
  final VoidCallback onClearFilters;

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

    if (state.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _FeedEmpty(
          isFiltered: !state.filter.isEmpty,
          onClear: onClearFilters,
          onNotice: onNotice,
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: state.posts.length,
          itemBuilder: (context, index) => KeyedSubtree(
            key: ValueKey(state.posts[index].id),
            child: PostCard(post: state.posts[index], onNotice: onNotice),
          ),
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (state.nextPageFailed)
          SliverToBoxAdapter(
            child: Center(
              child: AppButton(
                onPressed: onRetryNextPage,
                minimumSize: const Size(64, 48),
                child: const Text('Try again'),
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
    required this.onNotice,
  });

  final bool isFiltered;
  final VoidCallback onClear;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isFiltered ? 'No posts match these filters.' : 'No posts yet.'),
          const SizedBox(height: AppSpacing.medium),
          FilledButton(
            onPressed: isFiltered
                ? onClear
                : () => onNotice(
                    'Post creation is part of the next preview step.',
                  ),
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
