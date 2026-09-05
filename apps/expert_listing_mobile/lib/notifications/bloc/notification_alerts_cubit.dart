// Private dependencies retain product-language argument names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:expert_listing/notifications/notification_alert_cursor_store.dart';
import 'package:expert_listing/notifications/notification_alert_service.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';

/// Whether the foreground activity monitor can currently deliver alerts.
enum NotificationAlertsStatus {
  /// The app is not currently polling.
  idle,

  /// Permission is granted and foreground polling is active.
  monitoring,

  /// Native notification permission is unavailable or denied.
  permissionDenied,
}

/// Observable foreground-alert state without exposing notification contents.
final class NotificationAlertsState extends Equatable {
  /// Creates foreground-alert state.
  const NotificationAlertsState({this.status = NotificationAlertsStatus.idle});

  /// Current monitor availability.
  final NotificationAlertsStatus status;

  @override
  List<Object> get props => [status];
}

/// Polls bounded activity while resumed and emits each new unread alert once.
final class NotificationAlertsCubit extends Cubit<NotificationAlertsState> {
  /// Creates the actor-scoped foreground activity monitor.
  NotificationAlertsCubit({
    required NotificationsRepository repository,
    required NotificationAlertService alertService,
    required NotificationAlertCursorStore cursorStore,
    required String actorKey,
    this.pollInterval = const Duration(seconds: 30),
  }) : _repository = repository,
       _alertService = alertService,
       _cursorStore = cursorStore,
       _actorKey = actorKey,
       super(const NotificationAlertsState());

  final NotificationsRepository _repository;
  final NotificationAlertService _alertService;
  final NotificationAlertCursorStore _cursorStore;
  final String _actorKey;

  /// Maximum delay before new activity is checked again while resumed.
  final Duration pollInterval;

  Timer? _timer;
  int? _lastSeenId;
  var _cursorLoaded = false;
  var _isChecking = false;
  var _isResumed = false;
  var _generation = 0;

  /// Starts or resumes permission-aware polling.
  Future<void> resume() async {
    if (_isResumed || isClosed) return;
    _isResumed = true;
    final generation = ++_generation;
    final permissionGranted = await _alertService.requestPermission();
    if (!_isCurrent(generation)) return;
    if (!permissionGranted) {
      emit(
        const NotificationAlertsState(
          status: NotificationAlertsStatus.permissionDenied,
        ),
      );
      return;
    }

    emit(
      const NotificationAlertsState(
        status: NotificationAlertsStatus.monitoring,
      ),
    );
    await checkNow();
    if (!_isCurrent(generation)) return;
    _timer = Timer.periodic(pollInterval, (_) => unawaited(checkNow()));
  }

  /// Stops polling without discarding this actor's persisted cursor.
  void pause() {
    if (!_isResumed) return;
    _isResumed = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (!isClosed) emit(const NotificationAlertsState());
  }

  /// Performs one overlap-safe foreground check.
  Future<void> checkNow() async {
    if (!_isResumed || _isChecking || isClosed) return;
    _isChecking = true;
    final generation = _generation;
    try {
      if (!_cursorLoaded) {
        _lastSeenId = await _cursorStore.load(_actorKey);
        _cursorLoaded = true;
      }
      final notifications = await _repository.load();
      if (!_isCurrent(generation)) return;
      final highestId = notifications.fold<int>(
        0,
        (highest, notification) =>
            notification.id > highest ? notification.id : highest,
      );
      final previousId = _lastSeenId;
      if (previousId == null || highestId < previousId) {
        await _saveCursor(highestId);
        return;
      }

      final newUnread =
          notifications
              .where(
                (notification) =>
                    notification.id > previousId && !notification.isRead,
              )
              .toList()
            ..sort((left, right) => left.id.compareTo(right.id));
      for (final notification in newUnread) {
        if (!_isCurrent(generation)) return;
        try {
          await _alertService.show(notification);
        } finally {
          // Once native delivery was attempted, never replay this event.
          await _saveCursor(notification.id);
        }
      }
      if (_isCurrent(generation) && highestId > (_lastSeenId ?? previousId)) {
        await _saveCursor(highestId);
      }
    } on Object {
      // Polling is best effort; a later interval retries without disturbing UI.
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _saveCursor(int notificationId) async {
    _lastSeenId = notificationId;
    await _cursorStore.save(_actorKey, notificationId);
  }

  bool _isCurrent(int generation) =>
      !isClosed && _isResumed && generation == _generation;

  @override
  Future<void> close() {
    _isResumed = false;
    _generation++;
    _timer?.cancel();
    return super.close();
  }
}
