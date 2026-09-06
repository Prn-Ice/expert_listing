// Public members mirror direct user actions; constructor names preserve
// call-site language.
// ignore_for_file: public_member_api_docs, prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:expert_listing/create_post/create_post_state.dart';
import 'package:expert_listing/create_post/post_image_picker.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';

/// Owns one retained create-post draft and its submission lifecycle.
final class CreatePostCubit extends Cubit<CreatePostState> {
  /// Creates the create-post behavior boundary.
  CreatePostCubit({
    required FeedRepository repository,
    required PostImagePicker imagePicker,
  }) : _repository = repository,
       _imagePicker = imagePicker,
       super(CreatePostState.initial);

  final FeedRepository _repository;
  final PostImagePicker _imagePicker;

  void bodyChanged(String body) => emit(
    state.copyWith(body: body, clearFailure: true, clearCreatedPost: true),
  );

  void locationChanged(String location) => emit(
    state.copyWith(location: location, clearFailure: true),
  );

  void postTypeChanged(PostType postType) => emit(
    state.copyWith(postType: postType, clearFailure: true),
  );

  void requestTypeChanged(RequestType requestType) => emit(
    state.copyWith(requestType: requestType, clearFailure: true),
  );

  void propertyStatusChanged(PropertyStatus propertyStatus) => emit(
    state.copyWith(propertyStatus: propertyStatus, clearFailure: true),
  );

  Future<void> pickImages() async {
    if (state.isPickingImages) return;
    final remaining = 4 - state.images.length;
    if (remaining == 0) {
      emit(state.copyWith(failureMessage: 'You can add up to 4 images.'));
      return;
    }
    emit(state.copyWith(isPickingImages: true, clearFailure: true));
    try {
      final picked = await _imagePicker.pickImages(limit: remaining);
      if (isClosed) return;
      emit(
        state.copyWith(
          images: [...state.images, ...picked.take(remaining)],
          isPickingImages: false,
        ),
      );
    } on PostImagePickerFailure catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isPickingImages: false,
            failureMessage: error.message,
          ),
        );
      }
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= state.images.length || state.isSubmitting) return;
    emit(
      state.copyWith(
        images: [...state.images]..removeAt(index),
        clearFailure: true,
      ),
    );
  }

  Future<FeedPost?> submit() async {
    if (!state.canSubmit) return null;
    emit(
      state.copyWith(
        isSubmitting: true,
        uploadProgress: 0,
        clearFailure: true,
        clearCreatedPost: true,
      ),
    );
    try {
      final post = await _repository.createPost(
        body: state.body.trim(),
        location: state.location.trim(),
        postType: state.postType,
        requestType: state.postType == PostType.request
            ? state.requestType
            : null,
        propertyStatus: state.postType == PostType.property
            ? state.propertyStatus
            : null,
        images: state.postType == PostType.property ? state.images : const [],
        onProgress: (progress) {
          if (!isClosed) emit(state.copyWith(uploadProgress: progress));
        },
      );
      if (isClosed) return post;
      emit(
        state.copyWith(
          isSubmitting: false,
          uploadProgress: 1,
          createdPost: post,
        ),
      );
      return post;
    } on CreatePostFailure catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSubmitting: false,
            uploadProgress: 0,
            failureMessage: error.message,
          ),
        );
      }
      return null;
    }
  }
}
