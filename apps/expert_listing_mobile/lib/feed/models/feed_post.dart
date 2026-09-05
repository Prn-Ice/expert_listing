// API-shaped fields are self-describing; constructor order follows parse flow.
// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:equatable/equatable.dart';

import 'package:expert_listing/feed/models/post_types.dart';

/// The author data included with every hydrated feed post.
final class FeedAuthor extends Equatable {
  /// Creates an author.
  const FeedAuthor({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.role,
    required this.avatarUrl,
  });

  final String id;
  final String handle;
  final String displayName;
  final String role;
  final String? avatarUrl;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) => FeedAuthor(
    id: _requiredString(json, 'id'),
    handle: _requiredString(json, 'handle'),
    displayName: _requiredString(json, 'displayName'),
    role: _requiredString(json, 'role'),
    avatarUrl: _optionalString(json, 'avatarUrl'),
  );

  @override
  List<Object?> get props => [id, handle, displayName, role, avatarUrl];
}

/// A public, server-owned property image.
final class PropertyImage extends Equatable {
  /// Creates an ordered property image.
  const PropertyImage({
    required this.id,
    required this.url,
    required this.position,
  });

  final int id;
  final String? url;
  final int position;

  factory PropertyImage.fromJson(Map<String, dynamic> json) => PropertyImage(
    id: _requiredInt(json, 'id'),
    url: _optionalString(json, 'url'),
    position: _requiredInt(json, 'position'),
  );

  @override
  List<Object?> get props => [id, url, position];
}

/// One discriminated post returned by the feed API.
sealed class FeedPost extends Equatable {
  /// Creates shared feed post data.
  const FeedPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.viewCount,
    required this.bookmarkCount,
    required this.likeCount,
    required this.commentCount,
    required this.likedByCurrentUser,
    required this.author,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final int viewCount;
  final int bookmarkCount;
  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final FeedAuthor author;

  /// The server-side discriminator used by filters and presentation.
  PostType get postType;

  /// The location owned by this post's variant.
  String get location;

  /// Returns this post with server-owned engagement fields reconciled.
  FeedPost withEngagement({
    int? likeCount,
    int? commentCount,
    bool? likedByCurrentUser,
  }) {
    final common = _CommonPost(
      id: id,
      body: body,
      createdAt: createdAt,
      viewCount: viewCount,
      bookmarkCount: bookmarkCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByCurrentUser: likedByCurrentUser ?? this.likedByCurrentUser,
      author: author,
    );
    return switch (this) {
      GeneralFeedPost(:final location) => GeneralFeedPost._(
        common: common,
        location: location,
      ),
      RequestFeedPost(:final requestType, :final location) => RequestFeedPost._(
        common: common,
        requestType: requestType,
        location: location,
      ),
      PropertyFeedPost(
        :final propertyId,
        :final status,
        :final location,
        :final images,
      ) =>
        PropertyFeedPost._(
          common: common,
          propertyId: propertyId,
          status: status,
          location: location,
          images: images,
        ),
    };
  }

  /// Builds a strict discriminated post rather than accepting combined
  /// variants.
  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final common = _CommonPost.fromJson(json);
    return switch (_requiredString(json, 'postType')) {
      'general' => GeneralFeedPost._(
        common: common,
        location: _requiredString(json, 'location'),
      ),
      'request' => RequestFeedPost._(
        common: common,
        requestType: _requestTypeFromWire(
          _requiredMap(json, 'request'),
          'type',
        ),
        location: _requiredString(_requiredMap(json, 'request'), 'location'),
      ),
      'property' => PropertyFeedPost._(
        common: common,
        propertyId: _requiredInt(_requiredMap(json, 'property'), 'id'),
        status: _propertyStatusFromWire(
          _requiredMap(json, 'property'),
          'status',
        ),
        location: _requiredString(_requiredMap(json, 'property'), 'location'),
        images: _propertyImages(_requiredMap(json, 'property')),
      ),
      _ => throw const FormatException('Feed post has an unknown post type.'),
    };
  }

  @override
  List<Object?> get props => [
    id,
    body,
    createdAt,
    viewCount,
    bookmarkCount,
    likeCount,
    commentCount,
    likedByCurrentUser,
    author,
  ];
}

