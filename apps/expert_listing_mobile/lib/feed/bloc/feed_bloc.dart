// Private dependencies retain product-language argument names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/data/bookmark_store.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// Coordinates ordered first-page, refresh, filter, and cursor feed work.
final class FeedBloc extends Bloc<FeedEvent, FeedState> {
  /// Creates the feed state machine.
  FeedBloc({
    required FeedRepository repository,
    BookmarkStore? bookmarkStore,
  }) : _repository = repository,
       _bookmarkStore = bookmarkStore ?? _TransientBookmarkStore(),
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
    on<FeedLikeToggled>(_toggleLike);
    on<FeedBookmarkToggled>(
      _toggleBookmark,
      transformer: _sequential<FeedBookmarkToggled>(),
    );
    on<FeedPostHidden>((event, emit) {
      emit(
        state.copyWith(hiddenPostIds: {...state.hiddenPostIds, event.postId}),
      );
    });
    on<FeedPostRestored>((event, emit) {
      emit(
        state.copyWith(
          hiddenPostIds: {...state.hiddenPostIds}..remove(event.postId),
        ),
      );
    });
    on<FeedCommentAdded>(_commentAdded);
  }

  final FeedRepository _repository;
  final BookmarkStore _bookmarkStore;
  int _requestGeneration = 0;
  final _confirmedLikes = <int, LikeResult>{};
  final _desiredLikes = <int, bool>{};
  final _activeLikeWorkers = <int>{};
  final _commentCountFloor = <int, int>{};
  var _bookmarksLoaded = false;
  Future<({Set<int> postIds, bool noticeShown})>? _bookmarkLoad;
  var _deviceNoticeShown = false;
  Future<void> _bookmarkWrites = Future.value();

  Future<void> _loadFirstPage(
    Emitter<FeedState> emit, {
    FeedFilter? filter,
    bool keepVisible = false,
  }) async {
    await _loadBookmarks(emit);
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
          posts: _applyEngagementOverlays(page.posts),
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

      final posts = _mergeUniquePosts(
        state.posts,
        _applyEngagementOverlays(page.posts),
      );
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

  Future<bool> _loadBookmarks(
    Emitter<FeedState> emit, {
    bool announceFailure = false,
  }) async {
    if (_bookmarksLoaded) return true;
    final load = _bookmarkLoad ??= () async {
      final results = await Future.wait<Object>([
        _bookmarkStore.load(),
        _bookmarkStore.hasShownDeviceOnlyNotice(),
      ]);
      return (
        postIds: results[0] as Set<int>,
        noticeShown: results[1] as bool,
      );
    }();
    try {
      final result = await load;
      _bookmarksLoaded = true;
      _deviceNoticeShown = result.noticeShown;
      emit(state.copyWith(bookmarkedPostIds: result.postIds));
      return true;
    } on Object {
      if (identical(_bookmarkLoad, load)) _bookmarkLoad = null;
      if (announceFailure) {
        _emitNotice(emit, "Couldn't load saved bookmarks. Try again.");
      }
      return false;
    }
  }

  Future<void> _toggleLike(
    FeedLikeToggled event,
    Emitter<FeedState> emit,
  ) async {
    final post = _post(event.postId);
    if (post == null) return;
    _confirmedLikes.putIfAbsent(
      post.id,
      () => LikeResult(
        postId: post.id,
        liked: post.likedByCurrentUser,
        likeCount: post.likeCount,
      ),
    );
    final desired = !post.likedByCurrentUser;
    _desiredLikes[post.id] = desired;
    _replacePost(
      emit,
      post.withEngagement(
        likedByCurrentUser: desired,
        likeCount: (post.likeCount + (desired ? 1 : -1)).clamp(0, 1 << 31),
      ),
    );

    if (!_activeLikeWorkers.add(post.id)) return;
    var mutationSucceeded = false;
    try {
      while (true) {
        final requested = _desiredLikes[post.id]!;
        try {
          final result = await _repository.setPostLiked(
            postId: post.id,
            liked: requested,
          );
          _confirmedLikes[post.id] = result;
          mutationSucceeded = true;
          await _retireFeedLoadsAndInvalidate(emit);
          if (_desiredLikes[post.id] == requested) {
            final current = _post(post.id);
            if (current != null) {
              _replacePost(
                emit,
                current.withEngagement(
                  likedByCurrentUser: result.liked,
                  likeCount: result.likeCount,
                ),
              );
            }
            break;
          }
        } on Object {
          if (_desiredLikes[post.id] != requested) continue;
          final confirmed = _confirmedLikes[post.id]!;
          final current = _post(post.id);
          if (current != null) {
            _replacePost(
              emit,
              current.withEngagement(
                likedByCurrentUser: confirmed.liked,
                likeCount: confirmed.likeCount,
              ),
              notice: "Couldn't update your like. Try again.",
            );
          }
          break;
        }
      }
    } finally {
      _activeLikeWorkers.remove(post.id);
    }
    if (mutationSucceeded && !isClosed) add(const FeedRefreshed());
  }

  Future<void> _toggleBookmark(
    FeedBookmarkToggled event,
    Emitter<FeedState> emit,
  ) async {
    if (!await _loadBookmarks(emit, announceFailure: true)) return;
    final previous = state.bookmarkedPostIds;
    final updated = {...previous};
    final saved = updated.add(event.postId);
    if (!saved) updated.remove(event.postId);
    emit(state.copyWith(bookmarkedPostIds: updated));

    final write = _bookmarkWrites
        .catchError((Object _) {})
        .then((_) => _bookmarkStore.save(updated));
    _bookmarkWrites = write;
    try {
      await write;
      if (saved && !_deviceNoticeShown) {
        _deviceNoticeShown = true;
        _emitNotice(emit, 'Saved on this device.');
        try {
          await _bookmarkStore.markDeviceOnlyNoticeShown();
        } on Object {
          // The bookmark is durable; disclosure metadata is best effort.
        }
      }
    } on Object {
      if (state.bookmarkedPostIds == updated) {
        emit(state.copyWith(bookmarkedPostIds: previous));
        _emitNotice(emit, "Couldn't save bookmark. Try again.");
      }
    }
  }

  Future<void> _commentAdded(
    FeedCommentAdded event,
    Emitter<FeedState> emit,
  ) async {
    final post = _post(event.postId);
    if (post == null) return;
    final count = post.commentCount + 1;
    _commentCountFloor[post.id] = count;
    _replacePost(emit, post.withEngagement(commentCount: count));
    await _retireFeedLoadsAndInvalidate(emit);
    if (!isClosed) add(const FeedRefreshed());
  }

  Future<void> _retireFeedLoadsAndInvalidate(Emitter<FeedState> emit) async {
    _requestGeneration++;
    emit(
      state.copyWith(
        isRefreshing: false,
        isLoadingMore: false,
        nextPageFailed: false,
      ),
    );
    try {
      await _repository.invalidateFeed();
    } on Object {
      // Cache infrastructure cannot turn a successful mutation into failure.
    }
  }

  List<FeedPost> _applyEngagementOverlays(List<FeedPost> posts) {
    return posts
        .map((post) {
          var overlaidPost = post;
          final current = _post(post.id);
          if (_activeLikeWorkers.contains(post.id) && current != null) {
            overlaidPost = overlaidPost.withEngagement(
              likedByCurrentUser: current.likedByCurrentUser,
              likeCount: current.likeCount,
            );
          } else {
            _confirmedLikes[post.id] = LikeResult(
              postId: post.id,
              liked: post.likedByCurrentUser,
              likeCount: post.likeCount,
            );
          }
          final countFloor = _commentCountFloor[post.id];
          if (countFloor != null && overlaidPost.commentCount < countFloor) {
            overlaidPost = overlaidPost.withEngagement(
              commentCount: countFloor,
            );
          }
          return overlaidPost;
        })
        .toList(growable: false);
  }

  FeedPost? _post(int postId) {
    for (final post in state.posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  void _replacePost(
    Emitter<FeedState> emit,
    FeedPost replacement, {
    String? notice,
  }) {
    emit(
      state.copyWith(
        posts: [
          for (final post in state.posts)
            if (post.id == replacement.id) replacement else post,
        ],
        notice: notice,
        noticeSequence: notice == null
            ? state.noticeSequence
            : state.noticeSequence + 1,
      ),
    );
  }

  void _emitNotice(Emitter<FeedState> emit, String message) {
    emit(
      state.copyWith(
        notice: message,
        noticeSequence: state.noticeSequence + 1,
      ),
    );
  }
}

final class _TransientBookmarkStore implements BookmarkStore {
  var _postIds = <int>{};
  var _noticeShown = false;

  @override
  Future<bool> hasShownDeviceOnlyNotice() async => _noticeShown;

  @override
  Future<Set<int>> load() async => {..._postIds};

  @override
  Future<void> markDeviceOnlyNoticeShown() async => _noticeShown = true;

  @override
  Future<void> save(Set<int> postIds) async => _postIds = {...postIds};
}

EventTransformer<Event> _sequential<Event>() {
  return (events, mapper) => events.asyncExpand(mapper);
}
