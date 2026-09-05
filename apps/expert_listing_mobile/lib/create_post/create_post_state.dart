// State fields are named directly after the renderable create-post condition.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:expert_listing/create_post/create_post_image.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';

/// Renderable state for one create-post flow.
final class CreatePostState extends Equatable {
  /// Creates create-post state.
  const CreatePostState({
    this.body = '',
    this.location = '',
    this.postType = PostType.general,
    this.requestType = RequestType.lookingToBuy,
    this.propertyStatus = PropertyStatus.forSale,
    this.images = const [],
    this.isPickingImages = false,
    this.isSubmitting = false,
    this.uploadProgress = 0,
    this.failureMessage,
    this.createdPost,
  });

  /// The initial empty draft.
  static const initial = CreatePostState();

  final String body;
  final String location;
  final PostType postType;
  final RequestType requestType;
  final PropertyStatus propertyStatus;
  final List<CreatePostImage> images;
  final bool isPickingImages;
  final bool isSubmitting;
  final double uploadProgress;
  final String? failureMessage;
  final FeedPost? createdPost;

  /// Whether closing must ask before discarding the draft.
  bool get isPopulated =>
      body.trim().isNotEmpty || location.trim().isNotEmpty || images.isNotEmpty;

  /// Whether the current draft has the required client-side fields.
  bool get canSubmit =>
      body.trim().isNotEmpty &&
      location.trim().isNotEmpty &&
      !isPickingImages &&
      !isSubmitting;

  CreatePostState copyWith({
    String? body,
    String? location,
    PostType? postType,
    RequestType? requestType,
    PropertyStatus? propertyStatus,
    List<CreatePostImage>? images,
    bool? isPickingImages,
    bool? isSubmitting,
    double? uploadProgress,
    String? failureMessage,
    bool clearFailure = false,
    FeedPost? createdPost,
    bool clearCreatedPost = false,
  }) {
    return CreatePostState(
      body: body ?? this.body,
      location: location ?? this.location,
      postType: postType ?? this.postType,
      requestType: requestType ?? this.requestType,
      propertyStatus: propertyStatus ?? this.propertyStatus,
      images: images ?? this.images,
      isPickingImages: isPickingImages ?? this.isPickingImages,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      failureMessage: clearFailure
          ? null
          : failureMessage ?? this.failureMessage,
      createdPost: clearCreatedPost ? null : createdPost ?? this.createdPost,
    );
  }

  @override
  List<Object?> get props => [
    body,
    location,
    postType,
    requestType,
    propertyStatus,
    images,
    isPickingImages,
    isSubmitting,
    uploadProgress,
    failureMessage,
    createdPost,
  ];
}
