import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The required feed journey through the production provider graph against
/// the real local Hono/Postgres stack:
///
/// launch the seeded feed, exercise every filter dimension, clear filters,
/// paginate, and refresh while keeping post identity and scroll position.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'browse, filter every dimension, clear, paginate, and refresh',
    (tester) async {
      final config = AppConfig.fromEnvironment();
      await _pumpApp(tester, config);

      // Launch: the seeded feed renders its first page.
      await _pumpUntilFound(tester, find.byType(PostCard));
      expect(find.text('Ayo Balogun'), findsWidgets);
      expect(find.text('Liked by ifeoma and 1 other'), findsOneWidget);
      expect(
        find.text('The study could work well as a nursery too.'),
        findsOneWidget,
      );
      expect(find.text('View all 2 comments'), findsOneWidget);
      final identity = _firstVisiblePostId(tester);
      expect(_scrollOffset(tester), 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostCard).first),
      );
      final bloc = container.read(feedBlocProvider.bloc);

      // Refresh at the top keeps the same posts and scroll position.
      final refreshCompleted = bloc.stream.firstWhere(
        (state) => !state.isRefreshing && !state.isInitialLoading,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump();
      await tester.runAsync(
        () => refreshCompleted.timeout(const Duration(seconds: 15)),
      );
      await tester.pumpAndSettle();
      expect(_firstVisiblePostId(tester), identity);
      expect(_scrollOffset(tester), 0);

      // Scrolling keeps stable post identity (ValueKey per post id).
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      final scrolledOffset = _scrollOffset(tester);
      expect(scrolledOffset, greaterThan(0));
      expect(_firstVisiblePostId(tester), isPositive);

      // The pinned Feed destination returns the scrolled feed to its top.
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(_scrollOffset(tester), 0);

      // Post type plus request type filters reach the server.
      await _applySheetFilter(tester, ['Request', 'Looking to buy']);
      await _pumpUntilFound(tester, find.text('Looking to Buy'));

      await _applySheetFilter(tester, ['Request', 'Looking to rent']);
      await _pumpUntilFound(tester, find.text('Looking to Rent'));

      // Post type plus property status filters reach the server.
      await _applySheetFilter(tester, ['Property', 'For sale']);
      await _pumpUntilFound(tester, find.text('For Sale'));

      await _applySheetFilter(tester, ['Property', 'For rent']);
      await _pumpUntilFound(tester, find.text('For Rent'));

      await _applySheetFilter(tester, ['General']);
      await _pumpUntilFound(tester, find.byType(PostCard));
      expect(find.text('For Sale'), findsNothing);
      expect(find.text('For Rent'), findsNothing);

      // A location filter restricts matching owned locations; reset the
      // post-type dimension first because the sheet keeps the active one.
      await _openSheet(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('feed-filter-sheet')),
          matching: find.text('All'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_sheetField(tester), 'Lekki');
      await _apply(tester);
      await _pumpUntilFound(tester, find.text('Lekki Phase 1, Lagos'));

      // A location with no matches shows the filtered empty state.
      await _openSheet(tester);
      await tester.enterText(_sheetField(tester), 'ZZZ No Match');
      await _apply(tester);
      await _pumpUntilFound(tester, find.text('No posts match these filters.'));

      // Clearing restores the full feed.
      await tester.tap(find.text('Clear filters'));
      await _pumpUntilFound(tester, find.text('Ayo Balogun'));

      // Pagination appends the next page without duplicates.
      for (var fling = 0; fling < 4; fling++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2500),
        );
        await tester.pumpAndSettle();
      }
      await _pumpUntilFound(
        tester,
        find.textContaining('Three-bedroom duplex'),
      );
      final appendedIds = bloc.state.posts.map((post) => post.id).toList();
      expect(appendedIds.length, greaterThan(10));
      expect(appendedIds.toSet(), hasLength(appendedIds.length));
      final renderedIds = find
          .byType(PostCard)
          .evaluate()
          .map((element) => (element.widget as PostCard).post.id)
          .toList();
      expect(renderedIds.toSet(), hasLength(renderedIds.length));
    },
  );
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

int _firstVisiblePostId(WidgetTester tester) {
  final card = tester.widget<PostCard>(find.byType(PostCard).first);
  return card.post.id;
}

double _scrollOffset(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  return scrollable.position.pixels;
}

Finder _sheetField(WidgetTester tester) => find.descendant(
  of: find.byKey(const ValueKey<String>('feed-filter-sheet')),
  matching: find.byType(EditableText),
);

Future<void> _openSheet(WidgetTester tester) async {
  // The filter control sits near the top; return there first if needed.
  if (_scrollOffset(tester) > 0) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2500));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey<String>('feed-filters')));
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey<String>('feed-filter-sheet')),
  );
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

Future<void> _applySheetFilter(
  WidgetTester tester,
  List<String> labels,
) async {
  await _openSheet(tester);
  for (final label in labels) {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('feed-filter-sheet')),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }
  await _apply(tester);
}
