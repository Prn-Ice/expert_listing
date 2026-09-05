import 'package:equatable/equatable.dart';

/// User and lifecycle actions for activity notifications.
sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads activity when the destination first becomes visible.
final class NotificationsStarted extends NotificationsEvent {
  /// Creates the initial-load event.
  const NotificationsStarted();
}

/// Refreshes activity while retaining visible rows.
final class NotificationsRefreshed extends NotificationsEvent {
  /// Creates the refresh event.
  const NotificationsRefreshed();
}

/// Retries a failed initial load or refresh.
final class NotificationsRetryRequested extends NotificationsEvent {
  /// Creates the retry event.
  const NotificationsRetryRequested();
}

/// Marks one durable activity event as read.
final class NotificationReadRequested extends NotificationsEvent {
  /// Creates a read request for [notificationId].
  const NotificationReadRequested(this.notificationId);

  /// The event selected by the current actor.
  final int notificationId;

  @override
  List<Object?> get props => [notificationId];
}
