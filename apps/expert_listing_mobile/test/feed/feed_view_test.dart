import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Hono-shaped feed content and opens filters', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_page()));
    await tester.pump();

    expect(find.text('Saved post'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Post type'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('labels a saved connection fallback and exposes Retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _page(
          source: FeedDataSource.saved,
          fallbackReason: FeedFallbackReason.connection,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Offline · Showing saved posts'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'a replacement filter failure does not label an empty result as saved',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        _harnessWith(_SavedThenFilteredFailureRepository()),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Offline · Showing saved posts'), findsOneWidget);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('General'),
        ),
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Offline · Showing saved posts'), findsNothing);
      expect(
        find.text("You're offline. Reconnect to load the feed."),
        findsOneWidget,
      );
    },
  );

  testWidgets('applying and clearing filters reaches the Bloc repository', (
    tester,
  ) async {
    final repository = _TrackingFilterRepository();
    await tester.pumpWidget(_harnessWith(repository));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('General'),
      ),
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repository.filters.last.postType?.name, 'general');

    await tester.tap(find.byKey(const ValueKey<String>('feed-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.pump();
    expect(repository.filters.last.isEmpty, isTrue);
  });

  testWidgets('a short feed can pull to refresh', (tester) async {
    final repository = _PageRepository(_page());
    await tester.pumpWidget(_harnessWith(repository));
    await tester.pump();
    expect(repository.loadCalls, 1);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.loadCalls, 2);
  });

  testWidgets('announces a service saved-feed fallback once', (tester) async {
    await tester.pumpWidget(
      _harnessWith(
        _SequencePageRepository([
          _page(
            source: FeedDataSource.saved,
            fallbackReason: FeedFallbackReason.service,
          ),
        ]),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Service unavailable. Showing saved posts.'),
      findsOneWidget,
    );
  });

  testWidgets('announces reconnection after a saved connection fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harnessWith(
        _SequencePageRepository([
          _page(
            source: FeedDataSource.saved,
            fallbackReason: FeedFallbackReason.connection,
          ),
          _page(),
        ]),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Back online. Feed updated.'), findsOneWidget);
  });

  testWidgets('exposes action labels and the selected Feed destination', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_harness(_page()));
      await tester.pump();

      expect(find.byTooltip('Like'), findsOneWidget);
      expect(find.bySemanticsLabel('Like, 3'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Feed'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps feed controls inside 402 and 360px viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [402.0, 360.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_harness(_page()));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('feed-filters')),
        findsOneWidget,
      );
      expect(find.text('Abba'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('shows and retries a visible next-page failure', (tester) async {
    final repository = _NextPageFailureRepository();
    await tester.pumpWidget(_harnessWith(repository));
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -2000),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.nextPageCalls, 1);

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Try again'), findsOneWidget);

    final callsBeforeRetry = repository.nextPageCalls;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.nextPageCalls, callsBeforeRetry + 1);
  });
}

Widget _harness(FeedLoadResult page) {
  return _harnessWith(_PageRepository(page));
}

Widget _harnessWith(FeedRepository repository) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          'http://127.0.0.1:54321/functions/v1/api',
          isRelease: false,
        ),
      ),
      feedRepositoryProvider.overrideWithValue(repository),
    ],
    child: const ExpertListingApp(),
  );
}

final class _PageRepository extends FeedRepository {
  _PageRepository(this.page)
    : super(
        client: Dio(),
      );

  final FeedLoadResult page;
  int loadCalls = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    loadCalls++;
    return Future.value(page);
  }
}

final class _SequencePageRepository extends FeedRepository {
  _SequencePageRepository(this._pages)
    : super(
        client: Dio(),
      );

  final List<FeedLoadResult> _pages;
  var _nextPage = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    final index = _nextPage < _pages.length ? _nextPage : _pages.length - 1;
    final page = _pages[index];
    _nextPage++;
    return Future.value(page);
  }
}

final class _SavedThenFilteredFailureRepository extends FeedRepository {
  _SavedThenFilteredFailureRepository()
    : super(
        client: Dio(),
      );

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    if (!filter.isEmpty) {
      return Future.error(const FeedLoadFailure(FeedFailureKind.connection));
    }
    return Future.value(
      _page(
        source: FeedDataSource.saved,
        fallbackReason: FeedFallbackReason.connection,
      ),
    );
  }
}

final class _TrackingFilterRepository extends FeedRepository {
  _TrackingFilterRepository()
    : super(
        client: Dio(),
      );

  final filters = <FeedFilter>[];

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    filters.add(filter);
    return Future.value(_page());
  }
}

final class _NextPageFailureRepository extends FeedRepository {
  _NextPageFailureRepository()
    : super(
        client: Dio(),
      );

  int nextPageCalls = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    if (cursor == null) {
      return Future.value(_page(nextCursor: 'page-two', postCount: 6));
    }
    nextPageCalls++;
    return Future.error(const FeedLoadFailure(FeedFailureKind.service));
  }
}

FeedLoadResult _page({
  FeedDataSource source = FeedDataSource.network,
  FeedFallbackReason? fallbackReason,
  String? nextCursor,
  int postCount = 1,
}) => FeedLoadResult(
  posts: List.generate(
    postCount,
    (index) => FeedPost.fromJson({
      'id': 42 + index,
      'body': 'Saved post',
      'postType': 'general',
      'createdAt': '2026-09-03T12:00:00.000Z',
      'viewCount': 100,
      'bookmarkCount': 2,
      'likeCount': 3,
      'commentCount': 1,
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
  ),
  nextCursor: nextCursor,
  source: source,
  savedAt: source == FeedDataSource.saved ? DateTime.utc(2026, 9, 3) : null,
  fallbackReason: fallbackReason,
);
