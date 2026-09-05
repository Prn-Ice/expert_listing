import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FlutterLocalNotificationsPlatform originalPlatform;

  setUp(() {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    originalPlatform = FlutterLocalNotificationsPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    FlutterLocalNotificationsPlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  test('requests iOS permission after deferred initialization', () async {
    final platform = _IosNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = platform;

    final granted = await LocalNotificationAlertService().requestPermission();

    expect(platform.initializeCalls, 1);
    expect(platform.permissionCalls, 1);
    expect(granted, isTrue);
  });
}

final class _IosNotificationsPlatform
    extends IOSFlutterLocalNotificationsPlugin {
  int initializeCalls = 0;
  int permissionCalls = 0;

  @override
  Future<bool?> initialize({
    required DarwinInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls++;
    return false;
  }

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionCalls++;
    return alert && sound;
  }
}
