import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/bloc/feed_bloc.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/data/feed_cache.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved viewer state never crosses preview actor namespaces', () async {
    final directory = await Directory.systemTemp.createTemp(
      'feed-actor-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final server = await _FeedServer.start();
    final cache = FeedCache(
      _cacheManager(
        'feed-actor-cache-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });
    final baseUrl = server.baseUrl;
    final prince = FeedRepository(
      client: Dio(BaseOptions(baseUrl: baseUrl)),
      feedCache: cache,
      cacheNamespace: 'prince',
    );

    await prince.loadPage(filter: const FeedFilter());
    await server.close();

    final ayo = FeedRepository(
      client: Dio(BaseOptions(baseUrl: baseUrl)),
      feedCache: cache,
      cacheNamespace: 'ayo',
    );
    await expectLater(
      ayo.loadPage(filter: const FeedFilter()),
      throwsA(
        isA<FeedLoadFailure>().having(
          (failure) => failure.kind,
          'kind',
          FeedFailureKind.connection,
        ),
      ),
    );

    final saved = await prince.loadPage(filter: const FeedFilter());
    expect(saved.source, FeedDataSource.saved);
    expect(saved.posts.single.id, 42);
  });

  test(
    'reconstructed cache restores data after a connection failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _FeedServer.start();
      addTearDown(server.close);
      final baseUrl = server.baseUrl;
      final cacheKey = 'feed-cache-${DateTime.now().microsecondsSinceEpoch}';
      final firstCache = FeedCache(_cacheManager(cacheKey, directory));
      final firstRepository = _repository(baseUrl, firstCache);

      final network = await firstRepository.loadPage(
        filter: const FeedFilter(),
      );
      expect(network.source, FeedDataSource.network);
      await firstCache.dispose();

      await server.close();
      final rebuiltCache = FeedCache(_cacheManager(cacheKey, directory));
      addTearDown(() async {
        await rebuiltCache.clear();
        await rebuiltCache.dispose();
      });
      final saved = await _repository(baseUrl, rebuiltCache).loadPage(
        filter: const FeedFilter(),
      );

      expect(saved.source, FeedDataSource.saved);
      expect(saved.fallbackReason, FeedFallbackReason.connection);
      expect(saved.savedAt, isNotNull);
      expect(saved.posts.single.id, 42);
    },
  );

  test(
    'an older rejected first page cannot replace newer state or saved data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-race-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _RacingFeedServer.start();
      addTearDown(server.close);
      final cache = FeedCache(
        _cacheManager(
          'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final repository = _TrackingFeedRepository(
        client: Dio(BaseOptions(baseUrl: server.baseUrl)),
        feedCache: cache,
        expectedCompletions: 3,
      );
      final bloc = FeedBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const FeedStarted());
      await server.waitForRequests(1);
      bloc.add(
        const FeedFiltersApplied(FeedFilter(postType: PostType.request)),
      );
      await server.waitForRequests(2);
      bloc.add(const FeedFiltersCleared());
      await server.waitForRequests(3);

      final newestAccepted = bloc.stream.firstWhere(
        (state) => state.posts.isNotEmpty && state.posts.single.id == 3,
      );
      server.complete(2, _response(id: 3, body: 'Newest accepted post'));
      await newestAccepted;

      server
        ..complete(0, _response(id: 1, body: 'Older rejected post'))
        ..complete(1, _response(id: 2, body: 'Rejected filtered post'));
      await repository.allCompleted;

      expect(bloc.state.posts.single.id, 3);
      final saved = await cache.read(
        Uri.parse('${server.baseUrl}/posts?limit=10'),
      );
      expect(saved, isNotNull);
      final posts = saved!.data['posts']! as List<Object?>;
      expect((posts.single! as Map<String, dynamic>)['id'], 3);
    },
  );

  test(
    'an older in-flight write cannot replace the newest saved value',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-race-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manager = _GatedPutCacheManager(
        _cacheConfig(
          'feed-cache-write-race-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      final cache = FeedCache(manager);
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final uri = Uri.parse('https://example.test/functions/v1/api/posts');

      final older = cache.write(uri, _response(id: 1, body: 'Older post'));
      await manager.waitForPutFiles(1);
      final newer = cache.write(uri, _response(id: 3, body: 'Newer post'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        manager.putFileKeys,
        [uri.toString()],
        reason: 'the newer write waits until the older one finishes',
      );

      manager.releasePutFile(0);
      await older;
      await manager.waitForPutFiles(2);
      manager.releasePutFile(1);
      await newer;

      final saved = await cache.read(uri);
      final posts = saved!.data['posts']! as List<Object?>;
      expect((posts.single! as Map<String, dynamic>)['body'], 'Newer post');
    },
  );

  test(
    'corrupt-entry cleanup cannot delete a fresh write for the same URI',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-race-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manager = _GatedRemoveCacheManager(
        _cacheConfig(
          'feed-cache-clean-race-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      final cache = FeedCache(manager);
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final uri = Uri.parse('https://example.test/functions/v1/api/posts');
      await manager.putFile(
        uri.toString(),
        Uint8List.fromList(utf8.encode('not JSON')),
        key: uri.toString(),
        maxAge: FeedCache.retention,
        fileExtension: 'json',
      );

      final read = cache.read(uri);
      await manager.waitForRemovalCall();
      final fresh = cache.write(uri, _response(id: 3, body: 'Fresh post'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        manager.putFileCount,
        1,
        reason: 'the fresh write waits until corrupt-entry cleanup finishes',
      );

      manager.releaseRemoval();
      expect(await read, isNull);
      await fresh;
      expect(manager.putFileCount, 2);

      final saved = await manager.getFileFromCache(
        uri.toString(),
        ignoreMemCache: true,
      );
      expect(saved, isNotNull);
      final stored =
          jsonDecode(await saved!.file.readAsString()) as Map<String, dynamic>;
      final savedPage = stored['data']! as Map<String, dynamic>;
      final storedPosts = savedPage['posts']! as List<Object?>;
      expect((storedPosts.single! as Map<String, dynamic>)['id'], 3);
      expect(await cache.read(uri), isNotNull);
    },
  );

  test('operations for different URIs never wait for each other', () async {
    final directory = await Directory.systemTemp.createTemp(
      'feed-cache-race-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final manager = _GatedPutCacheManager(
      _cacheConfig(
        'feed-cache-uri-race-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    final cache = FeedCache(manager);
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });
    final firstUri = Uri.parse(
      'https://example.test/functions/v1/api/posts?cursor=a',
    );
    final secondUri = Uri.parse(
      'https://example.test/functions/v1/api/posts?cursor=b',
    );

    final first = cache.write(firstUri, _response(id: 1));
    await manager.waitForPutFiles(1);
    final second = cache.write(secondUri, _response(id: 2));
    // The second page reaches storage while the first one is still held.
    await manager.waitForPutFiles(2);
    expect(manager.putFileKeys, [
      firstUri.toString(),
      secondUri.toString(),
    ]);

    manager.releasePutFile(0);
    await first;
    manager.releasePutFile(1);
    await second;

    final firstSaved = await cache.read(firstUri);
    final firstPosts = firstSaved!.data['posts']! as List<Object?>;
    expect((firstPosts.single! as Map<String, dynamic>)['id'], 1);
    final secondSaved = await cache.read(secondUri);
    final secondPosts = secondSaved!.data['posts']! as List<Object?>;
    expect((secondPosts.single! as Map<String, dynamic>)['id'], 2);
  });

  test('invalidation waits for an in-flight same-URI write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'feed-cache-race-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final manager = _GatedPutCacheManager(
      _cacheConfig(
        'feed-cache-clear-race-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    final cache = FeedCache(manager);
    addTearDown(cache.dispose);
    final uri = Uri.parse('https://example.test/functions/v1/api/posts');

    final write = cache.write(uri, _response());
    await manager.waitForPutFiles(1);
    final cleared = cache.clear();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      manager.emptyCacheCalls,
      0,
      reason: 'invalidation waits behind the in-flight write',
    );

    manager.releasePutFile(0);
    await write;
    await cleared;

    expect(manager.emptyCacheCalls, 1);
    expect(
      await manager.getFileFromCache(uri.toString(), ignoreMemCache: true),
      isNull,
    );
  });

  test(
    'two cursor pages stay independently cacheable through the repository',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-race-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _RacingFeedServer.start();
      addTearDown(server.close);
      final cache = FeedCache(
        _cacheManager(
          'feed-cache-cursor-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final repository = _repository(server.baseUrl, cache);

      final firstPage = repository.loadPage(
        filter: const FeedFilter(),
        cursor: 'a',
      );
      await server.waitForRequests(1);
      final secondPage = repository.loadPage(
        filter: const FeedFilter(),
        cursor: 'b',
      );
      await server.waitForRequests(2);

      // The pages complete in reverse start order; each saves under its own
      // full URI.
      server
        ..complete(1, _response(id: 2, body: 'Second cursor page'))
        ..complete(0, _response(id: 1, body: 'First cursor page'));
      await firstPage;
      await secondPage;

      final firstSaved = await cache.read(
        Uri.parse('${server.baseUrl}/posts?limit=10&cursor=a'),
      );
      final secondSaved = await cache.read(
        Uri.parse('${server.baseUrl}/posts?limit=10&cursor=b'),
      );
      expect(firstSaved, isNotNull);
      expect(secondSaved, isNotNull);
      final firstPosts = firstSaved!.data['posts']! as List<Object?>;
      expect((firstPosts.single! as Map<String, dynamic>)['id'], 1);
      final secondPosts = secondSaved!.data['posts']! as List<Object?>;
      expect((secondPosts.single! as Map<String, dynamic>)['id'], 2);
    },
  );

  test(
    'a load in flight before invalidation cannot write into the cleared cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-race-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _RacingFeedServer.start();
      addTearDown(server.close);
      final cache = FeedCache(
        _cacheManager(
          'feed-cache-invalidate-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final repository = _repository(server.baseUrl, cache);

      final page = repository.loadPage(filter: const FeedFilter());
      await server.waitForRequests(1);
      await repository.invalidateFeed();

      server.complete(0, _response(id: 1, body: 'Pre-mutation post'));
      final result = await page;
      expect(result.source, FeedDataSource.network);
      expect(result.posts.single.id, 1);

      final saved = await cache.read(
        Uri.parse('${server.baseUrl}/posts?limit=10'),
      );
      expect(saved, isNull);
    },
  );

  test('a 503 falls back to saved data but a 404 does not', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final server = await _FeedServer.start();
    addTearDown(server.close);
    final cache = FeedCache(
      _cacheManager(
        'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });
    final repository = _repository(server.baseUrl, cache);
    await repository.loadPage(filter: const FeedFilter());

    server.statusCode = HttpStatus.serviceUnavailable;
    final service = await repository.loadPage(filter: const FeedFilter());
    expect(service.source, FeedDataSource.saved);
    expect(service.fallbackReason, FeedFallbackReason.service);

    server.statusCode = HttpStatus.notFound;
    await expectLater(
      repository.loadPage(filter: const FeedFilter()),
      throwsA(
        isA<FeedLoadFailure>().having(
          (failure) => failure.kind,
          'kind',
          FeedFailureKind.unavailable,
        ),
      ),
    );
  });

  test('the full filtered URI identifies one saved page', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final server = await _FeedServer.start();
    addTearDown(server.close);
    final cache = FeedCache(
      _cacheManager(
        'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });
    final repository = _repository(server.baseUrl, cache);
    const filter = FeedFilter(location: 'Yaba, Lagos');
    await repository.loadPage(filter: filter, cursor: 'next-page');

    server.statusCode = HttpStatus.serviceUnavailable;
    final saved = await repository.loadPage(
      filter: filter,
      cursor: 'next-page',
    );
    expect(saved.source, FeedDataSource.saved);
    expect(saved.posts.single.id, 42);
  });

  test('expired and corrupt saved files are cache misses', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final manager = _cacheManager(
      'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
      directory,
    );
    final cache = FeedCache(manager);
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });
    final uri = Uri.parse(
      'https://example.test/functions/v1/api/posts?limit=10',
    );

    await manager.putFile(
      uri.toString(),
      Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'savedAt': 'bad',
            'data': const <String, Object?>{},
          }),
        ),
      ),
      key: uri.toString(),
      maxAge: Duration.zero,
      fileExtension: 'json',
    );
    expect(await cache.read(uri), isNull);

    await manager.putFile(
      uri.toString(),
      Uint8List.fromList(utf8.encode('not JSON')),
      key: uri.toString(),
      maxAge: FeedCache.retention,
      fileExtension: 'json',
    );
    expect(await cache.read(uri), isNull);
  });

  test(
    'evicts the oldest response when the cache exceeds 32 entries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manager = _cacheManager(
        'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      );
      final cache = FeedCache(manager);
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });

      for (var index = 0; index < 33; index++) {
        await cache.write(
          Uri.parse(
            'https://example.test/functions/v1/api/posts?cursor=$index',
          ),
          _response(),
        );
      }
      await manager.getFileFromCache('missing', ignoreMemCache: true);
      await Future<void>.delayed(const Duration(seconds: 11));

      expect(
        await cache.read(
          Uri.parse('https://example.test/functions/v1/api/posts?cursor=0'),
        ),
        isNull,
      );
      expect(
        await cache.read(
          Uri.parse('https://example.test/functions/v1/api/posts?cursor=32'),
        ),
        isNotNull,
      );
    },
  );

  test(
    'a cache write failure after HTTP 200 still returns network data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _FeedServer.start();
      addTearDown(server.close);
      final cache = FeedCache(
        _FailingWriteCacheManager(
          _cacheConfig(
            'failing-feed-cache-${DateTime.now().microsecondsSinceEpoch}',
            directory,
          ),
        ),
      );
      addTearDown(cache.dispose);
      final page = await _repository(server.baseUrl, cache).loadPage(
        filter: const FeedFilter(),
      );

      expect(page.source, FeedDataSource.network);
      expect(page.posts.single.id, 42);
    },
  );

  test('distinct payloads stay isolated under their full URIs', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final cache = FeedCache(
      _cacheManager(
        'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
        directory,
      ),
    );
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });

    final filteredUri = Uri.parse(
      'https://example.test/functions/v1/api/posts'
      '?postType=request&location=Yaba&cursor=abc',
    );
    final secondUri = Uri.parse(
      'https://example.test/functions/v1/api/posts'
      '?postType=request&location=Yaba&cursor=def',
    );
    await cache.write(filteredUri, _response(id: 1, body: 'Filtered page'));
    await cache.write(secondUri, _response(id: 2, body: 'Second page'));

    final filtered = await cache.read(filteredUri);
    final second = await cache.read(secondUri);

    expect(filtered, isNotNull);
    expect(second, isNotNull);
    final filteredPosts = filtered!.data['posts']! as List<Object?>;
    final secondPosts = second!.data['posts']! as List<Object?>;
    final filteredPost = filteredPosts.single! as Map<String, dynamic>;
    final secondPost = secondPosts.single! as Map<String, dynamic>;
    expect(filteredPost['id'], 1);
    expect(filteredPost['body'], 'Filtered page');
    expect(secondPost['id'], 2);
    expect(secondPost['body'], 'Second page');
  });

  test('writes receive the seven-day validity period', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final manager = _cacheManager(
      'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
      directory,
    );
    final cache = FeedCache(manager);
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });

    final uri = Uri.parse('https://example.test/functions/v1/api/posts');
    await cache.write(uri, _response());

    final info = await manager.getFileFromCache(uri.toString());
    expect(info, isNotNull);
    final validity = info!.validTill.difference(DateTime.now().toUtc());
    const tolerance = Duration(minutes: 2);
    expect(validity, greaterThan(FeedCache.retention - tolerance));
    expect(validity, lessThan(FeedCache.retention + tolerance));
  });

  test('a corrupt entry is removed instead of decoded repeatedly', () async {
    final directory = await Directory.systemTemp.createTemp('feed-cache-test');
    addTearDown(() => directory.delete(recursive: true));
    final manager = _cacheManager(
      'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
      directory,
    );
    final cache = FeedCache(manager);
    addTearDown(() async {
      await cache.clear();
      await cache.dispose();
    });

    final uri = Uri.parse('https://example.test/functions/v1/api/posts');
    await cache.write(uri, _response());

    final cached = await manager.getFileFromCache(uri.toString());
    expect(cached, isNotNull);
    await cached!.file.writeAsString('not JSON');

    expect(await cache.read(uri), isNull);

    final removed = await manager.getFileFromCache(
      uri.toString(),
      ignoreMemCache: true,
    );
    expect(removed, isNull);
    expect(await cache.read(uri), isNull);
  });

  test(
    'a malformed HTTP 200 cannot replace an earlier valid saved page',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'feed-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final server = await _FeedServer.start();
      addTearDown(server.close);
      final cache = FeedCache(
        _cacheManager(
          'feed-cache-${DateTime.now().microsecondsSinceEpoch}',
          directory,
        ),
      );
      addTearDown(() async {
        await cache.clear();
        await cache.dispose();
      });
      final repository = _repository(server.baseUrl, cache);
      await repository.loadPage(filter: const FeedFilter());

      server.response = const {'posts': 'not a list', 'nextCursor': null};
      await expectLater(
        repository.loadPage(filter: const FeedFilter()),
        throwsA(
          isA<FeedLoadFailure>().having(
            (failure) => failure.kind,
            'kind',
            FeedFailureKind.unavailable,
          ),
        ),
      );

      await server.close();
      final saved = await repository.loadPage(filter: const FeedFilter());
      expect(saved.source, FeedDataSource.saved);
      expect(saved.posts.single.id, 42);
    },
  );
}

