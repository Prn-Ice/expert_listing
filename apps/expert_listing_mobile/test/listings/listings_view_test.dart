import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/listings/view/listings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ListingsView, () {
    testWidgets(
      'shows a swipeable property-first card at 360px in dark mode',
      (tester) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var presses = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(_Repository()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(platform: TargetPlatform.android),
              home: Scaffold(
                body: ListingsView(
                  isActive: true,
                  onListingPressed: () => presses++,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Properties'), findsOneWidget);
        expect(find.text('For Sale'), findsOneWidget);
        expect(find.text('Lekki Phase 1, Lagos'), findsOneWidget);
        expect(find.text('A bright family home.'), findsOneWidget);
        expect(find.text('Prince'), findsNothing);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('A bright family home.')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Next photo'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Next photo'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Previous photo'));
        await tester.pumpAndSettle();
        expect(find.text('1 / 2'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('listing-5001')),
        );
        await tester.pump();
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('retries a service failure into an empty 428px catalog', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(428, 926)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var attempts = 0;
      final repository = _Repository((_, _) {
        attempts++;
        if (attempts == 1) {
          return Future.error(
            const FeedLoadFailure(FeedFailureKind.service),
          );
        }
        return Future.value(
          const FeedLoadResult(
            posts: [],
            nextCursor: null,
            source: FeedDataSource.network,
          ),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light(platform: TargetPlatform.android),
            home: Scaffold(
              body: ListingsView(
                isActive: true,
                onListingPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Properties are unavailable. Try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(find.text('No properties yet.'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    });
  });
}

final class _Repository extends FeedRepository {
  _Repository([this._load]) : super(client: Dio());

  final Future<FeedLoadResult> Function(FeedFilter filter, String? cursor)?
  _load;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
  }) {
    final load = _load;
    if (load != null) return load(filter, cursor);
    return Future.value(
      FeedLoadResult(
        posts: [FeedPost.fromJson(_propertyPost())],
        nextCursor: null,
        source: FeedDataSource.network,
      ),
    );
  }
}

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
    'images': [
      {'id': 1, 'url': 'https://example.com/one.jpg', 'position': 0},
      {'id': 2, 'url': 'https://example.com/two.jpg', 'position': 1},
    ],
  },
};
