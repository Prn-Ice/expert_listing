import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/search/recent_search_store.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({TargetPlatform? platformOverride}) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            'http://127.0.0.1:56321/functions/v1/api',
            isRelease: false,
          ),
        ),
        feedRepositoryProvider.overrideWithValue(_ThemeFeedRepository()),
        recentSearchStoreProvider.overrideWithValue(_RecentSearchStore()),
      ],
      child: ExpertListingApp(platformOverride: platformOverride),
    );
  }

  testWidgets('iOS constructs a Cupertino root and Android a Material root', (
    tester,
  ) async {
    await tester.pumpWidget(harness(platformOverride: TargetPlatform.iOS));
    await tester.pump();
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsNothing);

    await tester.pumpWidget(harness(platformOverride: TargetPlatform.android));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CupertinoApp), findsNothing);
  });

  testWidgets('semantic colours follow the system appearance on both roots', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(harness(platformOverride: platform));
      await tester.pump();
      var context = tester.element(find.byType(FeedView));
      expect(
        Theme.of(context).extension<AppColors>(),
        AppColors.light,
        reason: 'the $platform root starts on the light palette',
      );
      if (platform == TargetPlatform.iOS) {
        expect(
          Theme.of(context).platform,
          TargetPlatform.iOS,
          reason: 'the Cupertino subtree resolves the hosted platform',
        );
      }

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      // The Material root animates its theme switch; the Cupertino root
      // restyles synchronously.
      await tester.pumpAndSettle();
      context = tester.element(find.byType(FeedView));
      expect(
        Theme.of(context).extension<AppColors>(),
        AppColors.dark,
        reason: 'the $platform root follows the system appearance',
      );
    }
  });

  testWidgets('the Cupertino root rebuilds its theme data with appearance', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(harness(platformOverride: TargetPlatform.iOS));
    await tester.pump();
    var theme = CupertinoTheme.of(tester.element(find.byType(FeedView)));
    expect(theme.scaffoldBackgroundColor, AppColors.light.canvas);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    theme = CupertinoTheme.of(tester.element(find.byType(FeedView)));
    expect(theme.scaffoldBackgroundColor, AppColors.dark.canvas);
  });

  testWidgets('system light brightness renders the light theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(harness());

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.light);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.light.canvas);
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.statusBarBrightness, Brightness.light);
  });

  testWidgets('system dark brightness renders the dark theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(harness());

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.dark.canvas);
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.statusBarBrightness, Brightness.dark);
  });

  testWidgets('configuration errors follow system dark appearance', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      const ConfigurationErrorApp(
        AppConfigException('API_BASE_URL is required.'),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.dark.canvas);
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.statusBarBrightness, Brightness.dark);
  });

  testWidgets('the configuration error surface follows the platform policy', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      const ConfigurationErrorApp(
        AppConfigException('API_BASE_URL is required.'),
        platformOverride: TargetPlatform.iOS,
      ),
    );

    expect(find.byType(CupertinoApp), findsOneWidget);
    var context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.dark);
  });
}

final class _RecentSearchStore implements RecentSearchStore {
  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> load() async => const [];

  @override
  Future<List<String>> remove(String query) async => const [];

  @override
  Future<List<String>> save(String query) async => [query];
}

final class _ThemeFeedRepository extends FeedRepository {
  _ThemeFeedRepository()
    : super(
        client: Dio(),
      );

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) => Future.value(
    const FeedLoadResult(
      posts: [],
      nextCursor: null,
      source: FeedDataSource.network,
    ),
  );
}
