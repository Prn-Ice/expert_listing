import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The local visual identity for one server-advertised preview actor.
typedef PreviewActorIdentity = ({String assetName, String displayName});

/// Resolves the fixed preview actor used by local, non-server UI.
PreviewActorIdentity previewActorIdentity(String? alias) => switch (alias) {
  'ayo' => (
    assetName: 'assets/images/ayo.jpg',
    displayName: 'Ayo Balogun',
  ),
  'ifeoma' => (
    assetName: 'assets/images/ifeoma.jpg',
    displayName: 'Ifeoma Nwosu',
  ),
  'bizzaro' => (
    assetName: 'assets/images/bizzaro.jpg',
    displayName: 'Bizzaro Cole',
  ),
  _ => (
    assetName: 'assets/images/current-user.jpg',
    displayName: 'Prince Adeyemi',
  ),
};

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
