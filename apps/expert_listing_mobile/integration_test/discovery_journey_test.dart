import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/listings/view/listing_card.dart';
import 'package:expert_listing/listings/view/listings_view.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The implemented discovery portion of the required journey through the
/// production provider graph and real Hono/Postgres/preferences boundaries.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'searches a seeded location, browses the catalog, and switches persona',
    (tester) async {
      final config = AppConfig.fromEnvironment();
      final recentSearches = SharedPreferencesRecentSearchStore();
      await tester.runAsync(recentSearches.clear);
      addTearDown(recentSearches.clear);
      await _pumpApp(tester, config);

      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('property-search-field')),
        'Lekki',
      );
      await _pumpUntilFound(
        tester,
        find.bySemanticsLabel(
          'Search Lekki Phase 1, Lagos, 1 properties',
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(
          'Search Lekki Phase 1, Lagos, 1 properties',
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('property-suggestion-5001')),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('property-suggestion-5001')),
      );
      await tester.pump();
      expect(
        find.text("Property details aren't part of this preview."),
        findsOneWidget,
      );
      await tester.runAsync(
        () => _waitForRecentSearch(
          recentSearches,
          'Lekki Phase 1, Lagos',
        ),
      );

      // Reconstruct the complete provider graph; the query must come back from
      // the platform preference boundary rather than retained Bloc state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpApp(tester, config);
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.bySemanticsLabel('Search again for Lekki Phase 1, Lagos'),
      );

      await tester.tap(find.bySemanticsLabel('List'));
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey<String>('listing-5001')),
      );
      expect(find.byType(ListingCard), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('listing-5005')),
        findsNothing,
      );

      final catalog = find.descendant(
        of: find.byType(ListingsView),
        matching: find.byType(CustomScrollView),
      );
      await _dragUntilFound(
        tester,
        catalog,
        find.byKey(const ValueKey<String>('listing-5005')),
      );

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Prince Adeyemi'));
      expect(find.text('@prince'), findsOneWidget);
      expect(find.text('Realtor'), findsOneWidget);

      await tester.tap(find.text('Previewing @prince'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@ayo'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Ayo Balogun'));
      expect(find.text('@ayo'), findsOneWidget);
      expect(find.text('Property Consultant'), findsOneWidget);
    },
  );
}

Future<void> _dragUntilFound(
  WidgetTester tester,
  Finder scrollable,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out scrolling to $finder');
}

Future<void> _waitForRecentSearch(
  RecentSearchStore store,
  String query,
) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(end)) {
    if ((await store.load()).contains(query)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for recent search $query');
}

Future<void> _pumpApp(WidgetTester tester, AppConfig config) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const ExpertListingApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
