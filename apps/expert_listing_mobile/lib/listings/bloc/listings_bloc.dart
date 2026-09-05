// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/listings/bloc/listings_event.dart';
import 'package:expert_listing/listings/bloc/listings_state.dart';

/// Coordinates property-only first-page, refresh, and cursor work.
final class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  /// Creates the independent catalog state machine.
  ListingsBloc({required FeedRepository repository})
    : _repository = repository,
      super(ListingsState.initial) {
    on<ListingsStarted>((_, emit) => _loadFirstPage(emit));
    on<ListingsRefreshed>((_, emit) => _loadFirstPage(emit, keepVisible: true));
    on<ListingsRetryRequested>(
      (_, emit) => _loadFirstPage(emit, keepVisible: state.listings.isNotEmpty),
    );
    on<ListingsNextPageRequested>(_loadNextPage);
  }

  static const _propertyFilter = FeedFilter(postType: PostType.property);
  static const _pageSize = 4;

  final FeedRepository _repository;
  var _generation = 0;

  Future<void> _loadFirstPage(
    Emitter<ListingsState> emit, {
    bool keepVisible = false,
  }) async {
    if (state.isInitialLoading || state.isRefreshing) return;
    final generation = ++_generation;
    final hasVisibleListings = keepVisible && state.listings.isNotEmpty;
    emit(
      state.copyWith(
        listings: hasVisibleListings ? state.listings : const [],
        clearNextCursor: true,
        isInitialLoading: !hasVisibleListings,
        isRefreshing: hasVisibleListings,
        isLoadingMore: false,
        clearFailure: true,
        refreshFailed: false,
        nextPageFailed: false,
      ),
    );

    try {
      final page = await _repository.loadPage(
        filter: _propertyFilter,
        limit: _pageSize,
      );
      if (generation != _generation) return;
      emit(
        state.copyWith(
          listings: _propertyPosts(page.posts),
          nextCursor: page.nextCursor,
          isInitialLoading: false,
          isRefreshing: false,
          source: page.source,
          savedAt: page.savedAt,
          fallbackReason: page.fallbackReason,
          clearSavedProvenance: page.source == FeedDataSource.network,
          clearFailure: true,
          refreshFailed: false,
        ),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      final failure = error is FeedLoadFailure
          ? error
          : const FeedLoadFailure(FeedFailureKind.unavailable);
      emit(
        state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          failure: hasVisibleListings ? null : failure,
          clearFailure: hasVisibleListings,
          refreshFailed: hasVisibleListings,
        ),
      );
    }
  }

  Future<void> _loadNextPage(
    ListingsNextPageRequested event,
    Emitter<ListingsState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore) {
      return;
    }

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true, nextPageFailed: false));
    try {
      final page = await _repository.loadPage(
        filter: _propertyFilter,
        cursor: cursor,
        limit: _pageSize,
      );
      if (generation != _generation) return;
      final incoming = _propertyPosts(page.posts);
      final ids = state.listings.map((listing) => listing.id).toSet();
      final listings = [...state.listings];
      for (final listing in incoming) {
        if (ids.add(listing.id)) listings.add(listing);
      }
      final retainsSavedProvenance = state.isShowingSavedListings;
      emit(
        state.copyWith(
          listings: listings,
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
      if (generation != _generation) return;
      emit(state.copyWith(isLoadingMore: false, nextPageFailed: true));
    }
  }

  List<PropertyFeedPost> _propertyPosts(List<FeedPost> posts) {
    if (posts.any((post) => post is! PropertyFeedPost)) {
      throw const FeedLoadFailure(FeedFailureKind.unavailable);
    }
    return posts.cast<PropertyFeedPost>();
  }
}
