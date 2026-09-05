import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notification_alert_cursor_store.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:expert_listing/notifications/view/notification_alert_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('polls on resume and remains quiet while paused', (tester) async {
    final repository = _NotificationsRepository();
    final service = _AlertService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          notificationAlertServiceProvider.overrideWithValue(service),
          notificationAlertCursorStoreProvider.overrideWithValue(
            _CursorStore(),
          ),
        ],
        child: const MaterialApp(
          home: NotificationAlertLifecycle(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    expect(repository.loadCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repository.notifications = [_notification];
    await tester.pump(const Duration(seconds: 31));
    expect(service.shown, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(service.shown, [_notification]);
  });
}

final class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository() : super(client: Dio());

  List<ActivityNotification> notifications = const [];
  int loadCalls = 0;

  @override
  Future<List<ActivityNotification>> load() async {
    loadCalls++;
    return notifications;
  }
}

final class _AlertService implements NotificationAlertService {
  final shown = <ActivityNotification>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(ActivityNotification notification) async {
    shown.add(notification);
  }
}

final class _CursorStore implements NotificationAlertCursorStore {
  int? cursor;

  @override
  Future<int?> load(String actorKey) async => cursor;

  @override
  Future<void> save(String actorKey, int notificationId) async {
    cursor = notificationId;
  }
}

final _notification = ActivityNotification(
  id: 10,
  createdAt: DateTime.utc(2026, 9, 5, 12),
  readAt: null,
  actor: const ActivityActor(
    handle: 'bizzaro',
    displayName: 'Bizzaro Cole',
    role: 'Homeowner',
    avatarUrl: null,
  ),
  post: const ActivityPost(id: 1006, body: 'A useful property update.'),
);
