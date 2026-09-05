// State fields correspond directly to visible search conditions.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';
import 'package:expert_listing/search/search_repository.dart';

final class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.recentSearches = const [],
    this.suggestions = const [],
    this.isLoading = false,
    this.failure,
  });

  static const initial = SearchState();

  final String query;
  final List<String> recentSearches;
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final SearchFailureKind? failure;

  SearchState copyWith({
    String? query,
    List<String>? recentSearches,
    List<SearchSuggestion>? suggestions,
    bool? isLoading,
    SearchFailureKind? failure,
    bool clearFailure = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    query,
    recentSearches,
    suggestions,
    isLoading,
    failure,
  ];
}
