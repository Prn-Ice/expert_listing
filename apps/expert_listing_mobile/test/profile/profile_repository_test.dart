import 'package:dio/dio.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ProfileRepository, () {
    test('parses profile details and safe aliases', () async {
      final repository = ProfileRepository(
        client: _clientWith({
          'profile': {
            'handle': 'prince',
            'displayName': 'Prince Adeyemi',
            'role': 'Realtor',
            'avatarUrl': 'https://example.test/prince.jpg',
          },
          'previewActors': ['prince', 'ayo'],
        }),
      );

      final result = await repository.load();

      expect(result.profile.displayName, 'Prince Adeyemi');
      expect(result.profile.handle, 'prince');
      expect(result.profile.role, 'Realtor');
      expect(result.previewActors, ['prince', 'ayo']);
    });

    test('rejects malformed and UUID preview values', () async {
      for (final actor in [
        'AYO',
        ' ayo ',
        '00000000-0000-0000-0000-000000000002',
      ]) {
        final repository = ProfileRepository(
          client: _clientWith({
            'profile': {
              'handle': 'prince',
              'displayName': 'Prince Adeyemi',
              'role': 'Realtor',
              'avatarUrl': null,
            },
            'previewActors': [actor],
          }),
        );

        await expectLater(
          repository.load(),
          throwsA(
            isA<ProfileFailure>().having(
              (failure) => failure.kind,
              'kind',
              ProfileFailureKind.invalidResponse,
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
        ProfileRepository(client: client).load(),
        throwsA(
          isA<ProfileFailure>().having(
            (failure) => failure.kind,
            'kind',
            ProfileFailureKind.timeout,
          ),
        ),
      );
    });
  });
}

Dio _clientWith(Map<String, dynamic> body) {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test'));
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: body,
          statusCode: 200,
        ),
      ),
    ),
  );
  return client;
}
