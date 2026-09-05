import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/notifications/bloc/notification_alerts_cubit.dart';
import 'package:expert_listing/notifications/bloc/notifications_bloc.dart';
import 'package:expert_listing/notifications/notification_alert_cursor_store.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:riverbloc/riverbloc.dart';

/// The Hono activity-notification boundary.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(client: ref.watch(httpClientProvider));
});

/// The process-owned native foreground-alert boundary.
final notificationAlertServiceProvider = Provider<NotificationAlertService>((
  _,
) {
  return LocalNotificationAlertService();
});

/// Device-only, actor-scoped alert cursor persistence.
final notificationAlertCursorStoreProvider =
    Provider<NotificationAlertCursorStore>((_) {
      return SharedPreferencesNotificationAlertCursorStore();
    });

/// Foreground activity polling cadence.
final notificationAlertPollIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 30),
);

/// Foreground polling lifecycle recreated for each selected preview persona.
final notificationAlertsCubitProvider =
    BlocProvider<NotificationAlertsCubit, NotificationAlertsState>((ref) {
      final actor = ref.watch(previewActorProvider);
      return NotificationAlertsCubit(
        repository: ref.watch(notificationsRepositoryProvider),
        alertService: ref.watch(notificationAlertServiceProvider),
        cursorStore: ref.watch(notificationAlertCursorStoreProvider),
        actorKey: actor ?? 'default',
        pollInterval: ref.watch(notificationAlertPollIntervalProvider),
      );
    });

/// The request-scoped notification behavior lifecycle.
final notificationsBlocProvider =
    BlocProvider<NotificationsBloc, NotificationsState>((ref) {
      return NotificationsBloc(
        repository: ref.watch(notificationsRepositoryProvider),
      );
    });
