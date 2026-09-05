import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:expert_listing/search/search_repository.dart';
import 'package:expert_listing/search/view/search_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search remains deliberate at 360px in dark mode', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_SearchRepository()),
          recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: SearchView(
              isActive: true,
              onPropertySelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Explore Lagos'), findsOneWidget);
    final field = tester.widget<CupertinoSearchTextField>(
      find.byType(CupertinoSearchTextField),
    );
    expect(field.prefixIcon, isA<AppIcon>());
    expect(field.suffixIcon.icon, Icons.cancel);
    await tester.enterText(
      find.byKey(const ValueKey<String>('property-search-field')),
      'Ikoyi',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('property-suggestion-5003')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('Two-bedroom apartment near the waterfront.'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search shows an honest empty result at 428px in light mode', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(428, 926)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_EmptySearchRepository()),
          recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(platform: TargetPlatform.android),
          home: Scaffold(
            body: SearchView(
              isActive: true,
              onPropertySelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('property-search-field')),
      'ZZZ no match',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('No matching properties yet.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long recent searches grow at large text scale', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const recentSearch = 'Victoria Island waterfront apartments';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_SearchRepository()),
          recentSearchStoreProvider.overrideWithValue(
            _RecentSearchStore(const [recentSearch]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SearchView(
              isActive: true,
              onPropertySelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(recentSearch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _SearchRepository extends SearchRepository {
  _SearchRepository() : super(client: Dio());

  @override
  Future<List<SearchSuggestion>> suggestions(String query) async => const [
    LocationSearchSuggestion(label: 'Ikoyi, Lagos', propertyCount: 1),
    PropertySearchSuggestion(
      postId: 1006,
      propertyId: 5003,
      status: PropertyStatus.forRent,
      location: 'Ikoyi, Lagos',
      summary: 'Two-bedroom apartment near the waterfront.',
      imageUrl: null,
    ),
  ];
}

final class _EmptySearchRepository extends SearchRepository {
  _EmptySearchRepository() : super(client: Dio());

  @override
  Future<List<SearchSuggestion>> suggestions(String query) async => const [];
}

final class _RecentSearchStore implements RecentSearchStore {
  _RecentSearchStore([this.searches = const ['Lekki']]);

  final List<String> searches;

  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> load() async => searches;

  @override
  Future<List<String>> remove(String query) async => const [];

  @override
  Future<List<String>> save(String query) async => [query];
}
