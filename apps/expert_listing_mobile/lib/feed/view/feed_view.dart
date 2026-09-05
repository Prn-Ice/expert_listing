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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The network-first Expert Listing feed body.
class FeedView extends ConsumerStatefulWidget {
  /// Creates the feed view.
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => FeedViewState();
}

/// Owns feed scroll position and the feed-specific lifecycle.
class FeedViewState extends ConsumerState<FeedView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    ref.read(feedBlocProvider.bloc).add(const FeedStarted());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(feedBlocProvider, _showSavedFeedTransition);
    final state = ref.watch(feedBlocProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey<String>('feed-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                  message: state.fallbackReason == FeedFallbackReason.connection
                      ? 'Offline · Showing saved posts'
                      : 'Showing saved posts',
                  onRetry: _retryFirstPage,
                ),
              ),
            if (state.refreshFailed)
              const SliverToBoxAdapter(
                child: _InlineStatus(
                  message:
                      "Couldn't refresh. Showing the posts already loaded.",
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
        ),
      ),
    );
  }

  /// Returns the feed to its top, or refreshes while it is already at top.
  void returnToTopOrRefresh() {
    if (!_scrollController.hasClients || _scrollController.offset <= 0) {
      _retryFirstPage();
      return;
    }
    scrollToTop();
  }

  /// Smoothly returns the feed to its top without triggering a refresh.
  void scrollToTop() {
    if (!_scrollController.hasClients || _scrollController.offset <= 0) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
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
    if (_scrollController.position.extentAfter < 360) {
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearFilters() =>
      ref.read(feedBlocProvider.bloc).add(const FeedFiltersCleared());

  void _showSavedFeedTransition(FeedState? previous, FeedState next) {
    if (previous == null) return;
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
}

final class _OfflineBarDelegate extends SliverPersistentHeaderDelegate {
  const _OfflineBarDelegate({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  double get maxExtent => OfflineStatusBar.height;

  @override
  double get minExtent => OfflineStatusBar.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => OfflineStatusBar(message: message, onRetry: onRetry);

  @override
  bool shouldRebuild(_OfflineBarDelegate oldDelegate) =>
      oldDelegate.message != message || oldDelegate.onRetry != onRetry;
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
          semanticLabel: 'Filters',
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
