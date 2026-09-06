import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/create_post_prompt.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/feed/view/property_media.dart';
import 'package:expert_listing/feed/view/story_strip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feed controls render the Cupertino family under iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final post = FeedPost.fromJson({
        ..._commonPost(id: 1),
        'commentCount': 3,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostCard(post: post, onNotice: (_) {}),
          ),
        ),
      );

      expect(find.byType(CupertinoButton), findsWidgets);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(InkResponse), findsNothing);
      expect(
        tester.getTopLeft(find.text('View all 3 comments')).dx,
        tester.getTopLeft(find.text('Post 1')).dx,
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('post-comments-1')),
            )
            .height,
        greaterThanOrEqualTo(AppIconSize.tapTarget),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

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
    (tester) async {
      final notices = <String>[];
      final semantics = tester.ensureSemantics();
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
      // The avatar visual keeps its measured 40px circle inside the profile
      // action.
      expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('post-profile-1')))
            .height,
        48,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('post-overflow-1'))),
        const Size(48, 48),
      );

      // One semantic profile button spans the avatar and the identity.
      final profile = find.bySemanticsLabel('Prince, view profile');
      expect(profile, findsOneWidget);
      expect(tester.getSemantics(profile).flagsCollection.isButton, isTrue);
      await tester.tap(profile);
      expect(notices, ['Profiles are not part of this preview.']);
      semantics.dispose();
    },
  );

  testWidgets(
    'profile and engagement buttons activate across their 48px targets',
    (tester) async {
      final notices = <String>[];
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PostCard(post: _generalPost(), onNotice: notices.add),
            ),
          ),
        );

        Finder actionButton(String label) => find.ancestor(
          of: find.bySemanticsLabel(label),
          matching: find.byType(AppIconButton),
        );

        for (final label in ['Like', 'Comments', 'Share']) {
          final button = actionButton(label);
          final buttonRect = tester.getRect(button);
          final icon = find.descendant(
            of: button,
            matching: find.byType(AppIcon),
          );
          expect(
            tester.getRect(icon).center.dx,
            buttonRect.center.dx,
            reason: '$label icon must be horizontally centered in its target',
          );
          expect(
            tester.getRect(icon).center.dy,
            buttonRect.center.dy,
            reason: '$label content must be centered in its pressed overlay',
          );
        }

        final likeButton = actionButton('Like');
        final likeRect = tester.getRect(likeButton);
        final bodyRect = tester.getRect(find.text('Post 1'));
        final likeIconRectFinder = find.descendant(
          of: likeButton,
          matching: find.byType(AppIcon),
        );
        final likeIconRect = tester.getRect(likeIconRectFinder);
        expect(
          likeRect.left,
          bodyRect.left - AppSpacing.large,
          reason: 'the action target uses the space before the content edge',
        );
        final locationIconRect = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget is AppIcon && widget.asset == AppIcons.mapPin,
          ),
        );
        expect(
          likeIconRect.top - locationIconRect.bottom,
          AppSpacing.large,
          reason: 'the centered action keeps ordinary in-flow geometry',
        );

        final cardRect = tester.getRect(find.byType(PostCard));
        final bookmarkButtonRect = tester.getRect(actionButton('Bookmark'));
        expect(
          bookmarkButtonRect.right,
          moreOrLessEquals(
            cardRect.right - AppSpacing.xlarge + AppSpacing.large,
          ),
          reason: 'the target uses space beyond the visible content edge',
        );

        expect(likeButton, findsOneWidget);
        expect(likeRect.size, const Size.square(AppIconSize.tapTarget));

        final press = await tester.startGesture(likeRect.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(likeIconRectFinder).center, likeRect.center);
        await press.cancel();
        await tester.pump();

        for (final point in <Offset>[
          likeRect.topLeft + const Offset(1, 1),
          likeRect.topRight + const Offset(-1, 1),
          likeRect.bottomLeft + const Offset(1, -1),
          likeRect.bottomRight + const Offset(-1, -1),
        ]) {
          await tester.tapAt(point);
          await tester.pump();
        }
        expect(
          notices,
          List<String>.filled(
            4,
            'Likes are part of the next preview step.',
          ),
        );

        final profileButton = find.byKey(
          const ValueKey<String>('post-profile-1'),
        );
        final profileRect = tester.getRect(profileButton);
        expect(profileRect.height, AppIconSize.tapTarget);
        await tester.tapAt(profileRect.topLeft + const Offset(1, 1));
        await tester.pump();
        expect(
          notices.last,
          'Profiles are not part of this preview.',
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('selected engagement uses filled brand icons', (tester) async {
    final post = FeedPost.fromJson({
      ..._commonPost(id: 1),
      'likeCount': 1,
      'likedByCurrentUser': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostCard(post: post, bookmarked: true, onNotice: (_) {}),
        ),
      ),
    );

    AppIcon selectedIcon(String label) {
      final button = find.ancestor(
        of: find.bySemanticsLabel(label),
        matching: find.byType(AppIconButton),
      );
      return tester.widget<AppIcon>(
        find.descendant(of: button, matching: find.byType(AppIcon)),
      );
    }

    final heart = selectedIcon('Unlike, 1');
    final bookmark = selectedIcon('Remove bookmark, 1');
    expect(heart.asset, AppIcons.heartFilled);
    expect(bookmark.asset, AppIcons.bookmarkFilled);
    expect(heart.color, AppColors.light.brandText);
    expect(bookmark.color, AppColors.light.brandText);
  });

  testWidgets('the profile pressed overlay moves no visible geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostCard(post: _generalPost(), onNotice: (_) {}),
        ),
      ),
    );

    final targets = <String, Finder>{
      'avatar': find.byType(ClipOval),
      'name': find.text('Prince'),
      'meta': find.textContaining('General'),
      'body': find.text('Post 1'),
      'overflow': find.byKey(const ValueKey<String>('post-overflow-1')),
    };
    Map<String, Rect> measure() => {
      for (final entry in targets.entries)
        entry.key: tester.getRect(entry.value),
    };

    final idle = measure();

    // Press and hold the profile action: the ink highlight shows while the
    // pointer is down and every measured position must stay identical.
    final press = await tester.startGesture(
      tester.getCenter(find.text('Prince')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final pressed = measure();

    expect(pressed, idle);

    await press.up();
    await tester.pump();
  });

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

  testWidgets('views follow share and comments align with post content', (
    tester,
  ) async {
    final post = FeedPost.fromJson({
      ..._commonPost(id: 6),
      'viewCount': 243,
      'commentCount': 2,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostCard(post: post, onNotice: (_) {}),
        ),
      ),
    );

    final shareButton = find.ancestor(
      of: find.bySemanticsLabel('Share'),
      matching: find.byType(AppIconButton),
    );
    final views = find.byKey(const ValueKey<String>('post-views-6'));
    final bookmark = find.descendant(
      of: find.ancestor(
        of: find.bySemanticsLabel('Bookmark'),
        matching: find.byType(AppIconButton),
      ),
      matching: find.byType(AppIcon),
    );
    expect(tester.getRect(views).left, tester.getRect(shareButton).right);
    expect(
      tester.getRect(views).right,
      lessThan(tester.getRect(bookmark).left),
    );

    final actions = find.byKey(const ValueKey<String>('post-actions-6'));
    final comments = find.byKey(const ValueKey<String>('post-comments-6'));
    final commentsText = find.text('View all 2 comments');
    final body = find.text('Post 6');
    final divider = find.byType(Divider);
    final commentsLabel = tester.widget<Text>(commentsText);
    expect(tester.getRect(comments).top, tester.getRect(actions).bottom);
    expect(tester.getRect(comments).height, AppIconSize.tapTarget);
    expect(tester.getRect(divider).top, tester.getRect(comments).bottom);
    expect(tester.getRect(commentsText).left, tester.getRect(body).left);
    expect(tester.getRect(comments).left, tester.getRect(commentsText).left);
    expect(
      tester.getRect(commentsText).center.dy,
      tester.getRect(comments).center.dy,
    );
    expect(commentsLabel.style?.fontSize, 14);
    expect(commentsLabel.style?.fontWeight, FontWeight.w500);
    expect(commentsLabel.style?.height, 1.2);
    expect(commentsLabel.style?.color, AppColors.light.textTertiary);
  });

  testWidgets('renders bounded liker and latest-comment previews', (
    tester,
  ) async {
    var commentsOpened = 0;
    final post = FeedPost.fromJson({
      ..._commonPost(id: 8),
      'likeCount': 2,
      'commentCount': 2,
      'likePreview': const [
        <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000003',
          'handle': 'ifeoma',
          'displayName': 'Ifeoma Nwosu',
          'role': 'Architect',
          'avatarUrl': 'https://example.test/ifeoma.jpg',
        },
        <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000001',
          'handle': 'prince',
          'displayName': 'Prince Adeyemi',
          'role': 'Realtor',
          'avatarUrl': 'https://example.test/prince.jpg',
        },
      ],
      'latestComment': const <String, dynamic>{
        'id': 3002,
        'body': 'The study could work well as a nursery too.',
        'author': <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000003',
          'handle': 'ifeoma',
          'displayName': 'Ifeoma Nwosu',
          'role': 'Architect',
          'avatarUrl': 'https://example.test/ifeoma.jpg',
        },
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 428,
            child: PostCard(
              post: post,
              onNotice: (_) {},
              onComments: () => commentsOpened++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Liked by ifeoma and 1 other'), findsOneWidget);
    final avatarGroup = find.byKey(
      const ValueKey<String>('post-liker-avatars'),
    );
    final avatars = find.descendant(
      of: avatarGroup,
      matching: find.byType(AppAvatar),
    );
    final avatarFrames = find.descendant(
      of: avatarGroup,
      matching: find.byKey(
        const ValueKey<String>('post-liker-avatar-0'),
      ),
    );
    expect(avatars, findsNWidgets(2));
    expect(tester.getSize(avatarGroup), const Size(42, 24));
    expect(tester.getSize(avatarFrames), const Size.square(24));
    expect(tester.getSize(avatars.at(0)), const Size.square(20));
    final firstRing = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('post-liker-avatar-ring-0')),
    );
    expect(
      firstRing.decoration,
      const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
    expect(
      tester.getRect(avatarFrames).right -
          tester
              .getRect(
                find.byKey(
                  const ValueKey<String>('post-liker-avatar-1'),
                ),
              )
              .left,
      6,
    );
    expect(find.text('ifeoma'), findsOneWidget);
    expect(
      find.text('The study could work well as a nursery too.'),
      findsOneWidget,
    );
    expect(find.text('View all 2 comments'), findsOneWidget);

    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey<String>('post-comments-8')),
          )
          .label,
      contains('The study could work well as a nursery too.'),
    );
    await tester.tap(find.byKey(const ValueKey<String>('post-comments-8')));
    expect(commentsOpened, 1);
  });

  testWidgets('uses concise copy for one comment', (tester) async {
    final post = FeedPost.fromJson({
      ..._commonPost(id: 9),
      'commentCount': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PostCard(post: post, onNotice: (_) {}),
        ),
      ),
    );

    expect(find.text('View comments'), findsOneWidget);
    expect(find.text('View all 1 comments'), findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey<String>('post-comments-9')),
          )
          .label,
      'View comments',
    );
  });

  testWidgets('counted edge actions align with the property image', (
    tester,
  ) async {
    final post = FeedPost.fromJson({
      ..._commonPost(id: 7),
      'likeCount': 2,
      'bookmarkCount': 17,
      'postType': 'property',
      'location': null,
      'property': const <String, dynamic>{
        'id': 7,
        'status': 'for_sale',
        'location': 'Lekki Phase 1, Lagos',
        'images': <Map<String, dynamic>>[
          {
            'id': 7,
            'url': 'https://example.test/property.jpg',
            'position': 0,
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 428,
              child: PostCard(post: post, onNotice: (_) {}),
            ),
          ),
        ),
      ),
    );

    Finder actionContent(String label) {
      final button = find.ancestor(
        of: find.bySemanticsLabel(label),
        matching: find.byType(AppIconButton),
      );
      return find.descendant(of: button, matching: find.byType(Row));
    }

    final mediaRect = tester.getRect(find.byType(PropertyMedia));
    expect(
      tester.getRect(actionContent('Like, 2')).left,
      moreOrLessEquals(mediaRect.left, epsilon: 1),
    );
    expect(
      tester.getRect(actionContent('Bookmark, 17')).right,
      moreOrLessEquals(mediaRect.right, epsilon: 1),
    );
  });

  testWidgets('icon-only edge actions align at 428 and 360 widths', (
    tester,
  ) async {
    for (final width in [428.0, 360.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: PostCard(post: _generalPost(), onNotice: (_) {}),
              ),
            ),
          ),
        ),
      );

      Finder actionIcon(String label) {
        final button = find.ancestor(
          of: find.bySemanticsLabel(label),
          matching: find.byType(AppIconButton),
        );
        return find.descendant(of: button, matching: find.byType(AppIcon));
      }

      final cardRect = tester.getRect(find.byType(PostCard));
      final bodyRect = tester.getRect(find.text('Post 1'));
      expect(tester.getRect(actionIcon('Like')).left, bodyRect.left);
      expect(
        tester.getRect(actionIcon('Bookmark')).right,
        cardRect.right - AppSpacing.xlarge,
      );
    }
  });

  testWidgets('the full-screen image viewer uses light icons on black', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: PropertyMedia(
              images: [
                PropertyImage(
                  id: 1,
                  url: 'https://example.test/property.jpg',
                  position: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).fit,
      BoxFit.cover,
    );

    await tester.tap(find.byType(AppPressable));
    await tester.pumpAndSettle();

    final fullScreenImage = find.descendant(
      of: find.byKey(const ValueKey<String>('full-screen-property-images')),
      matching: find.byType(AppNetworkImage),
    );
    expect(tester.widget<AppNetworkImage>(fullScreenImage).fit, BoxFit.contain);
    final zoom = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(zoom.minScale, 1);
    expect(zoom.maxScale, 4);

    final overlays = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .map((region) => region.value);
    expect(
      overlays,
      contains(
        isA<SystemUiOverlayStyle>()
            .having(
              (style) => style.statusBarIconBrightness,
              'Android icon brightness',
              Brightness.light,
            )
            .having(
              (style) => style.statusBarBrightness,
              'iOS status-bar brightness',
              Brightness.dark,
            ),
      ),
    );
  });

  testWidgets('the full-screen viewer toggles zoom without paging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: PropertyMedia(
              images: [
                PropertyImage(
                  id: 1,
                  url: 'https://example.test/property-1.jpg',
                  position: 0,
                ),
                PropertyImage(
                  id: 2,
                  url: 'https://example.test/property-2.jpg',
                  position: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Property photo 1 of 2'));
    await tester.pumpAndSettle();

    final zoomFinder = find.byKey(
      const ValueKey<String>('property-image-zoom-1'),
    );
    final center = tester.getCenter(zoomFinder);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    var zoom = tester.widget<InteractiveViewer>(zoomFinder);
    expect(zoom.transformationController!.value.getMaxScaleOnAxis(), 2.5);
    expect(
      tester
          .widget<PageView>(
            find.byKey(const ValueKey<String>('full-screen-property-images')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    zoom = tester.widget<InteractiveViewer>(zoomFinder);
    expect(zoom.transformationController!.value, Matrix4.identity());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the full-screen viewer uses the active platform route', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final observer = _PushedRouteObserver();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<TargetPlatform>(platform),
          navigatorObservers: [observer],
          theme: AppTheme.light(platform: platform),
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: PropertyMedia(
                images: [
                  PropertyImage(
                    id: 1,
                    url: 'https://example.test/property.jpg',
                    position: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppPressable));
      await tester.pumpAndSettle();

      expect(
        observer.lastPushed,
        platform == TargetPlatform.iOS
            ? isA<CupertinoPageRoute<void>>()
            : isA<MaterialPageRoute<void>>(),
      );
    }
  });

  testWidgets('the full-screen viewer starts tapped and pages in order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: PropertyMedia(
              images: [
                PropertyImage(
                  id: 1,
                  url: 'https://example.test/property-1.jpg',
                  position: 0,
                ),
                PropertyImage(
                  id: 2,
                  url: 'https://example.test/property-2.jpg',
                  position: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Property photo 2 of 2'));
    await tester.pumpAndSettle();

    final viewer = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('full-screen-property-images')),
    );
    expect(viewer.controller!.page, 1);

    await tester.tap(find.bySemanticsLabel('Previous photo'));
    await tester.pumpAndSettle();
    expect(viewer.controller!.page, 0);

    await tester.tap(find.bySemanticsLabel('Next photo'));
    await tester.pumpAndSettle();
    expect(viewer.controller!.page, 1);
  });

  testWidgets('feed rows grow and wrap at platform accessibility text sizes', (
    tester,
  ) async {
    final post = FeedPost.fromJson({
      ..._commonPost(id: 8),
      'likeCount': 120,
      'commentCount': 32,
      'viewCount': 2400,
      'bookmarkCount': 17,
      'likePreview': const [
        <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000003',
          'handle': 'ifeoma',
          'displayName': 'Ifeoma Nwosu',
          'role': 'Architect',
          'avatarUrl': null,
        },
      ],
      'latestComment': const <String, dynamic>{
        'id': 3002,
        'body': 'The study could work well as a nursery too.',
        'author': <String, dynamic>{
          'id': '00000000-0000-0000-0000-000000000003',
          'handle': 'ifeoma',
          'displayName': 'Ifeoma Nwosu',
          'role': 'Architect',
          'avatarUrl': null,
        },
      },
      'author': {
        ...(_commonPost(id: 8)['author']! as Map<String, dynamic>),
        'displayName': 'Prince Adeyemi with a long profile name',
      },
    });

    for (final textScale in [2.0, 3.0]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<double>(textScale),
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    StoryStrip(onNotice: (_) {}),
                    CreatePostPrompt(
                      onPressed: () {},
                      showInvitation: false,
                    ),
                    PostCard(post: post, onNotice: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'text scale $textScale');
    }

    expect(tester.getSize(find.text('Your Story')).height, greaterThan(30));
    expect(
      tester.getSize(find.byKey(const ValueKey('post-like-preview'))).height,
      greaterThan(24),
    );
  });

  testWidgets('a property carousel restores its page after reconstruction', (
    tester,
  ) async {
    final bucket = PageStorageBucket();
    var showCarousel = true;
    late StateSetter setHostState;
    const images = [
      PropertyImage(
        id: 11,
        url: 'https://example.test/property-1.jpg',
        position: 0,
      ),
      PropertyImage(
        id: 12,
        url: 'https://example.test/property-2.jpg',
        position: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return showCarousel
                    ? const SizedBox(
                        width: 388,
                        child: PropertyMedia(images: images),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    final media = find.byType(PropertyMedia);
    final indicatorBackdrop = find.byKey(
      const ValueKey<String>('property-media-11-indicators'),
    );
    Color activeIndicatorColor() =>
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(
                        const ValueKey<String>('property-media-11-indicator-1'),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(
      activeIndicatorColor(),
      Colors.white,
    );
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(
              const ValueKey<String>('property-media-11-indicator-1'),
            ),
          )
          .duration,
      AppMotion.medium,
    );
    expect(tester.getSize(media), const Size(388, 260));
    expect(
      tester.getBottomRight(indicatorBackdrop).dy,
      lessThan(tester.getBottomRight(media).dy),
    );
    expect(
      tester.getTopLeft(indicatorBackdrop).dy,
      greaterThan(tester.getTopLeft(media).dy),
    );

    setHostState(() => showCarousel = false);
    await tester.pump();
    expect(find.byType(PageView), findsNothing);

    setHostState(() => showCarousel = true);
    await tester.pumpAndSettle();

    expect(
      activeIndicatorColor(),
      Colors.white,
    );
  });
}

final class _PushedRouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
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
