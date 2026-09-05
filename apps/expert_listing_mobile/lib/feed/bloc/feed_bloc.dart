// Private dependencies retain product-language argument names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// Coordinates ordered first-page, refresh, filter, and cursor feed work.
final class FeedBloc extends Bloc<FeedEvent, FeedState> {
  /// Creates the feed state machine.
  FeedBloc({required FeedRepository repository})
    : _repository = repository,
      super(FeedState.initial) {
    on<FeedStarted>((_, emit) => _loadFirstPage(emit));
    on<FeedRefreshed>((_, emit) => _loadFirstPage(emit, keepVisible: true));
    on<FeedFiltersApplied>((event, emit) {
      return _loadFirstPage(emit, filter: event.filter);
    });
    on<FeedFiltersCleared>(
      (_, emit) => _loadFirstPage(emit, filter: const FeedFilter()),
    );
    on<FeedNextPageRequested>(_loadNextPage);
    on<FeedRetryRequested>(
      (_, emit) => _loadFirstPage(emit, keepVisible: state.posts.isNotEmpty),
    );
  }

  final FeedRepository _repository;
  int _requestGeneration = 0;

  Future<void> _loadFirstPage(
    Emitter<FeedState> emit, {
    FeedFilter? filter,
    bool keepVisible = false,
  }) async {
    final activeFilter = filter ?? state.filter;
    if (activeFilter == state.filter &&
        (state.isInitialLoading || state.isRefreshing)) {
      return;
    }
    final generation = ++_requestGeneration;
    final hasVisiblePosts = keepVisible && state.posts.isNotEmpty;

    emit(
      state.copyWith(
        posts: hasVisiblePosts ? state.posts : const [],
        filter: activeFilter,
        clearNextCursor: true,
        isInitialLoading: !hasVisiblePosts,
        isRefreshing: hasVisiblePosts,
        isLoadingMore: false,
        clearFailure: true,
        refreshFailed: false,
        nextPageFailed: false,
      ),
    );

    try {
      final page = await _repository.loadPage(filter: activeFilter);
      if (generation != _requestGeneration) return;

      emit(
        state.copyWith(
          posts: page.posts,
          nextCursor: page.nextCursor,
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          source: page.source,
          savedAt: page.savedAt,
          fallbackReason: page.fallbackReason,
          clearSavedProvenance: page.source == FeedDataSource.network,
          clearFailure: true,
          refreshFailed: false,
          nextPageFailed: false,
        ),
      );
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      final failure = error is FeedLoadFailure
          ? error
          : const FeedLoadFailure(FeedFailureKind.unavailable);

      emit(
        state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          failure: hasVisiblePosts ? null : failure,
          clearFailure: hasVisiblePosts,
          refreshFailed: hasVisiblePosts,
        ),
      );
    }
  }

  Future<void> _loadNextPage(
    FeedNextPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore) {
      return;
    }

    final generation = _requestGeneration;
    emit(state.copyWith(isLoadingMore: true, nextPageFailed: false));
    try {
      final page = await _repository.loadPage(
        filter: state.filter,
        cursor: cursor,
      );
      if (generation != _requestGeneration) return;

      final posts = _mergeUniquePosts(state.posts, page.posts);
      final retainsSavedProvenance = state.isShowingSavedPosts;
      emit(
        state.copyWith(
          posts: posts,
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          source: retainsSavedProvenance ? state.source : page.source,
          savedAt: retainsSavedProvenance ? state.savedAt : page.savedAt,
          fallbackReason: retainsSavedProvenance
              ? state.fallbackReason
              : page.fallbackReason,
          clearSavedProvenance:
              !retainsSavedProvenance && page.source == FeedDataSource.network,
          nextPageFailed: false,
        ),
      );
    } on Object {
      if (generation != _requestGeneration) return;
      emit(state.copyWith(isLoadingMore: false, nextPageFailed: true));
    }
  }

  List<FeedPost> _mergeUniquePosts(
    List<FeedPost> current,
    List<FeedPost> incoming,
  ) {
    final postIds = current.map((post) => post.id).toSet();
    final merged = [...current];
    for (final post in incoming) {
      if (postIds.add(post.id)) merged.add(post);
    }
    return merged;
  }
}
