import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local state for device-only feed bookmarks.
abstract class BookmarkStore {
  /// Loads bookmarked post IDs.
  Future<Set<int>> load();

  /// Replaces the complete bookmarked post ID set.
  Future<void> save(Set<int> postIds);

  /// Whether the first-use device-only notice has already appeared.
  Future<bool> hasShownDeviceOnlyNotice();

  /// Records that the first-use device-only notice appeared.
  Future<void> markDeviceOnlyNoticeShown();
}

/// Stores the bounded bookmark overlay in platform preferences.
final class SharedPreferencesBookmarkStore implements BookmarkStore {
  /// Creates the preference-backed store.
  SharedPreferencesBookmarkStore([this._preferences]);

  static const _bookmarksKey = 'feed-bookmarks-v1';
  static const _noticeKey = 'feed-bookmarks-device-notice-v1';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Set<int>> load() async {
    final values = await _store.getStringList(_bookmarksKey) ?? const [];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  @override
  Future<void> save(Set<int> postIds) async {
    final values = postIds.toList()..sort();
    await _store.setStringList(
      _bookmarksKey,
      values.map((id) => '$id').toList(growable: false),
    );
  }

  @override
  Future<bool> hasShownDeviceOnlyNotice() async =>
      await _store.getBool(_noticeKey) ?? false;

  @override
  Future<void> markDeviceOnlyNoticeShown() => _store.setBool(_noticeKey, true);
}
