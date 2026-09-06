import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/view/create_post_prompt.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/listings/view/listing_card.dart';
import 'package:expert_listing/listings/view/listings_view.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/disabled_notification_alert_service.dart';

/// The implemented discovery portion of the required journey through the
/// production provider graph and real Hono/Postgres/preferences boundaries.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'discovers properties and completes actor-scoped notification activity',
    (tester) async {
      final config = AppConfig.fromEnvironment();
      final recentSearches = SharedPreferencesRecentSearchStore();
      await tester.runAsync(recentSearches.clear);
      addTearDown(recentSearches.clear);
      await _pumpApp(tester, config);

      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('property-search-field')),
        'Lekki',
      );
      await _pumpUntilFound(
        tester,
        find.bySemanticsLabel(
          'Search Lekki Phase 1, Lagos, 1 properties',
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(
          'Search Lekki Phase 1, Lagos, 1 properties',
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('property-suggestion-5001')),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('property-suggestion-5001')),
      );
      await tester.pump();
      expect(
        find.text('Property details aren’t part of this preview.'),
        findsOneWidget,
      );
      if (find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () => _waitForRecentSearch(
          recentSearches,
          'Lekki Phase 1, Lagos',
        ),
      );

      final restoredSearches = await tester.runAsync(
        SharedPreferencesRecentSearchStore().load,
      );
      expect(restoredSearches, contains('Lekki Phase 1, Lagos'));
      await tester.enterText(
        find.byKey(const ValueKey<String>('property-search-field')),
        '',
      );
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.bySemanticsLabel('Search again for Lekki Phase 1, Lagos'),
      );

      await tester.tap(find.bySemanticsLabel('List'));
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('listing-5001')),
      );
      expect(find.byType(ListingCard), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('listing-5005')),
        findsNothing,
      );

      final catalog = find.descendant(
        of: find.byType(ListingsView),
        matching: find.byType(CustomScrollView),
      );
      await _dragUntilFound(
        tester,
        catalog,
        find.byKey(const ValueKey<String>('listing-5005')),
      );

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Prince Adeyemi'));
      expect(find.text('@prince'), findsOneWidget);
      expect(find.text('Realtor'), findsOneWidget);

      await tester.tap(find.text('Previewing @prince'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@bizzaro'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Bizzaro Cole'));
      expect(find.text('@bizzaro'), findsOneWidget);
      expect(find.text('Homeowner'), findsOneWidget);

      final bizzaroClient = _client(config, 'bizzaro');
      final princeClient = _client(config, 'prince');
      addTearDown(bizzaroClient.close);
      addTearDown(princeClient.close);
      final bizzaroFeed = FeedRepository(client: bizzaroClient);
      final princeNotifications = NotificationsRepository(client: princeClient);
      final existingNotifications =
          await tester.runAsync(princeNotifications.load) ?? const [];
      final existingIds = existingNotifications
          .map((notification) => notification.id)
          .toSet();

      const postId = 1006;
      await tester.tap(find.bySemanticsLabel('Feed'));
      await tester.pump();
      expect(
        tester
            .widget<AppAvatar>(
              find.descendant(
                of: find.byType(CreatePostPrompt),
                matching: find.byType(AppAvatar),
              ),
            )
            .displayName,
        'Bizzaro Cole',
      );
      await _scrollToPost(tester, postId);
      if (tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser) {
        await tester.tap(_postAction(postId, 'Unlike'));
        await tester.runAsync(
          () => _waitForLikeState(bizzaroFeed, postId, liked: false),
        );
      }
      await tester.tap(_postAction(postId, 'Like'));
      await tester.runAsync(
        () => _waitForLikeState(bizzaroFeed, postId, liked: true),
      );
      final notification = await tester.runAsync(
        () => _waitForNewNotification(
          princeNotifications,
          existingIds,
          postId,
          'bizzaro',
        ),
      );
      if (notification == null) {
        fail('The notification request did not finish.');
      }

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Bizzaro Cole'));
      await tester.tap(find.text('Previewing @bizzaro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@prince'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Prince Adeyemi'));

      await tester.tap(find.bySemanticsLabel('Notification'));
      await tester.pump();
      final notificationRow = find.byKey(ValueKey<int>(notification.id));
      await _pumpUntilFound(tester, notificationRow);
      expect(
        find.descendant(
          of: notificationRow,
          matching: find.textContaining('Bizzaro Cole', findRichText: true),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: notificationRow,
          matching: find.text('Mark as read'),
        ),
      );
      final readAt = await tester.runAsync(
        () => _waitForRead(princeNotifications, notification.id),
      );
      expect(readAt, isNotNull);

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Prince Adeyemi'));
      await tester.tap(find.text('Previewing @prince'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@bizzaro'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Feed'));
      await tester.pump();
      await _scrollToPost(tester, postId);
      await tester.tap(_postAction(postId, 'Unlike'));
      await tester.runAsync(
        () => _waitForLikeState(bizzaroFeed, postId, liked: false),
      );

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Bizzaro Cole'));
      await tester.tap(find.text('Previewing @bizzaro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@prince'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Notification'));
      await tester.pump();
      await _pumpUntilFound(tester, notificationRow);
      expect(
        await tester.runAsync(
          () => _waitForRead(princeNotifications, notification.id),
        ),
        readAt,
      );
    },
  );
}

Dio _client(AppConfig config, String actor) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUri.toString(),
    headers: {'X-Preview-Actor': actor},
  ),
);

