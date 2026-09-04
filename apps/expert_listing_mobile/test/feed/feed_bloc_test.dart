import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/bloc/feed_bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/feed_repository.dart';
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
  }) => _load(filter, cursor);
}

FeedLoadResult _page(
  int id, {
  String? nextCursor,
  FeedDataSource source = FeedDataSource.network,
  FeedFallbackReason? fallbackReason,
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
      'likedByCurrentUser': false,
      'author': const {
        'id': '11111111-1111-4111-8111-111111111111',
        'handle': 'prince',
        'displayName': 'Prince',
        'role': 'Buyer',
        'avatarUrl': null,
      },
      'location': 'Yaba, Lagos',
    }),
  ],
  nextCursor: nextCursor,
  source: source,
  savedAt: source == FeedDataSource.saved ? DateTime.utc(2026, 9, 3) : null,
  fallbackReason: fallbackReason,
);
