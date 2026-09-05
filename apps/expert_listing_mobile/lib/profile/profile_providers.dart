import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/profile/bloc/profile_cubit.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:riverbloc/riverbloc.dart';

/// The Hono current-user Profile boundary.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(client: ref.watch(httpClientProvider));
});

/// The current request-scoped Profile behavior lifecycle.
final profileCubitProvider = BlocProvider<ProfileCubit, ProfileState>((ref) {
  return ProfileCubit(repository: ref.watch(profileRepositoryProvider));
});
