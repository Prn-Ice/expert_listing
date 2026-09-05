import 'dart:ui' show Tristate;

import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/comments/comments_sheet.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:expert_listing/feed/view/post_actions.dart';
import 'package:expert_listing/feed/view/property_media.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

  testWidgets('comment action opens the shared persistent comments sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_page()));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Comments, 1'));
    await tester.pumpAndSettle();

    expect(find.byType(CommentsSheet), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('comment-input')), findsOneWidget);
    expect(find.text('No comments yet.'), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('comment-input')),
    );
    expect(input.decoration?.filled, isTrue);
    expect(input.decoration?.border, isA<OutlineInputBorder>());
    expect(input.decoration?.enabledBorder, isA<OutlineInputBorder>());
  });

  testWidgets('iOS comments composer stays reachable above the keyboard', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.reset);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(428, 926);
    await tester.binding.setSurfaceSize(const Size(428, 926));
    await tester.pumpWidget(
      _harness(_page(), platform: TargetPlatform.iOS),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Comments, 1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('comment-input')),
      'Is inspection still open?',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('comment-submit')).hitTestable(),
      findsOneWidget,
    );
    final inputRect = tester.getRect(
      find.byKey(const ValueKey<String>('comment-input')),
    );
    final submitRect = tester.getRect(
      find.byKey(const ValueKey<String>('comment-submit')),
    );
    expect(inputRect.height, greaterThanOrEqualTo(AppIconSize.tapTarget));
    expect(submitRect.height, inputRect.height);
    final postLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('comment-submit')),
        matching: find.text('Post'),
      ),
    );
    expect(postLabel.style?.color, AppColors.light.onBrand);
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('comment-submit')))
          .bottom,
      lessThanOrEqualTo(590),
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsSheet), findsNothing);
  });

  testWidgets('session hide removes a post and Undo restores it', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_page()));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('post-overflow-42')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this post'));
    await tester.pumpAndSettle();

    expect(find.text('Saved post'), findsNothing);
    expect(find.text('Post hidden.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Saved post'), findsOneWidget);
  });

  testWidgets('an all-hidden page keeps later pages reachable', (tester) async {
    final repository = _PageRepository(_page(nextCursor: 'next'));
    await tester.pumpWidget(_harnessWith(repository));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('post-overflow-42')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this post'));
    await tester.pumpAndSettle();

    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.pump();
    expect(repository.loadCalls, 2);
  });

  testWidgets('a replacement actor starts its new feed bloc', (tester) async {
    final calls = <String?>[];
    final container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWith((ref) {
          final actor = ref.watch(previewActorProvider);
          return _ActorPageRepository(actor: actor, calls: calls);
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: FeedView(scrollController: controller)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Feed for prince'), findsOneWidget);

    container.read(previewActorProvider.notifier).select('ayo');
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Feed for ayo'), findsOneWidget);
    expect(calls, [null, 'ayo']);
  });

  testWidgets('iOS pins the filter pill leading and uses native controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_harness(_page()));
      await tester.pump();

      final pill = find.byKey(const ValueKey<String>('feed-filters-pill'));
      expect(tester.getTopLeft(pill).dx, AppSpacing.xxlarge);

      await tester.tap(find.byKey(const ValueKey<String>('feed-filters')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('General'));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('General'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Material uses a compact leading outlined filter button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_page(), platform: TargetPlatform.android),
    );
    await tester.pump();

    final button = find.byKey(const ValueKey<String>('feed-filters'));
    final pill = find.byKey(const ValueKey<String>('feed-filters-pill'));
    final icon = find.descendant(of: button, matching: find.byType(AppIcon));
    final outlinedButton = tester.widget<OutlinedButton>(button);
    final style = outlinedButton.style!;
    expect(tester.getTopLeft(button).dx, AppSpacing.xxlarge);
    expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(icon), const Size.square(AppIconSize.small));
    expect(
      tester.getRect(button).width,
      tester.getRect(pill).width + (AppSpacing.medium * 2),
    );
    expect(
      style.padding!.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
    );
    expect(style.side!.resolve(<WidgetState>{})!.width, 1);
    expect(style.shape!.resolve(<WidgetState>{}), const StadiumBorder());

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('each platform uses its native refresh control', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await tester.pumpWidget(_harness(_page(), platform: platform));
      await tester.pump();

      final feed = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(
        feed.slivers.whereType<CupertinoSliverRefreshControl>().length,
        platform == TargetPlatform.iOS ? 1 : 0,
      );
      expect(
        find.byType(RefreshIndicator),
        platform == TargetPlatform.android ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('iOS exposes the feed as the page primary scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_page(), platform: TargetPlatform.iOS));
    await tester.pump();

    final pageContext = tester.element(find.byType(CupertinoPageScaffold));
    final primaryController = PrimaryScrollController.maybeOf(pageContext);
    final feed = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(primaryController, same(feed.controller));
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

  testWidgets('a short feed can pull to refresh on each platform', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final repository = _PageRepository(_page());
      await tester.pumpWidget(
        _harnessWith(repository, platform: platform),
      );
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
    }
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

Widget _harness(FeedLoadResult page, {TargetPlatform? platform}) {
  return _harnessWith(_PageRepository(page), platform: platform);
}

Widget _harnessWith(FeedRepository repository, {TargetPlatform? platform}) {
  return ProviderScope(
    key: ValueKey<TargetPlatform?>(platform),
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          'http://127.0.0.1:54321/functions/v1/api',
          isRelease: false,
        ),
      ),
      feedRepositoryProvider.overrideWithValue(repository),
      recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
    ],
    child: ExpertListingApp(platformOverride: platform),
  );
}

final class _RecentSearchStore implements RecentSearchStore {
  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> load() async => const [];

  @override
  Future<List<String>> remove(String query) async => const [];

  @override
  Future<List<String>> save(String query) async => [query];
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
    int limit = 10,
  }) {
    loadCalls++;
    return Future.value(page);
  }

  @override
  Future<List<FeedComment>> loadComments(int postId) async => const [];
}

final class _ActorPageRepository extends FeedRepository {
  _ActorPageRepository({required this.actor, required this.calls})
    : super(client: Dio());

  final String? actor;
  final List<String?> calls;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) async {
    calls.add(actor);
    return FeedLoadResult(
      posts: [
        FeedPost.fromJson({
          ..._feedPostJson(42, body: 'Feed for ${actor ?? 'prince'}'),
        }),
      ],
      nextCursor: null,
      source: FeedDataSource.network,
    );
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
    int limit = 10,
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
    int limit = 10,
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
    int limit = 10,
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
    int limit = 10,
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
