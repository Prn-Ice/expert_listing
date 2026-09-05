import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';

/// Keeps unrelated journeys from opening a native permission prompt.
final class DisabledNotificationAlertService
    implements NotificationAlertService {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(ActivityNotification notification) async {}
}
