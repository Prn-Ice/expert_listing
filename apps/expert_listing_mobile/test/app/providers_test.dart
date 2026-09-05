import 'package:dio/dio.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/listings/listings_providers.dart';
import 'package:expert_listing/profile/profile_providers.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppConfig testConfig() => AppConfig.parse(
    'http://127.0.0.1:56321/functions/v1/api',
    isRelease: false,
  );

  group('appConfigProvider', () {
    test('requires the startup override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(appConfigProvider),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('httpClientProvider', () {
    test('returns one client per container and closes it once on dispose', () {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
      );

      final first = container.read(httpClientProvider);
      final second = container.read(httpClientProvider);
      expect(identical(first, second), isTrue);
      expect(first.options.baseUrl, testConfig().apiBaseUri.toString());

      container.dispose();

      // The closed client rejects further requests.
      expect(
        () => first.get<Map<String, dynamic>>('/health'),
        throwsA(
          isA<DioException>().having(
            (error) => error.message,
            'message',
            contains('closed'),
          ),
        ),
      );

      // A fresh container builds a fresh client rather than reviving the old.
      final secondContainer = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
      );
      addTearDown(secondContainer.dispose);
      final third = secondContainer.read(httpClientProvider);
      expect(identical(first, third), isFalse);
    });

    test(
      'actor aliases recreate sensitive lifecycles but retain local stores',
      () {
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(testConfig()),
            feedRepositoryProvider.overrideWith(
              (ref) => FeedRepository(client: ref.watch(httpClientProvider)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final client = container.read(httpClientProvider);
        final feed = container.read(feedBlocProvider.bloc);
        final listings = container.read(listingsBlocProvider.bloc);
        final search = container.read(searchBlocProvider.bloc);
        final profile = container.read(profileCubitProvider.bloc);
        final recentSearches = container.read(recentSearchStoreProvider);

        container.read(previewActorProvider.notifier).select('ayo');

        final nextClient = container.read(httpClientProvider);
        expect(nextClient.options.headers['X-Preview-Actor'], 'ayo');
        expect(identical(client, nextClient), isFalse);
        expect(identical(feed, container.read(feedBlocProvider.bloc)), isFalse);
        expect(
          identical(listings, container.read(listingsBlocProvider.bloc)),
          isFalse,
        );
        expect(
          identical(search, container.read(searchBlocProvider.bloc)),
          isFalse,
        );
        expect(
          identical(profile, container.read(profileCubitProvider.bloc)),
          isFalse,
        );
        expect(
          identical(recentSearches, container.read(recentSearchStoreProvider)),
          isTrue,
        );
      },
    );

    test('actor state rejects raw UUIDs before creating a request header', () {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(previewActorProvider.notifier)
            .select('00000000-0000-0000-0000-000000000002'),
        throwsArgumentError,
      );
      expect(container.read(previewActorProvider), isNull);
      expect(
        container.read(httpClientProvider).options.headers,
        isNot(contains('X-Preview-Actor')),
      );
    });
  });
}