/// A general post with a post-owned location.
final class GeneralFeedPost extends FeedPost {
  /// Creates a general post.
  GeneralFeedPost._({required _CommonPost common, required this.location})
    : super(
        id: common.id,
        body: common.body,
        createdAt: common.createdAt,
        viewCount: common.viewCount,
        bookmarkCount: common.bookmarkCount,
        likeCount: common.likeCount,
        commentCount: common.commentCount,
        likedByCurrentUser: common.likedByCurrentUser,
        author: common.author,
      );

  @override
  final String location;

  @override
  PostType get postType => PostType.general;

  @override
  List<Object?> get props => [...super.props, location];
}

/// A request post with a desired-area location.
final class RequestFeedPost extends FeedPost {
  /// Creates a request post.
  RequestFeedPost._({
    required _CommonPost common,
    required this.requestType,
    required this.location,
  }) : super(
         id: common.id,
         body: common.body,
         createdAt: common.createdAt,
         viewCount: common.viewCount,
         bookmarkCount: common.bookmarkCount,
         likeCount: common.likeCount,
         commentCount: common.commentCount,
         likedByCurrentUser: common.likedByCurrentUser,
         author: common.author,
       );

  final RequestType requestType;
  @override
  final String location;

  @override
  PostType get postType => PostType.request;

  @override
  List<Object?> get props => [...super.props, requestType, location];
}

/// A property post with its physical location and ordered public images.
final class PropertyFeedPost extends FeedPost {
  /// Creates a property post.
  PropertyFeedPost._({
    required _CommonPost common,
    required this.propertyId,
    required this.status,
    required this.location,
    required this.images,
  }) : super(
         id: common.id,
         body: common.body,
         createdAt: common.createdAt,
         viewCount: common.viewCount,
         bookmarkCount: common.bookmarkCount,
         likeCount: common.likeCount,
         commentCount: common.commentCount,
         likedByCurrentUser: common.likedByCurrentUser,
         author: common.author,
       );

  final int propertyId;
  final PropertyStatus status;
  @override
  final String location;
  final List<PropertyImage> images;

  @override
  PostType get postType => PostType.property;

  @override
  List<Object?> get props => [
    ...super.props,
    propertyId,
    status,
    location,
    images,
  ];
}

final class _CommonPost {
  const _CommonPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.viewCount,
    required this.bookmarkCount,
    required this.likeCount,
    required this.commentCount,
    required this.likedByCurrentUser,
    required this.author,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final int viewCount;
  final int bookmarkCount;
  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final FeedAuthor author;

  factory _CommonPost.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(_requiredString(json, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException('Feed post has an invalid creation date.');
    }

    return _CommonPost(
      id: _requiredInt(json, 'id'),
      body: _requiredString(json, 'body'),
      createdAt: createdAt.toUtc(),
      viewCount: _requiredInt(json, 'viewCount'),
      bookmarkCount: _requiredInt(json, 'bookmarkCount'),
      likeCount: _requiredInt(json, 'likeCount'),
      commentCount: _requiredInt(json, 'commentCount'),
      likedByCurrentUser: _requiredBool(json, 'likedByCurrentUser'),
      author: FeedAuthor.fromJson(_requiredMap(json, 'author')),
    );
  }
}

List<PropertyImage> _propertyImages(Map<String, dynamic> property) {
  final rawImages = property['images'];
  if (rawImages is! List) {
    throw const FormatException('Property post has invalid images.');
  }
  final images =
      rawImages.map((image) {
          if (image is! Map<String, dynamic>) {
            throw const FormatException('Property image is invalid.');
          }
          return PropertyImage.fromJson(image);
        }).toList()
        ..sort((first, second) => first.position.compareTo(second.position));
  return images;
}

RequestType _requestTypeFromWire(Map<String, dynamic> request, String key) {
  return switch (_requiredString(request, key)) {
    'looking_to_buy' => RequestType.lookingToBuy,
    'looking_to_rent' => RequestType.lookingToRent,
    _ => throw const FormatException(
      'Request post has an unknown request type.',
    ),
  };
}

PropertyStatus _propertyStatusFromWire(
  Map<String, dynamic> property,
  String key,
) {
  return switch (_requiredString(property, key)) {
    'for_sale' => PropertyStatus.forSale,
    'for_rent' => PropertyStatus.forRent,
    _ => throw const FormatException(
      'Property post has an unknown property status.',
    ),
  };
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Feed response has an invalid $key object.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Feed response has an invalid $key value.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Feed response has an invalid $key value.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Feed response has an invalid $key value.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Feed response has an invalid $key value.');
}
