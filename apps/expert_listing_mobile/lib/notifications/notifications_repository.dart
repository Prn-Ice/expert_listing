// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';

/// The user-relevant category of a failed notification request.
enum NotificationsFailureKind {
  /// The device could not reach the service.
  connection,

  /// The request exceeded a transport deadline.
  timeout,

  /// The notification service returned a server failure.
  service,

  /// The response was rejected or could not be parsed safely.
  invalidResponse,
}

/// A safe notification failure without transport or server details.
final class NotificationsFailure implements Exception {
  /// Creates a classified notification failure.
  const NotificationsFailure(this.kind);

  /// The category rendered by the notification destination.
  final NotificationsFailureKind kind;
}

/// Loads and updates activity addressed to the request-scoped actor.
class NotificationsRepository {
  /// Creates the notification API boundary.
  const NotificationsRepository({required Dio client}) : _client = client;

  final Dio _client;

  /// Loads the latest bounded activity in deterministic server order.
  Future<List<ActivityNotification>> load() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/notifications',
      );
      final rawNotifications = response.data?['notifications'];
      if (rawNotifications is! List) {
        throw const FormatException('Notification response is invalid.');
      }
      final notifications = rawNotifications
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Notification item is invalid.');
            }
            return ActivityNotification.fromJson(item);
          })
          .toList(growable: false);
      if (notifications.map((item) => item.id).toSet().length !=
          notifications.length) {
        throw const FormatException('Notification IDs are duplicated.');
      }
      return notifications;
    } on DioException catch (error) {
      throw NotificationsFailure(_failureKind(error));
    } on FormatException {
      throw const NotificationsFailure(
        NotificationsFailureKind.invalidResponse,
      );
    }
  }

  /// Marks one current-actor notification read.
  ///
  /// Returns the server's stable first-read timestamp.
  Future<DateTime> markRead(int notificationId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/notifications/$notificationId/read',
      );
      final data = response.data;
      final id = data?['id'];
      final rawReadAt = data?['readAt'];
      final readAt = rawReadAt is String
          ? DateTime.tryParse(rawReadAt)?.toUtc()
          : null;
      if (id != notificationId || readAt == null) {
        throw const FormatException('Notification read response is invalid.');
      }
      return readAt;
    } on DioException catch (error) {
      throw NotificationsFailure(_failureKind(error));
    } on FormatException {
      throw const NotificationsFailure(
        NotificationsFailureKind.invalidResponse,
      );
    }
  }

  NotificationsFailureKind _failureKind(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => NotificationsFailureKind.connection,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.transformTimeout => NotificationsFailureKind.timeout,
      DioExceptionType.badResponse
          when (error.response?.statusCode ?? 0) >= 500 =>
        NotificationsFailureKind.service,
      DioExceptionType.badResponse ||
      DioExceptionType.cancel ||
      DioExceptionType.unknown => NotificationsFailureKind.invalidResponse,
    };
  }
}
