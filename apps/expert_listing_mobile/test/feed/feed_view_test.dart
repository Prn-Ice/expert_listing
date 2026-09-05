import 'dart:ui' show Tristate;

import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/post_actions.dart';
import 'package:expert_listing/feed/view/property_media.dart';
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

    final storyRing = tester.getRect(
      find.byKey(const ValueKey<String>('story-ring-Abba')),
    );
    final storyImage = tester.getRect(
      find.byKey(const ValueKey<String>('story-image-Abba')),
    );
    expect(storyRing.size, const Size.square(66));
    expect(storyImage.size, const Size.square(60));
    expect(storyImage.left - storyRing.left, 3);

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

  testWidgets('the saved-feed status bar pins while the feed scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _responsiveFeedPage(
          source: FeedDataSource.saved,
          fallbackReason: FeedFallbackReason.connection,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Offline · Showing saved posts'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // The strip sticks to the top of the viewport while posts scroll under
    // it, so the provenance stays visible.
    final barTop = tester.getTopLeft(find.byType(OfflineStatusBar)).dy;
    expect(barTop, moreOrLessEquals(0, epsilon: 1));
    expect(tester.takeException(), isNull);
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

  testWidgets('keeps the full feed inside 428 and 360px viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    // The intended narrow logical widths, in light and dark system themes.
    for (final (width, brightness) in const <(double, Brightness)>[
      (428, Brightness.light),
      (428, Brightness.dark),
      (360, Brightness.light),
      (360, Brightness.dark),
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_harness(_responsiveFeedPage()));
      await tester.pump();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Abba'), findsOneWidget);
      expect(find.text('Lekki two bedroom flat'), findsOneWidget);
      expect(find.byType(PropertyMedia), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('post-actions-1')),
        findsOneWidget,
      );

      // Scroll to build post metadata, property media, and action rows.
      for (var drag = 0; drag < 3; drag++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.byType(PropertyMedia), findsWidgets);
      expect(find.byType(PostActions), findsWidgets);
      expect(find.text('Buyer'), findsWidgets);
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

  testWidgets(
    'a continued fling past a failed page keeps exactly one failed request',
    (tester) async {
      final repository = _NextPageFailureRepository();
      await tester.pumpWidget(_harnessWith(repository));
      await tester.pump();
      await tester.pump();

      // Keep flinging while the bottom of the list stays visible; each fling
      // re-enters the pagination threshold.
      for (var fling = 0; fling < 4; fling++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -600),
          1200,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pump();
      await tester.pump();

      expect(repository.nextPageCalls, 1);
      expect(find.text('Try again'), findsOneWidget);

      // The visible control remains the only retry after failure.
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.nextPageCalls, 2);
    },
  );

  testWidgets(
    'the filter sheet keeps Apply reachable with a keyboard at 360x640',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.view.reset());
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      final repository = _TrackingFilterRepository();
      await tester.pumpWidget(_harnessWith(repository));
      await tester.pump();

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Lekki Phase 1');
      await tester.pump();

      // A compressed keyboard leaves less vertical space than the sheet needs;
      // the sheet content must scroll to keep Apply reachable.
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Apply'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.filters.last.location, 'Lekki Phase 1');
    },
  );

  testWidgets('a long location is capped at the 120-character API limit', (
    tester,
  ) async {
    final repository = _TrackingFilterRepository();
    await tester.pumpWidget(_harnessWith(repository));
    await tester.pump();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    final longLocation = 'A' * 130;
    await tester.enterText(find.byType(TextField), longLocation);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 120);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repository.filters.last.location, 'A' * 120);
    expect(tester.takeException(), isNull);
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

/// One page of mixed post types tall enough to scroll at narrow widths.
FeedLoadResult _responsiveFeedPage({
  FeedDataSource source = FeedDataSource.network,
  FeedFallbackReason? fallbackReason,
}) => FeedLoadResult(
  posts: [
    FeedPost.fromJson({
      ..._feedPostJson(1, body: 'Lekki two bedroom flat'),
      'postType': 'property',
      'property': const <String, dynamic>{
        'id': 1,
        'status': 'for_sale',
        'location': 'Lekki Phase 1, Lagos',
        'images': <Map<String, dynamic>>[
          {
            'id': 1,
            'url': 'https://example.test/property-1.jpg',
            'position': 0,
          },
          {
            'id': 2,
            'url': 'https://example.test/property-2.jpg',
            'position': 1,
          },
        ],
      },
    }),
    FeedPost.fromJson({
      ..._feedPostJson(2, body: 'Looking for a self-contained'),
      'postType': 'request',
      'request': const <String, String>{
        'type': 'looking_to_buy',
        'location': 'Yaba, Lagos',
      },
    }),
    FeedPost.fromJson(_feedPostJson(3, body: 'Lagos rent is changing')),
    FeedPost.fromJson({
      ..._feedPostJson(4, body: 'Furnished service apartment'),
      'postType': 'property',
      'property': const <String, dynamic>{
        'id': 4,
        'status': 'for_rent',
        'location': 'Ikoyi, Lagos',
        'images': <Map<String, dynamic>>[
          {
            'id': 3,
            'url': 'https://example.test/property-3.jpg',
            'position': 0,
          },
        ],
      },
    }),
  ],
  nextCursor: null,
  source: source,
  savedAt: source == FeedDataSource.saved ? DateTime.utc(2026, 9, 3) : null,
  fallbackReason: fallbackReason,
);

Map<String, dynamic> _feedPostJson(int id, {required String body}) => {
  'id': id,
  'body': body,
  'postType': 'general',
  'createdAt': '2026-09-03T12:00:00.000Z',
  'viewCount': 243,
  'bookmarkCount': 2,
  'likeCount': 3,
  'commentCount': 2,
  'likedByCurrentUser': false,
  'author': const {
    'id': '11111111-1111-4111-8111-111111111111',
    'handle': 'prince',
    'displayName': 'Prince',
    'role': 'Buyer',
    'avatarUrl': null,
  },
  'location': 'Yaba, Lagos',
};

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
