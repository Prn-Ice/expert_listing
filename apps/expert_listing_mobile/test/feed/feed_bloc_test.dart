import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/bloc/feed_bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/data/bookmark_store.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stale first-page response cannot replace a newer filter', () async {
    final initial = Completer<FeedLoadResult>();
    final filtered = Completer<FeedLoadResult>();
    final repository = _TestFeedRepository((filter, _) {
      return filter.postType == PostType.request
          ? filtered.future
          : initial.future;
    });
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FeedFiltersApplied(FeedFilter(postType: PostType.request)));
    await Future<void>.delayed(Duration.zero);

    filtered.complete(_page(2));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.posts.single.id, 2);

    initial.complete(_page(1));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.posts.single.id, 2);
  });

  test(
    'repeated first-page events for the active filter share one request',
    () async {
      final firstPage = Completer<FeedLoadResult>();
      var calls = 0;
      final repository = _TestFeedRepository((_, _) {
        calls++;
        return firstPage.future;
      });
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc
        ..add(const FeedStarted())
        ..add(const FeedRefreshed())
        ..add(const FeedRetryRequested());
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      firstPage.complete(_page(1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.posts.single.id, 1);
    },
  );

  test(
    'duplicate next-page events issue one request and keep stable IDs',
    () async {
      final nextPage = Completer<FeedLoadResult>();
      var calls = 0;
      final repository = _TestFeedRepository((_, cursor) {
        calls++;
        return cursor == null
            ? Future.value(_page(1, nextCursor: 'next'))
            : nextPage.future;
      });
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const FeedNextPageRequested())
        ..add(const FeedNextPageRequested());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);

      nextPage.complete(_page(1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.posts, hasLength(1));
      expect(bloc.state.posts.single.id, 1);
    },
  );

  test('created post inserts immediately and retires an older load', () async {
    final firstPage = Completer<FeedLoadResult>();
    final repository = _TestFeedRepository((_, _) => firstPage.future);
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(FeedPostCreated(_page(2).posts.single));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.posts.map((post) => post.id), [2]);
    expect(bloc.state.isInitialLoading, isFalse);

    firstPage.complete(_page(1));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.posts.map((post) => post.id), [2]);
  });

  test('next-page retry preserves the already loaded posts', () async {
    var nextPageAttempts = 0;
    final repository = _TestFeedRepository((_, cursor) {
      if (cursor == null) return Future.value(_page(1, nextCursor: 'next'));
      nextPageAttempts++;
      if (nextPageAttempts == 1) {
        return Future.error(const FeedLoadFailure(FeedFailureKind.connection));
      }
      return Future.value(_page(2));
    });
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FeedNextPageRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.posts.map((post) => post.id), [1]);
    expect(bloc.state.nextPageFailed, isTrue);

    bloc.add(const FeedNextPageRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.posts.map((post) => post.id), [1, 2]);
    expect(bloc.state.nextPageFailed, isFalse);
  });

  test('an unavailable first page ends in a terminal error state', () async {
    final repository = _TestFeedRepository(
      (_, _) => Future.error(
        const FeedLoadFailure(FeedFailureKind.unavailable),
      ),
    );
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.posts, isEmpty);
    expect(bloc.state.failure?.kind, FeedFailureKind.unavailable);
    expect(bloc.state.isInitialLoading, isFalse);
  });

  test(
    'only a successful first-page network result clears saved provenance',
    () async {
      var firstPageAttempts = 0;
      final repository = _TestFeedRepository((_, cursor) {
        if (cursor != null) return Future.value(_page(2));
        firstPageAttempts++;
        return Future.value(
          firstPageAttempts == 1
              ? _page(
                  1,
                  nextCursor: 'next',
                  source: FeedDataSource.saved,
                  fallbackReason: FeedFallbackReason.connection,
                )
              : _page(1),
        );
      });
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isShowingSavedPosts, isTrue);

      bloc.add(const FeedNextPageRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isShowingSavedPosts, isTrue);

      bloc.add(const FeedRetryRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.source, FeedDataSource.network);
      expect(bloc.state.fallbackReason, isNull);
    },
  );

  test('rapid like taps converge without stale response overwrite', () async {
    final repository = _EngagementRepository();
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    bloc.add(const FeedLikeToggled(1));
    await _flush();
    expect(bloc.state.posts.single.likedByCurrentUser, isTrue);
    expect(bloc.state.posts.single.likeCount, 1);
    expect(repository.likeRequests, hasLength(1));

    bloc.add(const FeedLikeToggled(1));
    await _flush();
    expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
    expect(bloc.state.posts.single.likeCount, 0);
    expect(repository.likeRequests, hasLength(1));

    repository.likeRequests.first.result.complete(
      const LikeResult(postId: 1, liked: true, likeCount: 1),
    );
    await _flush();
    expect(repository.likeRequests, hasLength(2));
    expect(repository.likeRequests.last.liked, isFalse);

    repository.likeRequests.last.result.complete(
      const LikeResult(postId: 1, liked: false, likeCount: 0),
    );
    await _flush();
    await _flush();

    expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
    expect(bloc.state.posts.single.likeCount, 0);
    expect(repository.invalidateCalls, 2);
  });

  test(
    'a tap during cache invalidation is sent before the worker exits',
    () async {
      final repository = _EngagementRepository(
        invalidateBarrier: Completer<void>(),
      );
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await _flush();
      bloc.add(const FeedLikeToggled(1));
      await _flush();
      repository.likeRequests.single.result.complete(
        const LikeResult(postId: 1, liked: true, likeCount: 1),
      );
      await _flush();

      bloc.add(const FeedLikeToggled(1));
      await _flush();
      expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
      expect(repository.likeRequests, hasLength(1));

      repository.invalidateBarrier!.complete();
      await _flush();
      expect(repository.likeRequests, hasLength(2));
      expect(repository.likeRequests.last.liked, isFalse);

      repository.likeRequests.last.result.complete(
        const LikeResult(postId: 1, liked: false, likeCount: 0),
      );
      await _flush();
      expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
    },
  );

  test('a pre-mutation refresh cannot overwrite a successful like', () async {
    final repository = _RefreshRaceRepository();
    final bloc = FeedBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    bloc.add(const FeedRefreshed());
    await _flush();
    expect(repository.refreshes, hasLength(1));

    bloc.add(const FeedLikeToggled(1));
    await _flush();
    repository.likeResult.complete(
      const LikeResult(postId: 1, liked: true, likeCount: 1),
    );
    await _flush();
    await _flush();
    expect(repository.refreshes, hasLength(2));

    repository.refreshes.first.complete(_page(1));
    await _flush();
    expect(bloc.state.posts.single.likedByCurrentUser, isTrue);

    repository.refreshes.last.complete(_likedPage());
    await _flush();
    expect(bloc.state.posts.single.likedByCurrentUser, isTrue);
    expect(bloc.state.posts.single.likeCount, 1);
  });

  test(
    'a failed latest like intent restores confirmed state and preview',
    () async {
      final repository = _EngagementRepository(withPreviews: true);
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await _flush();
      final confirmedPreview = bloc.state.posts.single.likePreview;
      expect(confirmedPreview, isNotEmpty);
      bloc.add(const FeedLikeToggled(1));
      await _flush();
      expect(bloc.state.posts.single.likedByCurrentUser, isTrue);
      expect(bloc.state.posts.single.likePreview, confirmedPreview);

      repository.likeRequests.single.result.completeError(
        const EngagementFailure(),
      );
      await _flush();

      expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
      expect(bloc.state.posts.single.likeCount, 2);
      expect(bloc.state.posts.single.likePreview, confirmedPreview);
      expect(bloc.state.notice, "Couldn't update your like. Try again.");
    },
  );

  test('a failed unlike restores the confirmed liker preview', () async {
    final repository = _EngagementRepository(
      withPreviews: true,
      initiallyLiked: true,
    );
    final bloc = FeedBloc(repository: repository, currentUserHandle: 'ayo');
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    final confirmedPreview = bloc.state.posts.single.likePreview;

    bloc.add(const FeedLikeToggled(1));
    await _flush();
    expect(bloc.state.posts.single.likedByCurrentUser, isFalse);
    expect(bloc.state.posts.single.likeCount, 1);
    expect(
      bloc.state.posts.single.likePreview.map((author) => author.handle),
      ['ifeoma'],
    );

    repository.likeRequests.single.result.completeError(
      const EngagementFailure(),
    );
    await _flush();

    expect(bloc.state.posts.single.likedByCurrentUser, isTrue);
    expect(bloc.state.posts.single.likeCount, 2);
    expect(bloc.state.posts.single.likePreview, confirmedPreview);
  });

  test('unlike removes only the current user from the liker preview', () async {
    final repository = _EngagementRepository(
      withPreviews: true,
      initiallyLiked: true,
    );
    final bloc = FeedBloc(
      repository: repository,
      currentUserHandle: 'ifeoma',
    );
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    bloc.add(const FeedLikeToggled(1));
    await _flush();

    expect(
      bloc.state.posts.single.likePreview.map((author) => author.handle),
      ['ayo'],
    );
  });

  test(
    'a comment mutation suppresses a stale latest-comment preview',
    () async {
      final repository = _EngagementRepository(withPreviews: true);
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await _flush();
      expect(bloc.state.posts.single.latestComment, isNotNull);

      bloc.add(const FeedCommentAdded(1));
      await _flush();
      await _flush();

      expect(bloc.state.posts.single.commentCount, 3);
      expect(bloc.state.posts.single.latestComment, isNull);
    },
  );

  test('bookmarks persist locally and disclose device scope once', () async {
    final store = _BookmarkStore();
    final bloc = FeedBloc(
      repository: _TestFeedRepository((_, _) async => _page(1)),
      bookmarkStore: store,
    );
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    bloc.add(const FeedBookmarkToggled(1));
    await _flush();

    expect(bloc.state.bookmarkedPostIds, {1});
    expect(store.savedPostIds, {1});
    expect(bloc.state.notice, 'Saved on this device.');
    final firstNoticeSequence = bloc.state.noticeSequence;

    bloc.add(const FeedBookmarkToggled(1));
    await _flush();
    bloc.add(const FeedBookmarkToggled(1));
    await _flush();

    expect(store.savedPostIds, {1});
    expect(bloc.state.noticeSequence, firstNoticeSequence);
  });

  test('a bookmark read failure never overwrites persisted IDs', () async {
    final store = _BookmarkStore(
      savedPostIds: {99},
      failLoad: true,
    );
    final bloc = FeedBloc(
      repository: _TestFeedRepository((_, _) async => _page(1)),
      bookmarkStore: store,
    );
    addTearDown(bloc.close);

    bloc.add(const FeedStarted());
    await _flush();
    bloc.add(const FeedBookmarkToggled(1));
    await _flush();

    expect(store.savedPostIds, {99});
    expect(store.saveCalls, 0);
    expect(bloc.state.notice, "Couldn't load saved bookmarks. Try again.");
  });

  test(
    'a disclosure write failure does not roll back a saved bookmark',
    () async {
      final store = _BookmarkStore(failNoticeWrite: true);
      final bloc = FeedBloc(
        repository: _TestFeedRepository((_, _) async => _page(1)),
        bookmarkStore: store,
      );
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await _flush();
      bloc.add(const FeedBookmarkToggled(1));
      await _flush();

      expect(store.savedPostIds, {1});
      expect(bloc.state.bookmarkedPostIds, {1});
      expect(bloc.state.notice, 'Saved on this device.');
    },
  );

  test('rapid bookmark taps share one load and retain toggle order', () async {
    final loadBarrier = Completer<void>();
    final store = _BookmarkStore(loadBarrier: loadBarrier);
    final bloc = FeedBloc(
      repository: _TestFeedRepository((_, _) async => _page(1)),
      bookmarkStore: store,
    );
    addTearDown(bloc.close);

    bloc
      ..add(const FeedStarted())
      ..add(const FeedBookmarkToggled(1))
      ..add(const FeedBookmarkToggled(1));
    await _flush();
    expect(store.loadCalls, 1);

    loadBarrier.complete();
    await _flush();
    await _flush();

    expect(store.loadCalls, 1);
    expect(store.savedPostIds, isEmpty);
    expect(bloc.state.bookmarkedPostIds, isEmpty);
    expect(store.saveCalls, 2);
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _TestFeedRepository extends FeedRepository {
  _TestFeedRepository(this._load)
    : super(
        client: Dio(),
      );

  final Future<FeedLoadResult> Function(FeedFilter filter, String? cursor)
  _load;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) => _load(filter, cursor);
}

final class _EngagementRepository extends FeedRepository {
  _EngagementRepository({
    this.invalidateBarrier,
    this.withPreviews = false,
    this.initiallyLiked = false,
  }) : super(client: Dio());

  final likeRequests = <({bool liked, Completer<LikeResult> result})>[];
  final Completer<void>? invalidateBarrier;
  final bool withPreviews;
  final bool initiallyLiked;
  int invalidateCalls = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) async => _page(
    1,
    withPreviews: withPreviews,
    likedByCurrentUser: initiallyLiked,
  );

  @override
  Future<LikeResult> setPostLiked({
    required int postId,
    required bool liked,
  }) {
    final result = Completer<LikeResult>();
    likeRequests.add((liked: liked, result: result));
    return result.future;
  }

  @override
  Future<void> invalidateFeed() async {
    invalidateCalls++;
    await invalidateBarrier?.future;
  }
}

