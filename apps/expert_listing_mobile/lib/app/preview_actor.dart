import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The public demo alias selected for request-scoped server resolution.
final previewActorProvider = NotifierProvider<PreviewActor, String?>(
  PreviewActor.new,
);

/// Owns the selected preview alias without ever accepting a user UUID.
final class PreviewActor extends Notifier<String?> {
  static final _validAlias = RegExp(r'^[a-z][a-z0-9-]{0,31}$');

  @override
  String? build() => null;

  /// Selects an alias advertised by the API.
  void select(String alias) {
    if (!_validAlias.hasMatch(alias)) {
      throw ArgumentError.value(alias, 'alias', 'Must be a preview alias.');
    }
    if (state != alias) state = alias;
  }
}
