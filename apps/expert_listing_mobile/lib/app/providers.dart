import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The validated application configuration, supplied once at startup.
///
/// `main` overrides this with the build environment's value; a missing or
/// invalid value never reaches the tree because startup shows the
/// configuration error surface instead.
final appConfigProvider = Provider<AppConfig>(
  (_) => throw StateError('AppConfig must be overridden at startup.'),
);

/// The shared HTTP client for the Hono API.
///
/// Riverpod owns the lifecycle: one instance per container, closed exactly
/// once when the container disposes.
final httpClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(baseUrl: config.apiBaseUri.toString()));
  ref.onDispose(dio.close);
  return dio;
});