Finder _post(int postId) => find.byWidgetPredicate(
  (widget) => widget is PostCard && widget.post.id == postId,
);

Finder _postAction(int postId, String label) => find.descendant(
  of: find.byKey(ValueKey<String>('post-actions-$postId')),
  matching: find.bySemanticsLabel(
    RegExp('^${RegExp.escape(label)}(?:,|${r'$'})'),
  ),
);

Future<void> _scrollToPost(WidgetTester tester, int postId) async {
  await _pumpUntilFound(tester, find.byType(PostCard));
  await tester.scrollUntilVisible(
    _post(postId),
    400,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _waitForLikeState(
  FeedRepository repository,
  int postId, {
  required bool liked,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(end)) {
    final page = await repository.loadPage(
      filter: const FeedFilter(),
      limit: 20,
    );
    final post = page.posts.where((post) => post.id == postId).firstOrNull;
    if (post?.likedByCurrentUser == liked) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for post $postId liked=$liked');
}

Future<ActivityNotification> _waitForNewNotification(
  NotificationsRepository repository,
  Set<int> existingIds,
  int postId,
  String actorHandle,
) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(end)) {
    final notifications = await repository.load();
    for (final notification in notifications) {
      if (!existingIds.contains(notification.id) &&
          notification.post.id == postId &&
          notification.actor.handle == actorHandle) {
        return notification;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for a new notification.');
}

Future<DateTime> _waitForRead(
  NotificationsRepository repository,
  int notificationId,
) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(end)) {
    final notifications = await repository.load();
    final notification = notifications
        .where((notification) => notification.id == notificationId)
        .firstOrNull;
    if (notification?.readAt case final readAt?) return readAt;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for notification $notificationId to be read.');
}

Future<void> _dragUntilFound(
  WidgetTester tester,
  Finder scrollable,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out scrolling to $finder');
}

Future<void> _waitForRecentSearch(
  RecentSearchStore store,
  String query,
) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(end)) {
    if ((await store.load()).contains(query)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for recent search $query');
}

Future<void> _pumpApp(WidgetTester tester, AppConfig config) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        // Offline cache behavior has dedicated integration coverage. Omitting
        // it here avoids flutter_cache_manager's delayed SQLite cleanup after
        // the device test has already completed.
        feedRepositoryProvider.overrideWith(
          (ref) => FeedRepository(client: ref.watch(httpClientProvider)),
        ),
        notificationAlertServiceProvider.overrideWithValue(
          DisabledNotificationAlertService(),
        ),
      ],
      child: const ExpertListingApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
