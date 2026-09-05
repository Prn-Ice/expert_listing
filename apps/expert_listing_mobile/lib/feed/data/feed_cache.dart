import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One validated feed response recovered from durable storage.
final class SavedFeedEntry {
  /// Creates a saved cache entry with the time it was written.
  const SavedFeedEntry({required this.data, required this.savedAt});

  /// The validated Hono response body.
  final Map<String, dynamic> data;

  /// The UTC time when this page was saved.
  final DateTime savedAt;
}

/// Durable, cache-only storage for validated feed responses.
///
/// This deliberately uses a separate [CacheManager] from image loading. Cache
/// failures are optional infrastructure, so every public operation is safe.
final class FeedCache {
  /// Creates the feed cache around its dedicated storage manager.
  FeedCache(this._manager);

  /// The seven-day maximum age for one saved feed response.
  static const retention = Duration(days: 7);

  final CacheManager _manager;

  /// The operation chain for each saved page, so concurrent work on one full
  /// URI finishes one at a time in call order while other pages stay free.
  final _operationsByUri = <String, Future<void>>{};

  /// Reads one non-expired saved response without making a network request.
  Future<SavedFeedEntry?> read(Uri uri) {
    return _oneAtATime(uri, () async {
      final key = uri.toString();
      try {
        final cached = await _manager.getFileFromCache(key);
        if (cached == null) return null;
        if (!cached.validTill.isAfter(DateTime.now())) {
          await _remove(key);
          return null;
        }

        final decoded = jsonDecode(await cached.file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          await _remove(key);
          return null;
        }
        final savedAt = DateTime.tryParse(decoded['savedAt'] as String? ?? '');
        final data = decoded['data'];
        if (savedAt == null || data is! Map<String, dynamic>) {
          await _remove(key);
          return null;
        }
        return SavedFeedEntry(data: data, savedAt: savedAt.toUtc());
      } on Object {
        // A corrupt entry is removed so it is never decoded repeatedly; a
        // removal failure only leaves an already-unreadable cache miss.
        await _remove(key);
        return null;
      }
    });
  }

  /// Saves a validated response for the requested full URI.
  Future<void> write(Uri uri, Map<String, dynamic> validatedData) {
    return _oneAtATime(uri, () async {
      try {
        final savedAt = DateTime.now().toUtc();
        final bytes = Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'savedAt': savedAt.toIso8601String(),
              'data': validatedData,
            }),
          ),
        );
        await _manager.putFile(
          uri.toString(),
          bytes,
          key: uri.toString(),
          maxAge: retention,
          fileExtension: 'json',
        );
        // CacheManager schedules metadata persistence separately from byte
        // writes.
        await Future<void>.delayed(Duration.zero);
      } on Object {
        // The live response remains correct when disk storage is unavailable.
      }
    });
  }

  /// Removes all saved feed pages after a successful mutation.
  Future<void> clear() async {
    try {
      // Page work already running finishes before the wipe, so a slow write
      // cannot restore stale data after the invalidation.
      final running = _operationsByUri.values.toList();
      for (final operation in running) {
        await operation;
      }
      await _manager.emptyCache();
    } on Object {
      // Cache invalidation must never fail a correct mutation.
    }
  }

  /// Releases the dedicated cache manager.
  Future<void> dispose() async {
    try {
      await _manager.dispose();
    } on Object {
      // Disposal is best effort during provider teardown.
    }
  }

  Future<void> _remove(String key) async {
    try {
      await _manager.removeFile(key);
    } on Object {
      // A corrupt entry is already a cache miss if removal also fails.
    }
  }

  /// Runs [operation] after every earlier read, write, or removal for [uri].
  ///
  /// Each page keeps its own queue: the newest write for a URI is therefore
  /// the final saved value, and corrupt-entry cleanup can no longer delete a
  /// replacement written under the same URI. Different URIs never wait for
  /// each other.
  Future<T> _oneAtATime<T>(Uri uri, Future<T> Function() operation) {
    final key = uri.toString();
    final pending = _operationsByUri[key] ?? Future<void>.value();
    final done = Completer<void>();
    final result = pending.then((_) async {
      try {
        return await operation();
      } finally {
        if (identical(_operationsByUri[key], done.future)) {
          final _ = _operationsByUri.remove(key);
        }
        done.complete();
      }
    });
    _operationsByUri[key] = done.future;
    return result;
  }
}
