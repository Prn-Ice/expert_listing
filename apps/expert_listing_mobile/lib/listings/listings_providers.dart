import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/listings/bloc/listings_bloc.dart';
import 'package:expert_listing/listings/bloc/listings_state.dart';
import 'package:riverbloc/riverbloc.dart';

/// The independently owned property-catalog behavior lifecycle.
final listingsBlocProvider = BlocProvider<ListingsBloc, ListingsState>((ref) {
  return ListingsBloc(repository: ref.watch(feedRepositoryProvider));
});
