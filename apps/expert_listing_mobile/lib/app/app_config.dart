import 'package:flutter/foundation.dart';

/// Validated public configuration supplied when the application is built.
final class AppConfig {
  const AppConfig._(this.apiBaseUri);

  /// Reads the API base URL supplied through the Flutter build environment.
  factory AppConfig.fromEnvironment({bool isRelease = kReleaseMode}) {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    return AppConfig.parse(apiBaseUrl, isRelease: isRelease);
  }

  /// Validates a supplied API base URL for the current build mode.
  factory AppConfig.parse(String value, {required bool isRelease}) {
    final apiBaseUrl = value.trim();
    if (apiBaseUrl.isEmpty) {
      throw const AppConfigException('API_BASE_URL is required.');
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const AppConfigException('API_BASE_URL must be a valid HTTP URL.');
    }

    if (isRelease && uri.scheme != 'https') {
      throw const AppConfigException(
        'Release builds require an HTTPS API_BASE_URL.',
      );
    }

    return AppConfig._(uri);
  }

  /// The complete Hono API base URL used for application requests.
  final Uri apiBaseUri;
}

/// Indicates that a required public application setting is invalid or absent.
final class AppConfigException implements Exception {
  /// Creates a configuration error with a safe, user-actionable message.
  const AppConfigException(this.message);

  /// The safe explanation of the invalid configuration.
  final String message;

  /// Returns the safe configuration explanation.
  @override
  String toString() => message;
}
