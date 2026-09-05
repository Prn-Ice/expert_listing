// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';

/// The user-relevant category of a failed autocomplete request.
enum SearchFailureKind {
  /// The device could not reach the service.
  connection,

  /// The request exceeded a transport deadline.
  timeout,

  /// The property-search service returned a server failure.
  service,

  /// The response was rejected or could not be parsed safely.
  invalidResponse,
}

/// A safe autocomplete failure without transport or server details.
final class SearchFailure implements Exception {
  /// Creates a classified search failure.
  const SearchFailure(this.kind);

  /// The category rendered by the search destination.
  final SearchFailureKind kind;
}

/// Loads bounded property and location suggestions from Hono.
class SearchRepository {
  /// Creates the search boundary.
  const SearchRepository({required Dio client}) : _client = client;

  final Dio _client;

  /// Returns suggestions for one trimmed query.
  Future<List<SearchSuggestion>> suggestions(String query) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/search/suggestions',
        queryParameters: {'q': query, 'limit': 6},
      );
      final data = response.data;
      final rawSuggestions = data?['suggestions'];
      if (rawSuggestions is! List) {
        throw const FormatException('Search response has invalid suggestions.');
      }

      return rawSuggestions
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Search suggestion is invalid.');
            }
            return SearchSuggestion.fromJson(raw);
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw SearchFailure(_failureKind(error));
    } on FormatException {
      throw const SearchFailure(SearchFailureKind.invalidResponse);
    }
  }

  SearchFailureKind _failureKind(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => SearchFailureKind.connection,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.transformTimeout => SearchFailureKind.timeout,
      DioExceptionType.badResponse
          when (error.response?.statusCode ?? 0) >= 500 =>
        SearchFailureKind.service,
      DioExceptionType.badResponse ||
      DioExceptionType.cancel ||
      DioExceptionType.unknown => SearchFailureKind.invalidResponse,
    };
  }
}
