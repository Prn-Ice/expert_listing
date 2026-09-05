// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:expert_listing/profile/models/profile.dart';

/// The user-relevant category of a failed profile request.
enum ProfileFailureKind {
  /// The device could not reach the service.
  connection,

  /// The request exceeded a transport deadline.
  timeout,

  /// The Profile service returned a server failure.
  service,

  /// The response was rejected or could not be parsed safely.
  invalidResponse,
}

/// A safe profile failure without transport or server details.
final class ProfileFailure implements Exception {
  /// Creates a classified profile failure.
  const ProfileFailure(this.kind);

  /// The category rendered by the Profile destination.
  final ProfileFailureKind kind;
}

/// Loads the request-scoped current-user profile from Hono.
class ProfileRepository {
  /// Creates the Profile API boundary.
  const ProfileRepository({required Dio client}) : _client = client;

  final Dio _client;

  /// Returns the server-resolved current user and safe preview aliases.
  Future<ProfileResult> load() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/profile');
      final data = response.data;
      final rawProfile = data?['profile'];
      final rawActors = data?['previewActors'];
      if (rawProfile is! Map<String, dynamic> || rawActors is! List) {
        throw const FormatException('Profile response is invalid.');
      }
      final actors = rawActors
          .map((actor) {
            if (actor is! String ||
                !RegExp(r'^[a-z][a-z0-9-]{0,31}$').hasMatch(actor)) {
              throw const FormatException('Preview actor alias is invalid.');
            }
            return actor;
          })
          .toList(growable: false);
      if (actors.toSet().length != actors.length) {
        throw const FormatException('Preview actor aliases are duplicated.');
      }
      return ProfileResult(
        profile: Profile.fromJson(rawProfile),
        previewActors: actors,
      );
    } on DioException catch (error) {
      throw ProfileFailure(_failureKind(error));
    } on FormatException {
      throw const ProfileFailure(ProfileFailureKind.invalidResponse);
    }
  }

  ProfileFailureKind _failureKind(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => ProfileFailureKind.connection,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.transformTimeout => ProfileFailureKind.timeout,
      DioExceptionType.badResponse
          when (error.response?.statusCode ?? 0) >= 500 =>
        ProfileFailureKind.service,
      DioExceptionType.badResponse ||
      DioExceptionType.cancel ||
      DioExceptionType.unknown => ProfileFailureKind.invalidResponse,
    };
  }
}
