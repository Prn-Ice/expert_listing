// Private dependencies retain product-language argument names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';

import 'package:expert_listing/feed/data/feed_cache.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';

/// Reconciles Hono's paginated feed with the explicit saved-read boundary.
class FeedRepository {
  /// Creates the concrete feed repository.
  FeedRepository({
    required Dio client,
    FeedCache? feedCache,
    String? cacheNamespace,
  }) : _client = client,
       _feedCache = feedCache,
       _cacheNamespace = cacheNamespace;

  final Dio _client;
  final FeedCache? _feedCache;
  final String? _cacheNamespace;

  /// One entry per full feed URI holding the latest active request token, so
  /// a superseded response cannot reach the cache. Tokens retire with their
  /// request, keeping the map bounded to work that is actually running.
  final _activeRequests = <Uri, int>{};
  var _nextRequestToken = 0;

  /// Loads one page network-first, consulting disk only for approved failures.
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) async {
    final uri = _feedUri(filter: filter, cursor: cursor, limit: limit);
    final cacheUri = _cacheUri(uri);
    final requestToken = ++_nextRequestToken;
    _activeRequests[uri] = requestToken;

    try {
      final response = await _client.getUri<Map<String, dynamic>>(uri);
      final data = response.data;
      if (data == null) {
        throw const FeedLoadFailure(FeedFailureKind.unavailable);
      }
      final page = _parseLivePage(data);
      // A superseded response for this URI must never reach the cache; the
      // newest accepted response for one full URI is the final saved value.
      if (_activeRequests[uri] == requestToken) {
        await _feedCache?.write(cacheUri, data);
      }
      return page;
    } on DioException catch (error) {
      final fallbackReason = _fallbackReasonFor(error);
      if (fallbackReason == null) {
        throw const FeedLoadFailure(FeedFailureKind.unavailable);
      }

      final saved = await _readSavedEntry(cacheUri);
      if (saved == null) {
        throw FeedLoadFailure(
          fallbackReason == FeedFallbackReason.connection
              ? FeedFailureKind.connection
              : FeedFailureKind.service,
        );
      }

      try {
        return FeedLoadResult.fromJson(
          saved.data,
          source: FeedDataSource.saved,
          savedAt: saved.savedAt,
          fallbackReason: fallbackReason,
        );
      } on Object {
        throw FeedLoadFailure(
          fallbackReason == FeedFallbackReason.connection
              ? FeedFailureKind.connection
              : FeedFailureKind.service,
        );
      }
    } on FeedLoadFailure {
      rethrow;
    } on Object {
      throw const FeedLoadFailure(FeedFailureKind.unavailable);
    } finally {
      if (_activeRequests[uri] == requestToken) {
        _activeRequests.remove(uri);
      }
    }
  }

  /// Removes all saved feed pages after a successful mutation.
  Future<void> invalidateFeed() async {
    // Retire the loads that were still running before the wipe so their
    // responses cannot write pre-mutation data into the cleared cache.
    _activeRequests.clear();
    await _feedCache?.clear();
  }

  FeedLoadResult _parseLivePage(Map<String, dynamic> data) {
    try {
      return FeedLoadResult.fromJson(data, source: FeedDataSource.network);
    } on FormatException {
      throw const FeedLoadFailure(FeedFailureKind.unavailable);
    }
  }

  Future<SavedFeedEntry?> _readSavedEntry(Uri uri) async =>
      _feedCache?.read(uri);

  Uri _feedUri({
    required FeedFilter filter,
    required int limit,
    String? cursor,
  }) {
    final base = Uri.parse(_client.options.baseUrl);
    final query = <String, String>{
      'limit': '$limit',
      ...filter.toQueryParameters(),
    };
    if (cursor != null) query['cursor'] = cursor;
    return base.replace(path: '${base.path}/posts', queryParameters: query);
  }

  Uri _cacheUri(Uri requestUri) {
    final namespace = _cacheNamespace;
    return namespace == null
        ? requestUri
        : requestUri.replace(fragment: 'preview-actor=$namespace');
  }

  FeedFallbackReason? _fallbackReasonFor(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return FeedFallbackReason.connection;
      case DioExceptionType.badResponse:
        return switch (error.response?.statusCode) {
          500 || 502 || 503 || 504 => FeedFallbackReason.service,
          _ => null,
        };
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return null;
    }
  }
}