final class _RefreshRaceRepository extends FeedRepository {
  _RefreshRaceRepository() : super(client: Dio());

  int loadCalls = 0;
  final refreshes = <Completer<FeedLoadResult>>[];
  final likeResult = Completer<LikeResult>();

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) {
    loadCalls++;
    if (loadCalls == 1) return Future.value(_page(1));
    final result = Completer<FeedLoadResult>();
    refreshes.add(result);
    return result.future;
  }

  @override
  Future<LikeResult> setPostLiked({
    required int postId,
    required bool liked,
  }) => likeResult.future;

  @override
  Future<void> invalidateFeed() async {}
}

final class _BookmarkStore implements BookmarkStore {
  _BookmarkStore({
    this.savedPostIds = const {},
    this.failLoad = false,
    this.failNoticeWrite = false,
    this.loadBarrier,
  });

  Set<int> savedPostIds;
  final bool failLoad;
  final bool failNoticeWrite;
  final Completer<void>? loadBarrier;
  bool noticeShown = false;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<bool> hasShownDeviceOnlyNotice() async => noticeShown;

  @override
  Future<Set<int>> load() async {
    loadCalls++;
    await loadBarrier?.future;
    if (failLoad) throw StateError('read failed');
    return {...savedPostIds};
  }

  @override
  Future<void> markDeviceOnlyNoticeShown() async {
    if (failNoticeWrite) throw StateError('notice write failed');
    noticeShown = true;
  }