CacheManager _cacheManager(String key, Directory directory) {
  return CacheManager(_cacheConfig(key, directory));
}

Config _cacheConfig(String key, Directory directory) {
  return Config(
    key,
    stalePeriod: FeedCache.retention,
    maxNrOfCacheObjects: 32,
    repo: JsonCacheInfoRepository(path: '${directory.path}/cache-info.json'),
    fileSystem: _TemporaryFileSystem(directory),
  );
}

FeedRepository _repository(String baseUrl, FeedCache cache) => FeedRepository(
  client: Dio(BaseOptions(baseUrl: baseUrl)),
  feedCache: cache,
);

final class _TrackingFeedRepository extends FeedRepository {
  _TrackingFeedRepository({
    required super.client,
    required super.feedCache,
    required this.expectedCompletions,
  });

  final int expectedCompletions;
  final _allCompleted = Completer<void>();
  var _completionCount = 0;

  Future<void> get allCompleted => _allCompleted.future;

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) async {
    try {
      return await super.loadPage(
        filter: filter,
        cursor: cursor,
        limit: limit,
      );
    } finally {
      _completionCount++;
      if (_completionCount == expectedCompletions) _allCompleted.complete();
    }
  }
}

final class _FailingWriteCacheManager extends CacheManager {
  _FailingWriteCacheManager(super.config);

