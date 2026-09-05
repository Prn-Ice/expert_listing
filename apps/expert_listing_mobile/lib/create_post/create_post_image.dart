import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One locally selected, ordered image ready for multipart upload.
final class CreatePostImage extends Equatable {
  /// Creates a validated local image.
  const CreatePostImage({required this.name, required this.bytes});

  /// The local filename used only as multipart metadata.
  final String name;

  /// Image bytes retained while the create-post sheet is open.
  final Uint8List bytes;

  @override
  List<Object?> get props => [name, bytes];
}
