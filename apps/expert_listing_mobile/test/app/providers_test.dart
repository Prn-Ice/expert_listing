import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppConfig testConfig() => AppConfig.parse(
    'http://127.0.0.1:56321/functions/v1/api',
    isRelease: false,
  );

  group('appConfigProvider', () {
    test('requires the startup override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(appConfigProvider),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('httpClientProvider', () {
    test('returns one client per container and closes it once on dispose', () {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
      );

      final first = container.read(httpClientProvider);
      final second = container.read(httpClientProvider);
      expect(identical(first, second), isTrue);
      expect(first.options.baseUrl, testConfig().apiBaseUri.toString());

      container.dispose();

      // The closed client rejects further requests.
      expect(
        () => first.get<Map<String, dynamic>>('/health'),
        throwsA(
          isA<DioException>().having(
            (error) => error.message,
            'message',
            contains('closed'),
          ),
        ),
      );

      // A fresh container builds a fresh client rather than reviving the old.
      final secondContainer = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
      );
      addTearDown(secondContainer.dispose);
      final third = secondContainer.read(httpClientProvider);
      expect(identical(first, third), isFalse);
    });
  });
}