  @override
  Future<Never> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => Future<Never>.error(StateError('Disk is unavailable.'));
}

/// Holds every putFile at the real storage boundary until the test releases
/// it, so write orderings are observed exactly.
final class _GatedPutCacheManager extends CacheManager {
  _GatedPutCacheManager(super.config);

  final putFileKeys = <String>[];
  final _putFileGates = <Completer<void>>[];
  int emptyCacheCalls = 0;

  Future<void> waitForPutFiles(int count) async {
    while (_putFileGates.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void releasePutFile(int index) => _putFileGates[index].complete();

  @override
  Future<void> emptyCache() async {
    emptyCacheCalls++;
    await super.emptyCache();
  }

  @override
  Future<file.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final gate = Completer<void>();
    _putFileGates.add(gate);
    putFileKeys.add(key ?? url);
    await gate.future;
    return super.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
  }
}

/// Holds every removeFile at the real storage boundary and counts putFile
/// calls, so corrupt-entry cleanup orderings are observed exactly.
final class _GatedRemoveCacheManager extends CacheManager {
  _GatedRemoveCacheManager(super.config);

  int putFileCount = 0;
  final _removalGates = <Completer<void>>[];

  Future<void> waitForRemovalCall() async {
    while (_removalGates.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void releaseRemoval() => _removalGates.single.complete();

  @override
  Future<void> removeFile(String key) async {
    final gate = Completer<void>();
    _removalGates.add(gate);
    await gate.future;
    await super.removeFile(key);
  }

  @override
  Future<file.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    putFileCount++;
    return super.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
  }
}

final class _TemporaryFileSystem implements FileSystem {
  _TemporaryFileSystem(this._directory);

