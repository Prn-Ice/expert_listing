import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/data/feed_cache.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

Map<String, dynamic> _response() => {
  'posts': [
    {
      'id': 42,
      'body': 'Saved post 42',
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
