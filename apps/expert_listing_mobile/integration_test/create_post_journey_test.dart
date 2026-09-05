import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/create_post/create_post_image.dart';
import 'package:expert_listing/create_post/create_post_sheet.dart';
import 'package:expert_listing/create_post/post_image_picker.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/disabled_notification_alert_service.dart';

/// The required creation journey through Flutter multipart serialization,
/// real Hono, Storage, and Postgres. It intentionally creates durable rows and
/// must run only against the resettable local stack.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates every variant and restores ordered property images', (
    tester,
  ) async {
    final config = AppConfig.fromEnvironment();
    final picker = _FixtureImagePicker();
    await _pumpApp(tester, config, picker, key: 'first-launch');
    await _pumpUntilFound(tester, find.byType(PostCard));

    const propertyBody = 'Integration property with ordered images.';
    final propertyPostId = await _createPost(
      tester,
      body: propertyBody,
      location: 'Ikoyi, Lagos',
      postType: 'Property',
      subtype: 'For rent',
      addImages: true,
    );
    await _createPost(
      tester,
      body: 'Integration general post.',
      location: 'Yaba, Lagos',
      postType: 'General',
    );
    await _createPost(
      tester,
      body: 'Integration request post.',
      location: 'Surulere, Lagos',
      postType: 'Request',
      subtype: 'Looking to rent',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpApp(tester, config, picker, key: 'relaunch');
    await _pumpUntil(
      tester,
      () => find
          .byWidgetPredicate(
            (widget) => widget is PostCard && widget.post.id == propertyPostId,
          )
          .evaluate()
          .isNotEmpty,
    );

    final propertyCard = tester.widget<PostCard>(
      find
          .byWidgetPredicate(
            (widget) => widget is PostCard && widget.post.id == propertyPostId,
          )
          .first,
    );
    final property = propertyCard.post as PropertyFeedPost;
    expect(property.status.name, 'forRent');
    expect(property.location, 'Ikoyi, Lagos');
    expect(property.images, hasLength(2));
    expect(property.images.map((image) => image.position), [0, 1]);
    expect(property.images[0].url, endsWith('/0.jpg'));
    expect(property.images[1].url, endsWith('/1.jpg'));
    expect(find.text('Integration general post.'), findsWidgets);
    expect(find.text('Integration request post.'), findsWidgets);
  });
}

Future<int> _createPost(
  WidgetTester tester, {
  required String body,
  required String location,
  required String postType,
  String? subtype,
  bool addImages = false,
}) async {
  await tester.ensureVisible(
    find.text('Share a property, Make a request or say something...'),
  );
  await tester.tap(
    find.text('Share a property, Make a request or say something...'),
  );
  await _pumpUntilFound(tester, find.byType(CreatePostSheet));
  final sheet = find.byKey(const ValueKey<String>('create-post-sheet'));

  final typeChoice = find.descendant(of: sheet, matching: find.text(postType));
  await tester.ensureVisible(typeChoice);
  await tester.tap(typeChoice);
  await tester.pump();
  if (subtype != null) {
    final subtypeChoice = find.descendant(
      of: sheet,
      matching: find.text(subtype),
    );
    await tester.ensureVisible(subtypeChoice);
    await tester.tap(subtypeChoice);
    await tester.pump();
  }
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey<String>('create-post-body')),
      matching: find.byType(EditableText),
    ),
    body,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey<String>('create-post-location')),
      matching: find.byType(EditableText),
    ),
    location,
  );
  await tester.pump();

  if (addImages) {
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Add images')),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('create-post-image-1'))
          .evaluate()
          .isNotEmpty,
    );
  }

  await tester.ensureVisible(
    find.descendant(of: sheet, matching: find.text('Publish')),
  );
  await tester.tap(find.descendant(of: sheet, matching: find.text('Publish')));
  await _pumpUntil(
    tester,
    () => find.byType(CreatePostSheet).evaluate().isEmpty,
  );
  await _pumpUntilFound(
    tester,
    find.byWidgetPredicate(
      (widget) => widget is PostCard && widget.post.body == body,
    ),
  );
  await _pumpUntilFound(tester, find.text('Post published.'));
  expect(find.text('Post published.'), findsOneWidget);
  final postId = tester
      .widget<PostCard>(
        find
            .byWidgetPredicate(
              (widget) => widget is PostCard && widget.post.body == body,
            )
            .first,
      )
      .post
      .id;
  if (find.text('OK').evaluate().isNotEmpty) {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
  return postId;
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppConfig config,
  PostImagePicker picker, {
  required String key,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey<String>(key),
      overrides: [
        appConfigProvider.overrideWithValue(config),
        notificationAlertServiceProvider.overrideWithValue(
          DisabledNotificationAlertService(),
        ),
        postImagePickerProvider.overrideWithValue(picker),
      ],
      child: const ExpertListingApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) => _pumpUntil(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('Timed out waiting for create-post state.');
}

final class _FixtureImagePicker implements PostImagePicker {
  @override
  Future<List<CreatePostImage>> pickImages({required int limit}) async {
    final images = <CreatePostImage>[];
    for (final name in ['current-user.jpg', 'ayo.jpg'].take(limit)) {
      final data = await rootBundle.load('assets/images/$name');
      images.add(
        CreatePostImage(
          name: name,
          bytes: Uint8List.sublistView(data),
        ),
      );
    }
    return images;
  }
}
