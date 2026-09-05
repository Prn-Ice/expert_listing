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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every destination answers or names its boundary', (
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
          .getSemantics(find.bySemanticsLabel('Search'))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    // Feed re-enters its own surface: at the top it refreshes.
    await tester.tap(find.bySemanticsLabel('Feed'));
    await tester.pump();
    await tester.pump();
    expect(repository.loadCalls, greaterThan(initialLoads));

    // The other destinations answer with their boundary notices.
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Search is not part of this preview. Try Filters.'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('List'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Post creation is part of the next preview step.'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Notifications are not part of this preview.'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Profiles are not part of this preview.'),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    semantics.dispose();
  });
}

final class _CountingRepository extends FeedRepository {
  _CountingRepository() : super(client: Dio());

  int loadCalls = 0;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    loadCalls++;
    return Future.value(_page());
  }
}

FeedLoadResult _page() => FeedLoadResult(
  posts: [
    FeedPost.fromJson(_post()),
  ],
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
