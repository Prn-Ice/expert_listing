import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:expert_listing/create_post/create_post_cubit.dart';
import 'package:expert_listing/create_post/create_post_image.dart';
import 'package:expert_listing/create_post/create_post_state.dart';
import 'package:expert_listing/create_post/post_image_picker.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CreatePostCubit, () {
    test('retains variant-specific draft values while switching type', () {
      final cubit = CreatePostCubit(
        repository: _CreateRepository(),
        imagePicker: _ImagePicker(const []),
      );
      addTearDown(cubit.close);

      cubit
        ..bodyChanged('A retained draft')
        ..locationChanged('Yaba, Lagos')
        ..postTypeChanged(PostType.request)
        ..requestTypeChanged(RequestType.lookingToRent)
        ..postTypeChanged(PostType.property)
        ..propertyStatusChanged(PropertyStatus.forRent)
        ..postTypeChanged(PostType.request);

      expect(cubit.state.body, 'A retained draft');
      expect(cubit.state.location, 'Yaba, Lagos');
      expect(cubit.state.requestType, RequestType.lookingToRent);
      expect(cubit.state.propertyStatus, PropertyStatus.forRent);
    });

    test('treats type-only changes as a populated draft', () {
      expect(CreatePostState.initial.isPopulated, isFalse);
      expect(
        CreatePostState.initial
            .copyWith(postType: PostType.request)
            .isPopulated,
        isTrue,
      );
      expect(
        CreatePostState.initial
            .copyWith(requestType: RequestType.lookingToRent)
            .isPopulated,
        isTrue,
      );
      expect(
        CreatePostState.initial
            .copyWith(propertyStatus: PropertyStatus.forRent)
            .isPopulated,
        isTrue,
      );
    });

    test('keeps selected images ordered and supports removal', () async {
      final images = [_image('first.png', 1), _image('second.png', 2)];
      final cubit = CreatePostCubit(
        repository: _CreateRepository(),
        imagePicker: _ImagePicker(images),
      );
      addTearDown(cubit.close);

      await cubit.pickImages();
      expect(cubit.state.images.map((image) => image.name), [
        'first.png',
        'second.png',
      ]);

      cubit.removeImage(0);
      expect(cubit.state.images.single.name, 'second.png');
    });

    test('retains the complete draft after recoverable failure', () async {
      final image = _image('property.png', 1);
      final repository = _CreateRepository(fail: true);
      final cubit = CreatePostCubit(
        repository: repository,
        imagePicker: _ImagePicker([image]),
      );
      addTearDown(cubit.close);

      cubit
        ..bodyChanged('Property draft')
        ..locationChanged('Lekki, Lagos')
        ..postTypeChanged(PostType.property)
        ..propertyStatusChanged(PropertyStatus.forRent);
      await cubit.pickImages();
      final post = await cubit.submit();

      expect(post, isNull);
      expect(cubit.state.body, 'Property draft');
      expect(cubit.state.location, 'Lekki, Lagos');
      expect(cubit.state.propertyStatus, PropertyStatus.forRent);
      expect(cubit.state.images, [image]);
      expect(
        cubit.state.failureMessage,
        'Couldn’t publish. Your post is still here.',
      );
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('returns the hydrated post and reports upload progress', () async {
      final repository = _CreateRepository();
      final cubit = CreatePostCubit(
        repository: repository,
        imagePicker: _ImagePicker(const []),
      );
      addTearDown(cubit.close);
      cubit
        ..bodyChanged('General post')
        ..locationChanged('Yaba, Lagos');

      final post = await cubit.submit();

      expect(post?.id, 99);
      expect(cubit.state.createdPost?.id, 99);
      expect(cubit.state.uploadProgress, 1);
      expect(repository.progressWasReported, isTrue);
    });
  });
}

CreatePostImage _image(String name, int marker) => CreatePostImage(
  name: name,
  bytes: Uint8List.fromList([marker]),
);

final class _ImagePicker implements PostImagePicker {
  _ImagePicker(this.images);

  final List<CreatePostImage> images;

  @override
  Future<List<CreatePostImage>> pickImages({required int limit}) async =>
      images.take(limit).toList(growable: false);
}

final class _CreateRepository extends FeedRepository {
  _CreateRepository({this.fail = false}) : super(client: Dio());

  final bool fail;
  bool progressWasReported = false;

  @override
  Future<FeedPost> createPost({
    required String body,
    required String location,
    required PostType postType,
    required List<CreatePostImage> images,
    required void Function(double) onProgress,
    RequestType? requestType,
    PropertyStatus? propertyStatus,
  }) async {
    onProgress(0.5);
    progressWasReported = true;
    if (fail) {
      throw const CreatePostFailure(
        'Couldn’t publish. Your post is still here.',
      );
    }
    return FeedPost.fromJson({
      'id': 99,
      'body': body,
      'postType': 'general',
      'createdAt': '2026-09-05T19:00:00.000Z',
      'viewCount': 0,
      'bookmarkCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'likedByCurrentUser': false,
      'author': const {
        'id': '00000000-0000-0000-0000-000000000001',
        'handle': 'prince',
        'displayName': 'Prince Adeyemi',
        'role': 'Buyer',
        'avatarUrl': null,
      },
      'location': location,
    });
  }
}
