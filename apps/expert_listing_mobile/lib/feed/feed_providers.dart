import 'dart:async';

import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/bloc/feed_bloc.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/data/feed_cache.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverbloc/riverbloc.dart';

/// Owns storage dedicated to saved feed responses, never public image bytes.
final feedCacheProvider = Provider<FeedCache>((ref) {
  final cache = FeedCache(
    CacheManager(
      Config(
        'expert-listing-feed-responses',
        stalePeriod: FeedCache.retention,
        maxNrOfCacheObjects: 32,
      ),
    ),
  );
  ref.onDispose(() => unawaited(cache.dispose()));
  return cache;
});

/// The concrete Hono feed boundary.
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    client: ref.watch(httpClientProvider),
    feedCache: ref.watch(feedCacheProvider),
  );
});

/// The event-based feed behavior lifecycle, owned by Riverpod through
/// Riverbloc.
final feedBlocProvider = BlocProvider<FeedBloc, FeedState>(
  (ref) {
    return FeedBloc(repository: ref.watch(feedRepositoryProvider));
  },
);
