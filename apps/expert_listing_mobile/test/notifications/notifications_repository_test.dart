import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NotificationsRepository, () {
    test('parses activity and a stable read timestamp', () async {
      final repository = NotificationsRepository(
        client: _clientWith((options) {
          if (options.path == '/notifications') {
            return {
              'notifications': [_notificationJson()],
            };
          }
          return {
            'id': 6004,
            'readAt': '2026-09-05T12:05:00.000Z',
          };
        }),
      );

      final notifications = await repository.load();
      final readAt = await repository.markRead(6004);

      expect(notifications.single.id, 6004);
      expect(notifications.single.actor.handle, 'ayo');
      expect(notifications.single.post.id, 1006);
      expect(notifications.single.isRead, isFalse);
      expect(readAt, DateTime.utc(2026, 9, 5, 12, 5));
    });

    test('rejects unsupported activity and duplicate IDs', () async {
      for (final notifications in [
        [
          {..._notificationJson(), 'type': 'comment'},
        ],
        [_notificationJson(), _notificationJson()],
      ]) {
        final repository = NotificationsRepository(
          client: _clientWith((_) => {'notifications': notifications}),
        );

        await expectLater(
          repository.load(),
          throwsA(
            isA<NotificationsFailure>().having(
              (failure) => failure.kind,
              'kind',
              NotificationsFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });

    test('classifies a transport timeout', () async {
      final client = Dio();
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            ),
          ),
        ),
      );

      await expectLater(
        NotificationsRepository(client: client).load(),
        throwsA(
          isA<NotificationsFailure>().having(
            (failure) => failure.kind,
            'kind',
            NotificationsFailureKind.timeout,
          ),
        ),
      );
    });
  });
}

Dio _clientWith(Map<String, dynamic> Function(RequestOptions) responseBody) {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: responseBody(options),
          statusCode: 200,
        ),
      ),
    ),
  );
  return client;
}

Map<String, dynamic> _notificationJson() => {
  'id': 6004,
  'type': 'postLike',
  'createdAt': '2026-09-05T12:00:00.000Z',
  'readAt': null,
  'actor': const {
    'handle': 'ayo',
    'displayName': 'Ayo Balogun',
    'role': 'Property Consultant',
    'avatarUrl': null,
  },
  'post': const {'id': 1006, 'body': 'A useful property update.'},
};
