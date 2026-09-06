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
import 'package:expert_listing/feed/view/feed_content.dart';
import 'package:expert_listing/feed/view/feed_controls.dart';
import 'package:expert_listing/feed/view/feed_header.dart';
import 'package:expert_listing/feed/view/filter_sheet.dart';
import 'package:expert_listing/feed/view/post_options_menu.dart';
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
          child: FeedFilterControl(
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
            delegate: FeedOfflineBarDelegate(
              height: OfflineStatusBar.heightFor(context),
              message: state.fallbackReason == FeedFallbackReason.connection
                  ? 'Offline · Showing saved posts'
                  : 'Showing saved posts',
              onRetry: _retryFirstPage,
            ),
          ),
        if (state.refreshFailed)
          const SliverToBoxAdapter(
            child: FeedInlineStatus(
              message: "Couldn't refresh. Showing the posts already loaded.",
            ),
          ),
        FeedContent(
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

  Future<void> _openPostOptions(
    FeedPost post,
    BuildContext sourceContext,
  ) async {
    final source = sourceContext.findRenderObject();
    final overlay = Navigator.of(
      sourceContext,
      rootNavigator: true,
    ).overlay?.context.findRenderObject();
    if (source is! RenderBox || !source.hasSize || overlay is! RenderBox) {
      return;
    }
    final sourceRect =
        source.localToGlobal(
          Offset.zero,
          ancestor: overlay,
        ) &
        source.size;
    final action = await showPostOptionsMenu(
      sourceContext,
      sourceRect: sourceRect,
      overlaySize: overlay.size,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case PostOption.copyDetails:
        await Clipboard.setData(ClipboardData(text: postDetailsText(post)));
        if (mounted) AppNotice.show(context, 'Post details copied.');
      case PostOption.hide:
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
