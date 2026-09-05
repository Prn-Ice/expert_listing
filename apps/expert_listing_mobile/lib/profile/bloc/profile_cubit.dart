// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:expert_listing/profile/models/profile.dart';
import 'package:expert_listing/profile/profile_repository.dart';

part 'profile_state.dart';

/// Coordinates loading and retry for the current-user Profile destination.
final class ProfileCubit extends Cubit<ProfileState> {
  /// Creates the Profile state machine.
  ProfileCubit({required ProfileRepository repository})
    : _repository = repository,
      super(ProfileState.initial);

  final ProfileRepository _repository;

  /// Loads the current request-scoped user unless work is already running.
  Future<void> load() async {
    if (state.isLoading) return;
    emit(const ProfileState(isLoading: true));
    try {
      final result = await _repository.load();
      emit(
        ProfileState(
          profile: result.profile,
          previewActors: result.previewActors,
        ),
      );
    } on Object catch (error) {
      emit(
        ProfileState(
          failure: error is ProfileFailure
              ? error
              : const ProfileFailure(ProfileFailureKind.invalidResponse),
        ),
      );
    }
  }
}
