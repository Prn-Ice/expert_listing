import 'package:shared_preferences/shared_preferences.dart';

/// Persists the highest activity ID considered for one preview persona.
abstract interface class NotificationAlertCursorStore {
  /// Loads the highest considered event ID, or null before the first baseline.
  Future<int?> load(String actorKey);

  /// Saves the highest event ID considered for [actorKey].
  Future<void> save(String actorKey, int notificationId);
}

/// Stores actor-scoped alert cursors in platform preferences.
final class SharedPreferencesNotificationAlertCursorStore
    implements NotificationAlertCursorStore {
  /// Creates the preference-backed cursor store.
  SharedPreferencesNotificationAlertCursorStore([this._preferences]);

  static const _keyPrefix = 'notification-alert-cursor-v1';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<int?> load(String actorKey) => _store.getInt(_key(actorKey));

  @override
  Future<void> save(String actorKey, int notificationId) =>
      _store.setInt(_key(actorKey), notificationId);

  String _key(String actorKey) => '$_keyPrefix:$actorKey';
}