  @override
  Future<void> save(Set<int> postIds) async {
    saveCalls++;
    savedPostIds = {...postIds};
  }
}

FeedLoadResult _likedPage() {
  final original = _page(1);
  return FeedLoadResult(
    posts: [
      original.posts.single.withEngagement(
        likedByCurrentUser: true,
        likeCount: 1,
      ),
    ],
    nextCursor: null,
    source: FeedDataSource.network,
  );
}

FeedLoadResult _page(
  int id, {
  String? nextCursor,
  FeedDataSource source = FeedDataSource.network,
  FeedFallbackReason? fallbackReason,
  bool withPreviews = false,
  bool likedByCurrentUser = false,
}) => FeedLoadResult(
  posts: [
    FeedPost.fromJson({
      'id': id,
      'body': 'Post $id',
      'postType': 'general',
      'createdAt': '2026-09-03T12:00:00.000Z',
      'viewCount': 0,
      'bookmarkCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'likedByCurrentUser': likedByCurrentUser,
      'author': const {
        'id': '11111111-1111-4111-8111-111111111111',
        'handle': 'prince',
        'displayName': 'Prince',
        'role': 'Buyer',
        'avatarUrl': null,
      },
      if (withPreviews) ...{
        'likeCount': 2,
        'commentCount': 2,
        'likePreview': const [
          {
            'id': '00000000-0000-0000-0000-000000000003',
            'handle': 'ifeoma',
            'displayName': 'Ifeoma Nwosu',
            'role': 'Architect',
            'avatarUrl': null,
          },
          {
            'id': '00000000-0000-0000-0000-000000000002',
            'handle': 'ayo',
            'displayName': 'Ayo Balogun',
            'role': 'Property Consultant',
            'avatarUrl': null,
          },
        ],
        'latestComment': const {
          'id': 3002,
          'body': 'Existing comment',
          'author': {
            'id': '00000000-0000-0000-0000-000000000003',
            'handle': 'ifeoma',
            'displayName': 'Ifeoma Nwosu',
            'role': 'Architect',
            'avatarUrl': null,
          },
        },
      },
      'location': 'Yaba, Lagos',
    }),
  ],
  nextCursor: nextCursor,
  source: source,
  savedAt: source == FeedDataSource.saved ? DateTime.utc(2026, 9, 3) : null,
  fallbackReason: fallbackReason,
);
