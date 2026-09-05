part of 'profile_cubit.dart';

/// Renderable state for the current-user Profile destination.
final class ProfileState extends Equatable {
  /// Creates a Profile state.
  const ProfileState({
    this.profile,
    this.previewActors = const [],
    this.isLoading = false,
    this.failure,
  });

  /// The initial untouched Profile state.
  static const initial = ProfileState();

  /// Loaded public profile details.
  final Profile? profile;

  /// Safe aliases advertised only by an enabled local backend.
  final List<String> previewActors;

  /// Whether Profile is currently loading.
  final bool isLoading;

  /// A safe load failure.
  final ProfileFailure? failure;

  @override
  List<Object?> get props => [profile, previewActors, isLoading, failure];
}