  final Directory _directory;
  static const _local = LocalFileSystem();

  @override
  Future<file.File> createFile(String name) async {
    final directory = _local.directory(_directory.path);
    await directory.create(recursive: true);
    return directory.childFile(name);
  }
}

final class _FeedServer {
  _FeedServer._(this._server);

  final HttpServer _server;
  int statusCode = HttpStatus.ok;
  Map<String, dynamic> response = _response();
  bool _closed = false;

  String get baseUrl =>
      'http://${_server.address.address}:${_server.port}/functions/v1/api';

  static Future<_FeedServer> start() async {
    final server = _FeedServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen((request) async {
      request.response
        ..statusCode = server.statusCode
        ..headers.contentType = ContentType.json;
      if (server.statusCode == HttpStatus.ok) {
        request.response.write(jsonEncode(server.response));
      }
      await request.response.close();
    });
    return server;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server.close(force: true);
  }
}

final class _RacingFeedServer {
  _RacingFeedServer._(this._server);

  final HttpServer _server;
  final List<Completer<Map<String, dynamic>>> _responses = [];

  String get baseUrl =>
      'http://${_server.address.address}:${_server.port}/functions/v1/api';

  static Future<_RacingFeedServer> start() async {
    final server = _RacingFeedServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen((request) async {
      final response = Completer<Map<String, dynamic>>();
      server._responses.add(response);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(await response.future));
      await request.response.close();
    });
    return server;
  }

  Future<void> waitForRequests(int count) async {
    while (_responses.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void complete(int index, Map<String, dynamic> response) {
    _responses[index].complete(response);
  }

  Future<void> close() => _server.close(force: true);
}

Map<String, dynamic> _response({int id = 42, String body = 'Saved post 42'}) =>
    {
      'posts': [
        {
          'id': id,
          'body': body,
          'postType': 'general',
          'createdAt': '2026-09-03T12:00:00.000Z',
          'viewCount': 1,
          'bookmarkCount': 0,
          'likeCount': 0,
          'commentCount': 0,
          'likedByCurrentUser': false,
          'author': {
            'id': '11111111-1111-4111-8111-111111111111',
            'handle': 'prince',
            'displayName': 'Prince',
            'role': 'Buyer',
            'avatarUrl': null,
          },
          'location': 'Yaba, Lagos',
        },
      ],
      'nextCursor': null,
    };
