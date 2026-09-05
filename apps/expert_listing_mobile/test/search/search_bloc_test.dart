import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/search/bloc/search_bloc.dart';
import 'package:expert_listing/search/bloc/search_event.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a stale autocomplete response cannot replace the latest query',
    () async {
      final repository = _ControlledSearchRepository();
      final bloc = SearchBloc(
        repository: repository,
        recentSearchStore: _MemoryRecentSearchStore(),
      );
      addTearDown(bloc.close);

      bloc.add(const SearchQueryChanged('Lekki'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      bloc.add(const SearchQueryChanged('Ikoyi'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final latestResult = bloc.stream.firstWhere(
        (state) => state.suggestions.contains(_ikoyi),
      );
      repository.complete('Ikoyi', const [_ikoyi]);
      await latestResult;
      repository.complete('Lekki', const [_lekki]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.query, 'Ikoyi');
      expect(bloc.state.suggestions, const [_ikoyi]);
    },
  );

  test(
    'saving searches keeps newest unique values and persists five',
    () async {
      final store = _MemoryRecentSearchStore();
      final bloc = SearchBloc(
        repository: _ControlledSearchRepository(),
        recentSearchStore: store,
      );
      addTearDown(bloc.close);

      for (final query in [
        'Lekki',
        'Ikoyi',
        'Ajah',
        'Magodo',
        'Yaba',
        'lekki',
      ]) {
        bloc.add(SearchSaved(query));
        await bloc.stream.firstWhere(
          (state) => state.recentSearches.isNotEmpty,
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.recentSearches, [
        'lekki',
        'Yaba',
        'Magodo',
        'Ajah',
        'Ikoyi',
      ]);
      expect(await store.load(), bloc.state.recentSearches);
    },
  );

  test('recent-search writes complete in event order', () async {
    final store = _DelayedRecentSearchStore();
    final bloc = SearchBloc(
      repository: _ControlledSearchRepository(),
      recentSearchStore: store,
    );
    addTearDown(bloc.close);

    bloc.add(const SearchSaved('Lekki'));
    await store.firstSaveStarted.future;
    bloc.add(const SearchSaved('Ikoyi'));
    await Future<void>.delayed(Duration.zero);
    store.releaseFirstSave.complete();
    await bloc.stream.firstWhere(
      (state) => state.recentSearches.length == 2,
    );

    expect(bloc.state.recentSearches, ['Ikoyi', 'Lekki']);
    expect(await store.load(), bloc.state.recentSearches);
  });

  test('connection failures retain a specific user-facing category', () async {
    final bloc = SearchBloc(
      repository: _FailingSearchRepository(),
      recentSearchStore: _MemoryRecentSearchStore(),
    );
    addTearDown(bloc.close);

    bloc.add(const SearchQueryChanged('Lekki'));
    await bloc.stream.firstWhere(
      (state) => state.failure == SearchFailureKind.connection,
    );

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.suggestions, isEmpty);
  });

  test('loads, removes, and clears persisted recent searches', () async {
    final store = _MemoryRecentSearchStore();
    await store.save('Lekki');
    await store.save('Ikoyi');
    final bloc = SearchBloc(
      repository: _ControlledSearchRepository(),
      recentSearchStore: store,
    );
    addTearDown(bloc.close);

    bloc.add(const SearchStarted());
    await bloc.stream.firstWhere((state) => state.recentSearches.length == 2);

    bloc.add(const RecentSearchRemoved('Lekki'));
    await bloc.stream.firstWhere(
      (state) => !state.recentSearches.contains('Lekki'),
    );
    expect(await store.load(), ['Ikoyi']);

    bloc.add(const RecentSearchesCleared());
    await bloc.stream.firstWhere((state) => state.recentSearches.isEmpty);
    expect(await store.load(), isEmpty);
  });
}

const _lekki = LocationSearchSuggestion(
  label: 'Lekki Phase 1, Lagos',
  propertyCount: 1,
);

const _ikoyi = PropertySearchSuggestion(
  postId: 1006,
  propertyId: 5003,
  status: PropertyStatus.forRent,
  location: 'Ikoyi, Lagos',
  summary: 'Two-bedroom apartment near the waterfront.',
  imageUrl: null,
);

final class _ControlledSearchRepository extends SearchRepository {
  _ControlledSearchRepository() : super(client: Dio());

  final _requests = <String, Completer<List<SearchSuggestion>>>{};

  @override
  Future<List<SearchSuggestion>> suggestions(String query) {
    return (_requests[query] ??= Completer<List<SearchSuggestion>>()).future;
  }

  void complete(String query, List<SearchSuggestion> suggestions) {
    _requests[query]!.complete(suggestions);
  }
}

final class _FailingSearchRepository extends SearchRepository {
  _FailingSearchRepository() : super(client: Dio());

  @override
  Future<List<SearchSuggestion>> suggestions(String query) {
    throw const SearchFailure(SearchFailureKind.connection);
  }
}

class _MemoryRecentSearchStore implements RecentSearchStore {
  var _searches = <String>[];

  @override
  Future<List<String>> load() async => List.unmodifiable(_searches);

  @override
  Future<List<String>> save(String query) async {
    _searches = [
      query,
      ..._searches.where(
        (search) => search.toLowerCase() != query.toLowerCase(),
      ),
    ].take(5).toList();
    return load();
  }

  @override
  Future<List<String>> remove(String query) async {
    _searches = _searches
        .where((search) => search.toLowerCase() != query.toLowerCase())
        .toList();
    return load();
  }

  @override
  Future<void> clear() async => _searches.clear();
}

final class _DelayedRecentSearchStore extends _MemoryRecentSearchStore {
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  var _saveCount = 0;

  @override
  Future<List<String>> save(String query) async {
    _saveCount++;
    if (_saveCount == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    return super.save(query);
  }
}
