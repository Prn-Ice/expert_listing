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
    });

    test('requires the Hono API path in every build', () {
      expect(
        () => AppConfig.parse('https://project.supabase.co', isRelease: false),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('accepts the hosted API host in release builds', () {
      final config = AppConfig.parse(
        'https://${AppConfig.hostedApiHost}/functions/v1/api',
        isRelease: true,
      );

      expect(config.apiBaseUri.host, AppConfig.hostedApiHost);
    });

    test(
      'accepts the hosted API host case-insensitively in release builds',
      () {
        final upperHost = AppConfig.hostedApiHost.toUpperCase();
        final config = AppConfig.parse(
          'https://$upperHost/functions/v1/api',
          isRelease: true,
        );

        expect(config.apiBaseUri.host, AppConfig.hostedApiHost);
      },
    );

    test('rejects loopback and local hosts in release builds', () {
      for (final host in [
        '127.0.0.1',
        'localhost',
        '0.0.0.0',
        '[::1]',
        '10.0.0.1',
        '192.168.1.1',
      ]) {
        expect(
          () => AppConfig.parse(
            'https://$host/functions/v1/api',
            isRelease: true,
          ),
          throwsA(isA<AppConfigException>()),
          reason: 'release must reject $host',
        );
      }
    });

    test('rejects reserved and example hosts in release builds', () {
      for (final host in [
        'api.example.com',
        'example.test',
        'project.supabase.co',
        'metadata.google.internal',
      ]) {
        expect(
          () => AppConfig.parse(
            'https://$host/functions/v1/api',
            isRelease: true,
          ),
          throwsA(isA<AppConfigException>()),
          reason: 'release must reject $host',
        );
      }
    });

    test('rejects lookalike hosted hosts in release builds', () {
      for (final host in [
        '${AppConfig.hostedApiHost}.evil.com',
        'evil-${AppConfig.hostedApiHost}',
        '${AppConfig.hostedApiHost.replaceAll('.supabase', '')}.evil.com',
      ]) {
        expect(
          () => AppConfig.parse(
            'https://$host/functions/v1/api',
            isRelease: true,
          ),
          throwsA(isA<AppConfigException>()),
          reason: 'release must reject $host',
        );
      }
    });

    test('still allows a local HTTP API during debug development', () {
      final config = AppConfig.parse(
        'http://127.0.0.1:54321/functions/v1/api',
        isRelease: false,
      );

      expect(config.apiBaseUri.host, '127.0.0.1');
    });
  });
}
