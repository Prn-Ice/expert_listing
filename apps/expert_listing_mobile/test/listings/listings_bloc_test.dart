import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/listings/bloc/listings_bloc.dart';
import 'package:expert_listing/listings/bloc/listings_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ListingsBloc, () {
    test(
      'requests only properties and suppresses duplicate pagination',
      () async {
        final nextPage = Completer<FeedLoadResult>();
        final calls = <({FeedFilter filter, String? cursor})>[];
        final repository = _ListingsRepository((filter, cursor) {
          calls.add((filter: filter, cursor: cursor));
          return cursor == null
              ? Future.value(_page([_property(1)], nextCursor: 'next'))
              : nextPage.future;
        });
        final bloc = ListingsBloc(repository: repository);
        addTearDown(bloc.close);

        bloc.add(const ListingsStarted());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.listings.map((listing) => listing.id), [1]);
        expect(
          calls.single.filter,
          const FeedFilter(postType: PostType.property),
        );

        bloc
          ..add(const ListingsNextPageRequested())
          ..add(const ListingsNextPageRequested());
        await Future<void>.delayed(Duration.zero);
        expect(calls, hasLength(2));
        expect(calls.last.cursor, 'next');

        nextPage.complete(_page([_property(1), _property(2)]));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.listings.map((listing) => listing.id), [1, 2]);
      },
    );

    test('rejects a non-property response from the repository', () async {
      final repository = _ListingsRepository(
        (_, _) => Future.value(_page([_generalPost()])),
      );
      final bloc = ListingsBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const ListingsStarted());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.listings, isEmpty);
      expect(bloc.state.failure?.kind, FeedFailureKind.unavailable);
      expect(bloc.state.isInitialLoading, isFalse);
    });
  });
}

final class _ListingsRepository extends FeedRepository {
  _ListingsRepository(this._load) : super(client: Dio());

  final Future<FeedLoadResult> Function(FeedFilter filter, String? cursor)
  _load;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) => _load(filter, cursor);
}

FeedLoadResult _page(List<FeedPost> posts, {String? nextCursor}) =>
    FeedLoadResult(
      posts: posts,
      nextCursor: nextCursor,
      source: FeedDataSource.network,
    );

FeedPost _property(int id) => FeedPost.fromJson({
  ..._post(id),
  'postType': 'property',
  'property': {
    'id': 5000 + id,
    'status': id.isOdd ? 'for_sale' : 'for_rent',
    'location': 'Property $id, Lagos',
    'images': const <Map<String, dynamic>>[],
  },
});

FeedPost _generalPost() => FeedPost.fromJson({
  ..._post(9),
  'postType': 'general',
  'location': 'Yaba, Lagos',
});

Map<String, dynamic> _post(int id) => {
  'id': id,
  'body': 'Post $id',
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
};
