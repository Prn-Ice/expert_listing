// Search events are direct user and lifecycle actions.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => const [];
}

sealed class RecentSearchEvent extends SearchEvent {
  const RecentSearchEvent();
}

final class SearchStarted extends RecentSearchEvent {
  const SearchStarted();
}

final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SearchSuggestionsRequested extends SearchEvent {
  const SearchSuggestionsRequested(this.query, this.generation);

  final String query;
  final int generation;

  @override
  List<Object?> get props => [query, generation];
}

final class SearchRetried extends SearchEvent {
  const SearchRetried();
}

final class SearchSaved extends RecentSearchEvent {
  const SearchSaved(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class RecentSearchRemoved extends RecentSearchEvent {
  const RecentSearchRemoved(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class RecentSearchesCleared extends RecentSearchEvent {
  const RecentSearchesCleared();
}
