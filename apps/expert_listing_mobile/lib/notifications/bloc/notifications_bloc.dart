// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:expert_listing/notifications/bloc/notifications_event.dart';
import 'package:expert_listing/notifications/bloc/notifications_state.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';

export 'notifications_event.dart';
export 'notifications_state.dart';

/// Coordinates loading, refresh, and read state for activity notifications.
final class NotificationsBloc
    extends Bloc<NotificationsEvent, NotificationsState> {
  /// Creates the actor-scoped notification state machine.
  NotificationsBloc({required NotificationsRepository repository})
    : _repository = repository,
      super(NotificationsState.initial) {
    on<NotificationsStarted>((_, emit) => _load(emit));
    on<NotificationsRefreshed>((_, emit) => _load(emit, keepVisible: true));
    on<NotificationsRetryRequested>(
      (_, emit) => _load(emit, keepVisible: state.notifications.isNotEmpty),
    );
    on<NotificationReadRequested>(_markRead);
  }

  final NotificationsRepository _repository;
  var _generation = 0;

  Future<void> _load(
    Emitter<NotificationsState> emit, {
    bool keepVisible = false,
  }) async {
    if (state.isInitialLoading || state.isRefreshing) return;
    final generation = ++_generation;
    final hasVisibleNotifications =
        keepVisible && state.notifications.isNotEmpty;
    emit(
      state.copyWith(
        notifications: hasVisibleNotifications ? state.notifications : const [],
        isInitialLoading: !hasVisibleNotifications,
        isRefreshing: hasVisibleNotifications,
        clearFailure: true,
        refreshFailed: false,
        clearNotice: true,
      ),
    );

    try {
      final notifications = await _repository.load();
      if (generation != _generation) return;
      final readAtById = <int, DateTime>{};
      for (final notification in state.notifications) {
        final readAt = notification.readAt;
        if (readAt != null) {
          readAtById[notification.id] = readAt;
        }
      }
      final mergedNotifications = notifications
          .map((notification) {
            final readAt = readAtById[notification.id];
            if (notification.readAt == null && readAt != null) {
              return notification.markRead(readAt);
            }
            return notification;
          })
          .toList(growable: false);
      emit(
        state.copyWith(
          notifications: mergedNotifications,
          hasLoaded: true,
          isInitialLoading: false,
          isRefreshing: false,
          clearFailure: true,
          refreshFailed: false,
        ),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      emit(
        state.copyWith(
          hasLoaded: true,
          isInitialLoading: false,
          isRefreshing: false,
          failure: hasVisibleNotifications
              ? null
              : error is NotificationsFailure
              ? error.kind
              : NotificationsFailureKind.invalidResponse,
          clearFailure: hasVisibleNotifications,
          refreshFailed: hasVisibleNotifications,
        ),
      );
    }
  }

  Future<void> _markRead(
    NotificationReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final index = state.notifications.indexWhere(
      (notification) => notification.id == event.notificationId,
    );
    if (index < 0 ||
        state.notifications[index].isRead ||
        state.readingIds.contains(event.notificationId)) {
      return;
    }

    emit(
      state.copyWith(
        readingIds: {...state.readingIds, event.notificationId},
        clearNotice: true,
      ),
    );
    try {
      final readAt = await _repository.markRead(event.notificationId);
      final notifications = [...state.notifications];
      final currentIndex = notifications.indexWhere(
        (notification) => notification.id == event.notificationId,
      );
      if (currentIndex >= 0) {
        notifications[currentIndex] = notifications[currentIndex].markRead(
          readAt,
        );
      }
      emit(
        state.copyWith(
          notifications: notifications,
          readingIds: {...state.readingIds}..remove(event.notificationId),
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          readingIds: {...state.readingIds}..remove(event.notificationId),
          noticeSequence: state.noticeSequence + 1,
          notice: "Couldn't mark that notification as read. Try again.",
        ),
      );
    }
  }
}
