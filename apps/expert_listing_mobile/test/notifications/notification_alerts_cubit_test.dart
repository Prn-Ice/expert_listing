import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/bloc/notification_alerts_cubit.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notification_alert_cursor_store.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationAlertsCubit', () {
    test('baselines silently then alerts each new unread event once', () async {
      final repository = _NotificationsRepository([
        [_notification(1)],
        [
          _notification(4),
          _notification(3, read: true),
          _notification(2),
          _notification(1),
        ],
        [
          _notification(4),
          _notification(3, read: true),
          _notification(2),
          _notification(1),
        ],
      ]);
      final service = _AlertService();
      final store = _CursorStore();
      final cubit = NotificationAlertsCubit(
        repository: repository,
        alertService: service,
        cursorStore: store,
        actorKey: 'prince',
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      await cubit.resume();
      expect(service.shown, isEmpty);
      expect(store.values['prince'], 1);

      await cubit.checkNow();
      expect(service.shown.map((item) => item.id), [2, 4]);
      expect(store.values['prince'], 4);

      await cubit.checkNow();
      expect(service.shown.map((item) => item.id), [2, 4]);
    });

    test('an empty first load still allows the next event to alert', () async {
      final repository = _NotificationsRepository([
        <ActivityNotification>[],
        [_notification(4)],
      ]);
      final service = _AlertService();
      final store = _CursorStore();
      final cubit = NotificationAlertsCubit(
        repository: repository,
        alertService: service,
        cursorStore: store,
        actorKey: 'ayo',
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      await cubit.resume();
      await cubit.checkNow();

      expect(service.shown.map((item) => item.id), [4]);
      expect(store.values['ayo'], 4);
    });

    test('permission denial does not poll or affect app state', () async {
      final repository = _NotificationsRepository(const []);
      final service = _AlertService(permissionGranted: false);
      final cubit = NotificationAlertsCubit(
        repository: repository,
        alertService: service,
        cursorStore: _CursorStore(),
        actorKey: 'default',
      );
      addTearDown(cubit.close);

      await cubit.resume();

      expect(repository.loadCalls, 0);
      expect(cubit.state.status, NotificationAlertsStatus.permissionDenied);
    });

    test('suppresses overlapping checks and a paused response', () async {
      final pendingLoad = Completer<List<ActivityNotification>>();
      final repository = _NotificationsRepository([
        <ActivityNotification>[],
        pendingLoad.future,
      ]);
      final service = _AlertService();
      final cubit = NotificationAlertsCubit(
        repository: repository,
        alertService: service,
        cursorStore: _CursorStore(),
        actorKey: 'bizzaro',
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);
      await cubit.resume();

      final firstCheck = cubit.checkNow();
      final overlappingCheck = cubit.checkNow();
      expect(repository.loadCalls, 2);
      cubit.pause();
      pendingLoad.complete([_notification(5)]);
      await Future.wait([firstCheck, overlappingCheck]);

      expect(service.shown, isEmpty);
      expect(cubit.state.status, NotificationAlertsStatus.idle);
    });

    test('uses independent persisted cursors for each actor', () async {
      final store = _CursorStore(values: {'prince': 8});
      final princeService = _AlertService();
      final ayoService = _AlertService();
      final prince = NotificationAlertsCubit(
        repository: _NotificationsRepository([
          [_notification(9)],
        ]),
        alertService: princeService,
        cursorStore: store,
        actorKey: 'prince',
        pollInterval: const Duration(hours: 1),
      );
      final ayo = NotificationAlertsCubit(
        repository: _NotificationsRepository([
          [_notification(9)],
        ]),
        alertService: ayoService,
        cursorStore: store,
        actorKey: 'ayo',
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(prince.close);
      addTearDown(ayo.close);

      await prince.resume();
      await ayo.resume();

      expect(princeService.shown.map((item) => item.id), [9]);
      expect(ayoService.shown, isEmpty);
      expect(store.values, {'prince': 9, 'ayo': 9});
    });
  });
}

final class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository(
    List<FutureOr<List<ActivityNotification>>> loads,
  ) : _loads = [...loads],
      super(client: Dio());

  final List<FutureOr<List<ActivityNotification>>> _loads;
  int loadCalls = 0;

  @override
  Future<List<ActivityNotification>> load() async {
    loadCalls++;
    final load = _loads.removeAt(0);
    if (load is Future<List<ActivityNotification>>) return load;
    return load;
  }
}

final class _AlertService implements NotificationAlertService {
  _AlertService({this.permissionGranted = true});

  final bool permissionGranted;
  final shown = <ActivityNotification>[];

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> show(ActivityNotification notification) async {
    shown.add(notification);
  }
}

final class _CursorStore implements NotificationAlertCursorStore {
  _CursorStore({Map<String, int>? values}) : values = values ?? {};

  final Map<String, int> values;

  @override
  Future<int?> load(String actorKey) async => values[actorKey];

  @override
  Future<void> save(String actorKey, int notificationId) async {
    values[actorKey] = notificationId;
  }
}

ActivityNotification _notification(int id, {bool read = false}) {
  final createdAt = DateTime.utc(2026, 9, 5, 12, id);
  return ActivityNotification(
    id: id,
    createdAt: createdAt,
    readAt: read ? createdAt : null,
    actor: const ActivityActor(
      handle: 'bizzaro',
      displayName: 'Bizzaro Cole',
      role: 'Homeowner',
      avatarUrl: null,
    ),
    post: const ActivityPost(id: 1006, body: 'A useful property update.'),
  );
}
