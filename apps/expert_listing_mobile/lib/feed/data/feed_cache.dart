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

  /// Reads one non-expired saved response without making a network request.
  Future<SavedFeedEntry?> read(Uri uri) async {
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
      return null;
    }
  }

  /// Saves a validated response for the requested full URI.
  Future<void> write(Uri uri, Map<String, dynamic> validatedData) async {
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
  }

  /// Removes every saved feed response after a successful mutation.
  Future<void> clear() async {
    try {
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
}
