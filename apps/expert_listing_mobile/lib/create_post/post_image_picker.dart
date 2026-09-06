// The interface deliberately isolates a difficult native plugin boundary.
// ignore_for_file: one_member_abstracts

import 'dart:typed_data';

import 'package:expert_listing/create_post/create_post_image.dart';
import 'package:image_picker/image_picker.dart';

/// A safe picker failure that can be shown without exposing plugin details.
final class PostImagePickerFailure implements Exception {
  /// Creates a picker failure with approved user-facing copy.
  const PostImagePickerFailure(this.message);

  /// Short recoverable failure copy.
  final String message;
}

/// Isolates the native image picker from create-post behavior tests.
abstract interface class PostImagePicker {
  /// Picks up to [limit] images and returns validated bytes in selection order.
  Future<List<CreatePostImage>> pickImages({required int limit});
}

/// The production native photo-library picker.
final class SystemPostImagePicker implements PostImagePicker {
  /// Creates the picker boundary.
  SystemPostImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const int _maxImageBytes = 2 * 1024 * 1024;
  final ImagePicker _picker;

  @override
  Future<List<CreatePostImage>> pickImages({required int limit}) async {
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        limit: limit,
        requestFullMetadata: false,
      );
      final images = <CreatePostImage>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxImageBytes) {
          throw const PostImagePickerFailure(
            'Each image must be 2 MiB or smaller.',
          );
        }
        if (!_isSupportedImage(bytes)) {
          throw const PostImagePickerFailure(
            'That image format isn’t supported yet.',
          );
        }
        images.add(CreatePostImage(name: file.name, bytes: bytes));
      }
      return images;
    } on PostImagePickerFailure {
      rethrow;
    } on Object {
      throw const PostImagePickerFailure(
        'That image couldn’t be added. Choose another.',
      );
    }
  }

  bool _isSupportedImage(Uint8List bytes) {
    final png =
        bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[12] == 0x49 &&
        bytes[13] == 0x48 &&
        bytes[14] == 0x44 &&
        bytes[15] == 0x52;
    final jpeg =
        bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff &&
        bytes[bytes.length - 2] == 0xff &&
        bytes.last == 0xd9;
    final webp =
        bytes.length >= 16 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return png || jpeg || webp;
  }
}
