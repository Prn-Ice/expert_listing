import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notification_alert_cursor_store.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Verifies the native foreground-alert boundary against real local activity.
/// Notification permission must be granted before the test runner starts.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('presents one native alert for a new like event', (tester) async {
    final config = AppConfig.fromEnvironment();
    final bizzaroClient = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUri.toString(),
        headers: const {'X-Preview-Actor': 'bizzaro'},
      ),
    );
    final bizzaroFeed = FeedRepository(client: bizzaroClient);
    final princeClient = Dio(
      BaseOptions(baseUrl: config.apiBaseUri.toString()),
    );
    final notifications = _RecordingNotificationsRepository(
      client: princeClient,
    );
    const postId = 1006;
    await tester.runAsync(
      () => bizzaroFeed.setPostLiked(postId: postId, liked: false),
    );
    addTearDown(() async {
      await bizzaroFeed.setPostLiked(postId: postId, liked: false);
      bizzaroClient.close();
      princeClient.close();
    });

    final plugin = FlutterLocalNotificationsPlugin();
    final alerts = _RecordingAlertService(
      LocalNotificationAlertService(plugin),
    );
    addTearDown(plugin.cancelAll);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          feedRepositoryProvider.overrideWith(
            (ref) => FeedRepository(client: ref.watch(httpClientProvider)),
          ),
          notificationAlertServiceProvider.overrideWithValue(alerts),
          notificationAlertCursorStoreProvider.overrideWithValue(
            _RecordingCursorStore(),
          ),
          notificationsRepositoryProvider.overrideWithValue(notifications),
          notificationAlertPollIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 500),
          ),
        ],
        child: const ExpertListingApp(),
      ),
    );
    await tester.pump();
    final baselineCompleted = await tester.runAsync(
      () => notifications.firstLoad.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      ),
    );
    expect(
      baselineCompleted,
      isTrue,
      reason: 'Grant notification permission before running this journey.',
    );
    if (baselineCompleted != true) return;

    await tester.runAsync(
      () => bizzaroFeed.setPostLiked(postId: postId, liked: true),
    );
    final notification = await tester.runAsync(
      () => alerts.firstAlert.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      ),
    );

    expect(notification, isNotNull);
    if (notification == null) return;
    expect(notification.actor.handle, 'bizzaro');
    expect(notification.post.id, postId);
    expect(alerts.alertCount, 1);
  });
}

final class _RecordingAlertService implements NotificationAlertService {
  _RecordingAlertService(this._delegate);

  final NotificationAlertService _delegate;
  final firstAlert = Completer<ActivityNotification?>();
  int alertCount = 0;

  @override
  Future<bool> requestPermission() => _delegate.requestPermission();

  @override
  Future<void> show(ActivityNotification notification) async {
    await _delegate.show(notification);
    alertCount++;
    if (!firstAlert.isCompleted) firstAlert.complete(notification);
  }
}

final class _RecordingCursorStore implements NotificationAlertCursorStore {
  int? _cursor;

  @override
  Future<int?> load(String actorKey) async => _cursor;

  @override
  Future<void> save(String actorKey, int notificationId) async {
    _cursor = notificationId;
  }
}

final class _RecordingNotificationsRepository extends NotificationsRepository {
  _RecordingNotificationsRepository({required super.client});

  final firstLoad = Completer<bool>();

  @override
  Future<List<ActivityNotification>> load() async {
    final notifications = await super.load();
    if (!firstLoad.isCompleted) firstLoad.complete(true);
    return notifications;
  }
}
