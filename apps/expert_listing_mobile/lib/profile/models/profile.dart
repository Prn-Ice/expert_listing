import 'package:equatable/equatable.dart';

/// The server-resolved current user's public profile.
final class Profile extends Equatable {
  /// Creates a current-user profile.
  const Profile({
    required this.handle,
    required this.displayName,
    required this.role,
    required this.avatarUrl,
  });

  /// Parses the strict profile response object.
  factory Profile.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final displayName = json['displayName'];
    final role = json['role'];
    final avatarUrl = json['avatarUrl'];
    if (handle is! String ||
        handle.isEmpty ||
        displayName is! String ||
        displayName.isEmpty ||
        role is! String ||
        role.isEmpty ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const FormatException('Profile response is invalid.');
    }
    return Profile(
      handle: handle,
      displayName: displayName,
      role: role,
      avatarUrl: avatarUrl as String?,
    );
  }

  /// Public handle without the visual `@` prefix.
  final String handle;

  /// Human-readable name.
  final String displayName;

  /// Professional role.
  final String role;

  /// Optional public media URL.
  final String? avatarUrl;

  @override
  List<Object?> get props => [handle, displayName, role, avatarUrl];
}

/// A loaded profile and the aliases advertised by a local debug backend.
final class ProfileResult extends Equatable {
  /// Creates one profile response.
  const ProfileResult({required this.profile, required this.previewActors});

  /// The server-resolved current user.
  final Profile profile;

  /// Safe aliases, empty when preview switching is unavailable.
  final List<String> previewActors;

  @override
  List<Object?> get props => [profile, previewActors];
}
