// Private dependencies keep product-language names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:expert_listing/search/bloc/search_event.dart';
import 'package:expert_listing/search/bloc/search_state.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_repository.dart';

/// Coordinates debounced autocomplete and recent-search persistence.
final class SearchBloc extends Bloc<SearchEvent, SearchState> {
  /// Creates the search state machine.
  SearchBloc({
    required SearchRepository repository,
    required RecentSearchStore recentSearchStore,
  }) : _repository = repository,
       _recentSearchStore = recentSearchStore,
       super(SearchState.initial) {
    on<RecentSearchEvent>(
      _updateRecentSearches,
      transformer: _sequential(),
    );
    on<SearchQueryChanged>(_changeQuery);
    on<SearchSuggestionsRequested>(_loadSuggestions);
    on<SearchRetried>(_retry);
  }

  static const _debounceDuration = Duration(milliseconds: 280);
  static const _minimumQueryLength = 3;

  final SearchRepository _repository;
  final RecentSearchStore _recentSearchStore;
  Timer? _debounce;
  var _generation = 0;

  Future<void> _updateRecentSearches(
    RecentSearchEvent event,
    Emitter<SearchState> emit,
  ) {
    return switch (event) {
      SearchStarted() => _start(event, emit),
      SearchSaved() => _saveSearch(event, emit),
      RecentSearchRemoved() => _removeRecentSearch(event, emit),
      RecentSearchesCleared() => _clearRecentSearches(event, emit),
    };
  }

  Future<void> _start(SearchStarted event, Emitter<SearchState> emit) async {
    try {
      emit(state.copyWith(recentSearches: await _recentSearchStore.load()));
    } on Object {
      // Search remains usable when optional local history is unavailable.
    }
  }

  void _changeQuery(SearchQueryChanged event, Emitter<SearchState> emit) {
    _debounce?.cancel();
    final query = event.query.trimLeft();
    final generation = ++_generation;
    if (query.trim().length < _minimumQueryLength) {
      emit(
        state.copyWith(
          query: query,
          suggestions: const [],
          isLoading: false,
          clearFailure: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: query,
        suggestions: const [],
        isLoading: true,
        clearFailure: true,
      ),
    );
    _debounce = Timer(
      _debounceDuration,
      () => add(SearchSuggestionsRequested(query.trim(), generation)),
    );
  }

  Future<void> _loadSuggestions(
    SearchSuggestionsRequested event,
    Emitter<SearchState> emit,
  ) async {
    if (event.generation != _generation) return;
    try {
      final suggestions = await _repository.suggestions(event.query);
      if (event.generation != _generation) return;
      emit(
        state.copyWith(
          suggestions: suggestions,
          isLoading: false,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      if (event.generation != _generation) return;
      emit(
        state.copyWith(
          suggestions: const [],
          isLoading: false,
          failure: error is SearchFailure
              ? error.kind
              : SearchFailureKind.invalidResponse,
        ),
      );
    }
  }

  void _retry(SearchRetried event, Emitter<SearchState> emit) {
    final query = state.query.trim();
    if (query.length < _minimumQueryLength) return;
    final generation = ++_generation;
    emit(state.copyWith(isLoading: true, clearFailure: true));
    add(SearchSuggestionsRequested(query, generation));
  }

  Future<void> _saveSearch(
    SearchSaved event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final recentSearches = await _recentSearchStore.save(event.query);
      emit(state.copyWith(recentSearches: recentSearches));
    } on Object {
      // Selecting a result still succeeds when optional local history fails.
    }
  }

  Future<void> _removeRecentSearch(
    RecentSearchRemoved event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final recentSearches = await _recentSearchStore.remove(event.query);
      emit(state.copyWith(recentSearches: recentSearches));
    } on Object {
      // Keep the existing list if optional local persistence fails.
    }
  }

  Future<void> _clearRecentSearches(
    RecentSearchesCleared event,
    Emitter<SearchState> emit,
  ) async {
    try {
      await _recentSearchStore.clear();
      emit(state.copyWith(recentSearches: const []));
    } on Object {
      // Keep the existing list if optional local persistence fails.
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

EventTransformer<Event> _sequential<Event>() {
  return (events, mapper) => events.asyncExpand(mapper);
}
