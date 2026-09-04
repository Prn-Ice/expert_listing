import 'package:expert_listing/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.parse', () {
    test('rejects a missing API base URL', () {
      expect(
        () => AppConfig.parse('', isRelease: false),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects malformed API base URLs', () {
      expect(
        () => AppConfig.parse('not a URL', isRelease: false),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('allows a local HTTP API during debug development', () {
      final config = AppConfig.parse(
        'http://127.0.0.1:54321/functions/v1/api',
        isRelease: false,
      );

      expect(config.apiBaseUri.host, '127.0.0.1');
    });

    test('requires HTTPS in release builds', () {
      expect(
        () => AppConfig.parse(
          'http://127.0.0.1:54321/functions/v1/api',
          isRelease: true,
        ),
        throwsA(isA<AppConfigException>()),
      );

      final config = AppConfig.parse(
        'https://project.supabase.co/functions/v1/api',
        isRelease: true,
      );

      expect(config.apiBaseUri.scheme, 'https');
    });

    test('requires the Hono API path in every build', () {
      expect(
        () => AppConfig.parse('https://project.supabase.co', isRelease: false),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('accepts any valid HTTPS host in release builds', () {
      final config = AppConfig.parse(
        'https://api.example.com/functions/v1/api',
        isRelease: true,
      );

      expect(config.apiBaseUri.host, 'api.example.com');
    });
  });
}
