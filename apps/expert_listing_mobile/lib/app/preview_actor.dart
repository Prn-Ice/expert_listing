import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local-debug preview alias selected for request-scoped server resolution.
final previewActorProvider = NotifierProvider<PreviewActor, String?>(
  PreviewActor.new,
);

/// Whether the current build may render the preview-user developer tool.
final previewActorUiEnabledProvider = Provider<bool>((_) => kDebugMode);

/// Owns the selected preview alias without ever accepting a user UUID.
final class PreviewActor extends Notifier<String?> {
  static final _validAlias = RegExp(r'^[a-z][a-z0-9-]{0,31}$');

  @override
  String? build() => null;

  /// Selects an alias advertised by the local backend.
  void select(String alias) {
    if (!kDebugMode || !_validAlias.hasMatch(alias)) {
      throw ArgumentError.value(alias, 'alias', 'Must be a preview alias.');
    }
    if (state != alias) state = alias;
  }
}
