import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The native boundary that requests permission and presents activity alerts.
abstract interface class NotificationAlertService {
  /// Initializes native notifications and returns whether alerts are allowed.
  Future<bool> requestPermission();

  /// Presents one audible notification for new activity.
  Future<void> show(ActivityNotification notification);
}

/// Presents foreground activity through the platform notification service.
final class LocalNotificationAlertService implements NotificationAlertService {
  /// Creates the native local-notification boundary.
  LocalNotificationAlertService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _androidDetails = AndroidNotificationDetails(
    'activity-notifications',
    'Activity notifications',
    channelDescription: 'Likes on your Expert Listing posts',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.social,
  );
  static const _darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: false,
    presentSound: true,
    presentBanner: true,
    presentList: true,
    threadIdentifier: 'activity-notifications',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }

    try {
      await (_initialization ??= _initialize());
      return switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              false,
        TargetPlatform.iOS =>
          await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(
                    alert: true,
                    sound: true,
                  ) ??
              false,
        _ => false,
      };
    } on Object {
      return false;
    }
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentBadge: false,
        ),
      ),
    );
  }

  @override
  Future<void> show(ActivityNotification notification) async {
    try {
      await _plugin.show(
        id: notification.id.remainder(0x7fffffff),
        title: 'New activity',
        body: '${notification.actor.displayName} liked your post.',
        notificationDetails: const NotificationDetails(
          android: _androidDetails,
          iOS: _darwinDetails,
        ),
        payload: 'notification:${notification.id}',
      );
    } on Object {
      // Native notification failure must not interrupt the app or repeat
      // alerts.
    }
  }
}
