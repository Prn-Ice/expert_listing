import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/search/bloc/search_bloc.dart';
import 'package:expert_listing/search/bloc/search_state.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_repository.dart';
import 'package:riverbloc/riverbloc.dart';

/// The Hono autocomplete boundary.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(client: ref.watch(httpClientProvider));
});

/// This device's bounded recent-search persistence boundary.
final recentSearchStoreProvider = Provider<RecentSearchStore>((ref) {
  return SharedPreferencesRecentSearchStore();
});

/// The autocomplete and recent-search behavior lifecycle.
final searchBlocProvider = BlocProvider<SearchBloc, SearchState>((ref) {
  return SearchBloc(
    repository: ref.watch(searchRepositoryProvider),
    recentSearchStore: ref.watch(recentSearchStoreProvider),
  );
});
