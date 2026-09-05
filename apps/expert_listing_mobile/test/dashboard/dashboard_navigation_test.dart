import 'dart:ui' show Tristate;

import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/dashboard/destination_switcher.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/profile/models/profile.dart';
import 'package:expert_listing/profile/profile_providers.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:expert_listing/search/search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an immediate destination transition can be disposed safely', (
    tester,
  ) async {
    Widget harness(int selectedIndex) => MaterialApp(
      theme: AppTheme.light(platform: TargetPlatform.iOS),
      home: DestinationSwitcher(
        selectedIndex: selectedIndex,
        children: const [Text('Feed'), Text('Search')],
      ),
    );

    await tester.pumpWidget(harness(0));
    await tester.pumpWidget(harness(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('destination motion follows the active platform', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await tester.pumpWidget(_platformHarness(platform));
      await tester.pump();

      final transition = tester.widget<AnimatedOpacity>(
        find.byKey(
          const ValueKey<String>('dashboard-destination-transition-1'),
          skipOffstage: false,
        ),
      );
      expect(
        transition.duration,
        platform == TargetPlatform.iOS ? Duration.zero : AppMotion.medium,
      );
    }
  });

  testWidgets(
    'implemented destinations select and unavailable ones name their boundary',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = _CountingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                'http://127.0.0.1:54321/functions/v1/api',
                isRelease: false,
              ),
            ),
            feedRepositoryProvider.overrideWithValue(repository),
            searchRepositoryProvider.overrideWithValue(_SearchRepository()),
            recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
            profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
          ],
          child: const ExpertListingApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      final initialLoads = repository.loadCalls;

      // Green marks selection only: the feed destination is the selected one.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Feed'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Search').last)
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      expect(
        tester
            .widget<TickerMode>(
              find
                  .ancestor(
                    of: find.byType(FeedView),
                    matching: find.byType(TickerMode),
                  )
                  .first,
            )
            .enabled,
        isTrue,
      );

      // Feed re-enters its own surface: at the top it refreshes.
      await tester.tap(find.bySemanticsLabel('Feed'));
      await tester.pump();
      await tester.pump();
      expect(repository.loadCalls, greaterThan(initialLoads));

      // Search is a real destination with genuine selected state.
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Search').last)
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Feed'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      expect(
        tester
            .widget<TickerMode>(
              find
                  .ancestor(
                    of: find.byType(FeedView, skipOffstage: false),
                    matching: find.byType(TickerMode, skipOffstage: false),
                  )
                  .first,
            )
            .enabled,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey<String>('property-search-field')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('property-search-field')),
        'Lekki',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('property-suggestion-5001')),
      );
      await tester.pump();
      expect(
        find.text("Property details aren't part of this preview."),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // List is independently selected and renders only property posts.
      await tester.tap(find.bySemanticsLabel('List'));
      await tester.pumpAndSettle();
      expect(
        find.text('Lekki Phase 1, Lagos'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('List'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Search').last)
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      final listing = find.byKey(const ValueKey<String>('listing-5001'));
      await Scrollable.ensureVisible(
        tester.element(listing),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(listing) + const Offset(24, 24));
      await tester.pump();
      expect(
        find.text("Property details aren't part of this preview."),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      final searchField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('property-search-field'),
          ),
          matching: find.byType(EditableText),
        ),
      );
      expect(searchField.controller.text, 'Lekki');
      expect(
        find.bySemanticsLabel(
          RegExp('For Sale property in Lekki Phase 1, Lagos'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('List'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('listing-5001')),
        findsOneWidget,
      );

      // Notifications remain an explicit preview boundary.
      await tester.tap(find.bySemanticsLabel('Notification'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Notifications are not part of this preview.'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.text('Prince Adeyemi'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Profile').last)
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );
}

Widget _platformHarness(TargetPlatform platform) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(
      AppConfig.parse(
        'http://127.0.0.1:54321/functions/v1/api',
        isRelease: false,
      ),
    ),
    feedRepositoryProvider.overrideWithValue(_CountingRepository()),
    searchRepositoryProvider.overrideWithValue(_SearchRepository()),
    recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
    profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
  ],
  child: ExpertListingApp(platformOverride: platform),
);

final class _CountingRepository extends FeedRepository {
  _CountingRepository() : super(client: Dio());

  int loadCalls = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) {
    loadCalls++;
    return Future.value(
      filter.postType == PostType.property ? _propertyPage() : _page(),
    );
  }
}

final class _SearchRepository extends SearchRepository {
  _SearchRepository() : super(client: Dio());

  @override
  Future<List<SearchSuggestion>> suggestions(String query) async => const [
    PropertySearchSuggestion(
      postId: 1001,
      propertyId: 5001,
      status: PropertyStatus.forSale,
      location: 'Lekki Phase 1, Lagos',
      summary: 'A bright family home.',
      imageUrl: null,
    ),
  ];
}

final class _ProfileRepository extends ProfileRepository {
  _ProfileRepository() : super(client: Dio());

  @override
  Future<ProfileResult> load() async => const ProfileResult(
    profile: Profile(
      handle: 'prince',
      displayName: 'Prince Adeyemi',
      role: 'Realtor',
      avatarUrl: null,
    ),
    previewActors: [],
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

FeedLoadResult _page() => FeedLoadResult(
  posts: [
    FeedPost.fromJson(_post()),
  ],
  nextCursor: null,
  source: FeedDataSource.network,
);

FeedLoadResult _propertyPage() => FeedLoadResult(
  posts: [FeedPost.fromJson(_propertyPost())],
  nextCursor: null,
  source: FeedDataSource.network,
);

Map<String, dynamic> _post() => {
  'id': 42,
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
};

Map<String, dynamic> _propertyPost() => {
  'id': 1001,
  'body': 'A bright family home.',
  'postType': 'property',
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
  'property': const {
    'id': 5001,
    'status': 'for_sale',
    'location': 'Lekki Phase 1, Lagos',
    'images': <Map<String, dynamic>>[],
  },
};
