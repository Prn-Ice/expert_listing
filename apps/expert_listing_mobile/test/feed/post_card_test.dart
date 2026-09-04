import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'general, request, and property cards keep their metadata rules',
    (
      tester,
    ) async {
      final posts = [
        _generalPost(),
        _requestPost(),
        _propertyPost(),
        _requestRentPost(),
        _propertyRentPost(),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final post in posts)
                    PostCard(post: post, onNotice: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Buyer'), findsNWidgets(5));
      expect(find.text('Looking to Buy'), findsOneWidget);
      expect(find.text('Looking to Rent'), findsOneWidget);
      expect(find.text('For Sale'), findsOneWidget);
      expect(find.text('For Rent'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('post-tag-1')), findsNothing);
      expect(find.byKey(const ValueKey<String>('post-tag-2')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('post-tag-3')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('post-tag-4')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('post-tag-5')), findsOneWidget);
      final forSaleIcon = tester.widget<AppIcon>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('post-tag-3')),
          matching: find.byType(AppIcon),
        ),
      );
      expect(forSaleIcon.asset, AppIcons.postTag);
      expect(forSaleIcon.size, 12);
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(
                of: find.byKey(const ValueKey<String>('post-tag-2')),
                matching: find.byType(AppIcon),
              ),
            )
            .asset,
        AppIcons.lookingToBuyTag,
      );
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(
                of: find.byKey(const ValueKey<String>('post-tag-4')),
                matching: find.byType(AppIcon),
              ),
            )
            .asset,
        AppIcons.lookingToRentKey,
      );
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(
                of: find.byKey(const ValueKey<String>('post-tag-5')),
                matching: find.byType(AppIcon),
              ),
            )
            .asset,
        AppIcons.propertyRentKey,
      );
      final body = tester.widget<Text>(find.text('Post 1'));
      expect(body.style?.fontSize, 16);
      expect(body.style?.fontWeight, FontWeight.w500);
      expect(body.style?.height, 1.2);
    },
  );

  testWidgets(
    'zero counts stay icon-only and named controls use 48px targets',
    (
      tester,
    ) async {
      final notices = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostCard(post: _generalPost(), onNotice: notices.add),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Like'), findsOneWidget);
      expect(find.bySemanticsLabel('Like, 0'), findsNothing);
      expect(find.text('0 Views'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('author-avatar-1'))),
        const Size(48, 48),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('author-name-1')))
            .height,
        48,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('post-overflow-1'))),
        const Size(48, 48),
      );
      await tester.tap(find.byKey(const ValueKey<String>('author-avatar-1')));
      await tester.tap(find.byKey(const ValueKey<String>('author-name-1')));
      expect(
        notices,
        [
          'Profiles are not part of this preview.',
          'Profiles are not part of this preview.',
        ],
      );
    },
  );

  testWidgets('formats one thousand views without a decimal', (tester) async {
    final post = FeedPost.fromJson({..._commonPost(id: 4), 'viewCount': 1000});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostCard(post: post, onNotice: (_) {}),
        ),
      ),
    );

    expect(find.text('1K Views'), findsOneWidget);
    expect(find.text('1.0K Views'), findsNothing);
  });
}

FeedPost _generalPost() => FeedPost.fromJson(_commonPost(id: 1));

FeedPost _requestPost() => FeedPost.fromJson({
  ..._commonPost(id: 2),
  'postType': 'request',
  'request': const <String, String>{
    'type': 'looking_to_buy',
    'location': 'Yaba, Lagos',
  },
});

FeedPost _propertyPost() => FeedPost.fromJson({
  ..._commonPost(id: 3),
  'postType': 'property',
  'property': const <String, dynamic>{
    'id': 3,
    'status': 'for_sale',
    'location': 'Lekki Phase 1, Lagos',
    'images': <Map<String, dynamic>>[],
  },
});

FeedPost _requestRentPost() => FeedPost.fromJson({
  ..._commonPost(id: 4),
  'postType': 'request',
  'request': const <String, String>{
    'type': 'looking_to_rent',
    'location': 'Yaba, Lagos',
  },
});

FeedPost _propertyRentPost() => FeedPost.fromJson({
  ..._commonPost(id: 5),
  'postType': 'property',
  'property': const <String, dynamic>{
    'id': 5,
    'status': 'for_rent',
    'location': 'Lekki Phase 1, Lagos',
    'images': <Map<String, dynamic>>[],
  },
});

Map<String, dynamic> _commonPost({required int id}) => {
  'id': id,
  'body': 'Post $id',
  'postType': 'general',
  'createdAt': '2026-09-03T12:00:00.000Z',
  'viewCount': 0,
  'bookmarkCount': 0,
  'likeCount': 0,
  'commentCount': 0,
  'likedByCurrentUser': false,
  'author': {
    'id': '11111111-1111-4111-8111-111111111111',
    'handle': 'prince',
    'displayName': 'Prince',
    'role': 'Buyer',
    'avatarUrl': null,
  },
  'location': 'Yaba, Lagos',
};
