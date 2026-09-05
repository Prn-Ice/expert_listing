import 'package:dio/dio.dart';
import 'package:expert_listing/profile/bloc/profile_cubit.dart';
import 'package:expert_listing/profile/models/profile.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads a profile and retries after a safe failure', () async {
    var attempts = 0;
    final repository = _ProfileRepository(() {
      attempts++;
      if (attempts == 1) {
        throw const ProfileFailure(ProfileFailureKind.connection);
      }
      return Future.value(_result);
    });
    final cubit = ProfileCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.failure?.kind, ProfileFailureKind.connection);
    expect(cubit.state.isLoading, isFalse);

    await cubit.load();
    expect(cubit.state.profile, _result.profile);
    expect(cubit.state.previewActors, ['prince', 'ayo']);
    expect(cubit.state.failure, isNull);
    expect(attempts, 2);
  });
}

final class _ProfileRepository extends ProfileRepository {
  _ProfileRepository(this._load) : super(client: Dio());

  final Future<ProfileResult> Function() _load;

  @override
  Future<ProfileResult> load() => _load();
}

const _result = ProfileResult(
  profile: Profile(
    handle: 'prince',
    displayName: 'Prince Adeyemi',
    role: 'Realtor',
    avatarUrl: null,
  ),
  previewActors: ['prince', 'ayo'],
);
