import 'package:shared_preferences/shared_preferences.dart';

/// The persisted boundary for this device's recent property searches.
abstract class RecentSearchStore {
  /// Loads newest-first recent searches.
  Future<List<String>> load();

  /// Moves [query] to the front and returns the bounded result.
  Future<List<String>> save(String query);

  /// Removes one query and returns the remaining result.
  Future<List<String>> remove(String query);

  /// Removes all recent searches.
  Future<void> clear();
}

/// Stores a small recent-search list in platform preferences.
final class SharedPreferencesRecentSearchStore implements RecentSearchStore {
  /// Creates the preference-backed store.
  SharedPreferencesRecentSearchStore([this._preferences]);

  static const _key = 'recent-property-searches-v1';
  static const _maximumCount = 5;

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<List<String>> load() async =>
      List.unmodifiable(await _store.getStringList(_key) ?? const []);

  @override
  Future<List<String>> save(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final searches = await load();
    final updated = [
      trimmed,
      ...searches.where(
        (search) => search.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(_maximumCount).toList(growable: false);
    await _store.setStringList(_key, updated);
    return updated;
  }

  @override
  Future<List<String>> remove(String query) async {
    final updated = (await load())
        .where((search) => search.toLowerCase() != query.toLowerCase())
        .toList(growable: false);
    if (updated.isEmpty) {
      await _store.remove(_key);
    } else {
      await _store.setStringList(_key, updated);
    }
    return updated;
  }

  @override
  Future<void> clear() => _store.remove(_key);
}
